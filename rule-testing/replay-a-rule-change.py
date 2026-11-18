"""Replays a situation in which a rule went wrong, in fresh Claude Code sessions, under two or more versions of the
shared rules: so that a change to a rule is tested before it is committed, and against a control.

    python .claude-shared/rule-testing/replay-a-rule-change.py <replay folder>
        [--arm <name>=<rules>]...   default: committed=HEAD and working-tree=working-tree
        [--runs <how many for each arm>]   default: 2
        [--model <model>] [--judge-model <model>] [--tools <allowed tools>] [--keep-in <folder>]
        [--timeout-minutes <minutes>]   default: 20, for all the sessions together, and again for the judging
        [--judge <results folder>]   judge the answers already there, and run no sessions
        [--show <regular expression>]

A replay folder holds:
    prompt.txt              what each fresh session is asked: the situation as it stood, and the user's message.
    documents/              optional: the files the prompt has the session read, at the paths the prompt names. They
                            are copied in last, so a replay can also hold one of the consuming repository's own rules
                            as it was, at its path under .claude/rules.
    the-failing.md          optional: what counts as the failing, and what doesn't. With it, each answer is judged
                            by a fresh session of its own, and the script counts the failings for each arm.
    passages-to-show.txt    optional: a regular expression. Without the-failing.md, only the passages of each answer
                            that match it are printed. Without either, and without --show, whole answers are.

An arm is a version of the catalog's rules, given as <name>=<rules>, where <rules> is one of:
    working-tree    the catalog as it is on disk, uncommitted changes included: the change under test.
    <commit>        the catalog as of that commit, such as HEAD or a1b2c3d^: the control.
    none            no shared rules at all: what the model does by itself.
After working-tree or a commit, +<folder> lays that folder's files over the catalog's, at the same paths. So several
wordings of a rule are tested at once, each in a folder of its own, with nothing changed in the catalog:
    --arm shorter=HEAD+C:/wordings/shorter    with the wording in C:/wordings/shorter/rules/universal/001-some-rule.md

Each arm gets a folder of its own, holding the replay's documents and the consuming repository's .claude folder, with
the rules that come from the catalog in the arm's version. So the arms differ in the catalog's rules and in nothing
else. Rules at user level are loaded in every arm: this script can't take them out.

A session is told its working directory, and the name of that folder changes what it answers: folders named after the
arms, such as with-the-sentence, gave results that folders with plain names did not (2026-11-14). So every arm's folder
is named after the consuming repository, under a temporary folder with a random name.

Every run is a fresh session, since a session, and the agents it starts, keep the rules they started with. The
sessions have only the tools --tools names, read-only ones by default, the judges none, and none of them MCP servers.
Claude Code keeps no transcript of them. The whole answers are kept in the results folder: read some of them beside the
judge's verdicts, since the judge is a model too.

The sessions of a run all start at once, and each is reported, and its answer written to the results folder, as it
finishes. They share one deadline: the sessions still running when it passes are stopped, and reported as having given
no answer. So a run never takes longer than its timeout, and its timeout once more for the judging.
"""
from __future__ import annotations

import argparse
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

CATALOG = Path(__file__).resolve().parent.parent


@dataclass
class Arm:
    name: str
    rules: str
    laid_over_the_rules: Path | None = None
    """A folder whose files replace the catalog's at the same paths."""

    @staticmethod
    def parsed_from(text: str) -> Arm:
        name, separator, rules = text.partition("=")
        if not separator or not name or not rules:
            sys.exit(f"An arm is <name>=<rules>, such as before=HEAD. Got: {text}")
        rules, _, folder = rules.partition("+")
        if not folder:
            return Arm(name, rules)
        if rules == "none" or not Path(folder).is_dir():
            sys.exit(f"After working-tree or a commit, + takes a folder that exists. Got: {text}")
        return Arm(name, rules, Path(folder).resolve())

    @property
    def described(self) -> str:
        return f"{self.name} ({self.rules}" + (f" with {self.laid_over_the_rules} laid over it)" if self.laid_over_the_rules else ")")

    def puts_what_the_catalog_has_at(self, path_in_the_catalog: PurePosixPath, destination: Path) -> None:
        """Writes the catalog's file or folder at that path to the destination, in this arm's version of the rules."""
        if self.rules == "none":
            return
        if self.rules == "working-tree":
            copy_the_file_or_folder(CATALOG / path_in_the_catalog, destination)
        else:
            self.puts_what_its_commit_has_at(path_in_the_catalog, destination)
        if self.laid_over_the_rules:
            copy_the_file_or_folder(self.laid_over_the_rules / path_in_the_catalog, destination)

    def puts_what_its_commit_has_at(self, path_in_the_catalog: PurePosixPath, destination: Path) -> None:
        archived = subprocess.run(["git", "-C", str(CATALOG), "archive", self.rules, path_in_the_catalog.as_posix()], capture_output=True)
        if archived.returncode != 0:
            print(f"   ({self.name}: the catalog has no {path_in_the_catalog} as of {self.rules})")
            return
        with tarfile.open(fileobj=io.BytesIO(archived.stdout)) as archive:
            for member in archive:
                contents = archive.extractfile(member)
                if contents is None:
                    continue
                target = destination / PurePosixPath(member.name).relative_to(path_in_the_catalog)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(contents.read())


@dataclass
class FreshSession:
    """A claude session started for one prompt, which writes its result as JSON to a file."""
    name: str
    result_file: Path
    process: subprocess.Popen
    started_at: float = field(default_factory=time.monotonic)

    @staticmethod
    def started(name: str, prompt: Path, runs_in: Path, result_file: Path, model: str | None, tools: str) -> FreshSession:
        """tools are the only tools the session has, comma separated, or "" for none."""
        claude = shutil.which("claude")
        if not claude:
            sys.exit("claude isn't on the PATH")
        command = [claude, "-p", "--strict-mcp-config", "--no-session-persistence", "--output-format", "json", "--tools", tools]
        if tools:
            # --tools makes them the only ones, and --allowedTools lets the session use them without a permission prompt.
            command += ["--allowedTools", tools]
        if model:
            command += ["--model", model]
        with prompt.open("rb") as the_prompt, result_file.open("wb") as the_result, result_file.with_suffix(".errors.txt").open("wb") as its_errors:
            process = subprocess.Popen(command, cwd=runs_in, stdin=the_prompt, stdout=the_result, stderr=its_errors)
        return FreshSession(name, result_file, process)

    @property
    def has_finished(self) -> bool:
        return self.process.poll() is not None

    @property
    def time_taken(self) -> str:
        seconds = int(time.monotonic() - self.started_at)
        return f"{seconds // 60} min {seconds % 60} s" if seconds >= 60 else f"{seconds} s"

    def stop(self) -> None:
        self.process.kill()
        self.process.wait()

    def result(self) -> dict | None:
        """What the session returned, once it has finished or was stopped, or None when it gave no answer."""
        try:
            result = json.loads(self.result_file.read_text(encoding="utf-8"))
            return result if "result" in result else None
        except (ValueError, OSError):
            return None


def results_as_they_come(sessions: list[FreshSession], timeout_minutes: int) -> Iterator[tuple[FreshSession, dict | None]]:
    """Each session with what it returned, or None when it gave no answer, in the order the sessions finish.

    The sessions share one deadline, counted from now: those still running when it passes are stopped, and gave no answer.
    """
    deadline = time.monotonic() + timeout_minutes * 60
    still_running = list(sessions)
    while still_running:
        finished = [session for session in still_running if session.has_finished]
        if not finished and time.monotonic() < deadline:
            time.sleep(1)
            continue
        if not finished:
            print(f"   The {timeout_minutes} minutes are up: stopping the {len(still_running)} sessions still running.")
            finished = list(still_running)
            for session in finished:
                session.stop()
        for session in finished:
            still_running.remove(session)
            yield session, session.result()


@dataclass
class Verdict:
    shows_the_failing: bool | None
    """None when the judge gave no verdict."""
    what_decides_it: str

    @staticmethod
    def parsed_from(the_judges_answer: str | None) -> Verdict:
        # The verdict comes last, after the passage it rests on: a judge that gave it first sometimes argued itself out of it
        # in the passage that followed, and the first word stood (2026-11-17, two verdicts of eight).
        lines = [line.strip() for line in (the_judges_answer or "").splitlines() if line.strip()]
        last_line = lines[-1].upper().strip("*# .:") if lines else ""
        what_decides_it = " ".join(lines[:-1])
        if last_line.startswith("NOT FAILING"):
            return Verdict(False, what_decides_it)
        if last_line.startswith("FAILING"):
            return Verdict(True, what_decides_it)
        return Verdict(None, " ".join(lines) or "The judge gave no answer.")

    @property
    def in_a_word(self) -> str:
        return {True: "FAILING", False: "not failing", None: "NO VERDICT"}[self.shows_the_failing]


def main() -> None:
    arguments = parsed_arguments()
    replay = Path(arguments.replay).resolve()
    the_failing = text_of(replay / "the-failing.md")

    if arguments.judge:
        if the_failing is None:
            sys.exit(f"{replay} has no the-failing.md to judge by")
        answers = {file.stem: file.read_text(encoding="utf-8") for file in sorted(Path(arguments.judge).glob("*.md"))}
        print_the_verdicts(answers, the_failing, arguments)
        return

    prompt = replay / "prompt.txt"
    if not prompt.is_file():
        sys.exit(f"{replay} has no prompt.txt")
    arms = [Arm.parsed_from(text) for text in arguments.arm] or [Arm("committed", "HEAD"), Arm("working-tree", "working-tree")]
    results = Path(arguments.keep_in).resolve() if arguments.keep_in else Path(tempfile.mkdtemp(prefix="replay-of-a-rule-change-"))
    results.mkdir(parents=True, exist_ok=True)
    repository = consuming_repository()

    print(f"Replaying {replay.name}: {arguments.runs} runs for each of {', '.join(arm.described for arm in arms)}")
    sessions: list[FreshSession] = []
    where_each_arm_ran: dict[str, Path] = {}
    for arm in arms:
        folder = Path(tempfile.mkdtemp()) / (repository.name if repository else "project")
        build_the_folder_a_session_runs_in(folder, arm, replay, repository)
        where_each_arm_ran[arm.name] = folder
        for number in range(1, arguments.runs + 1):
            name = f"{arm.name}-{number}"
            sessions.append(FreshSession.started(name, prompt, folder, results / f"{name}.json", arguments.model, arguments.tools))

    answer_of_each: dict[str, str] = {}
    for session, result in results_as_they_come(sessions, arguments.timeout_minutes):
        if result is None:
            print(f"   {session.name} gave no answer in {session.time_taken}: see {session.result_file} and the errors file beside it")
            continue
        answer_of_each[session.name] = result["result"]
        (results / f"{session.name}.md").write_text(result["result"], encoding="utf-8")
        print(f"   {session.name} answered after {session.time_taken}")
    answers = {session.name: answer_of_each[session.name] for session in sessions if session.name in answer_of_each}
    for folder in where_each_arm_ran.values():
        remove_the_empty_folder_claude_code_made_for(folder)

    if the_failing is not None:
        print_the_verdicts(answers, the_failing, arguments)
    else:
        print_the_passages(answers, arguments.show or text_of(replay / "passages-to-show.txt"))
    print(f"\nThe whole answers are in {results}")
    for arm_name, folder in where_each_arm_ran.items():
        print(f"   {arm_name} ran in {folder}")
    sys.exit(0 if len(answers) == len(sessions) else 1)


def parsed_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("replay", help="the replay folder: prompt.txt, and optionally documents/, the-failing.md and passages-to-show.txt")
    parser.add_argument("--arm", action="append", default=[], metavar="NAME=RULES", help="RULES is working-tree, none, or a commit of the catalog; +FOLDER lays a folder's files over it")
    parser.add_argument("--runs", type=int, default=2, help="fresh sessions for each arm")
    parser.add_argument("--model", help="the model the sessions use, such as the one that got it wrong")
    parser.add_argument("--judge-model", help="the model that judges the answers. Default: --model")
    parser.add_argument("--tools", default="Read,Grep,Glob", help="the only tools the sessions have")
    parser.add_argument("--judge", metavar="FOLDER", help="judge the answers (*.md) already in that results folder, and run no sessions")
    parser.add_argument("--show", metavar="REGEX", help="without the-failing.md: print only the passages of each answer that match")
    parser.add_argument("--keep-in", metavar="FOLDER", help="where the results go, instead of a new temporary folder")
    parser.add_argument("--timeout-minutes", type=int, default=20, help="how long all the sessions together may take, and then the judging")
    return parser.parse_args()


def text_of(file: Path) -> str | None:
    return file.read_text(encoding="utf-8").strip() if file.is_file() else None


def copy_the_file_or_folder(source: Path, destination: Path) -> None:
    """Copies it over what the destination already has. Does nothing when there is no such file or folder."""
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True)
    elif source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def remove_the_empty_folder_claude_code_made_for(where_sessions_ran: Path) -> None:
    """Claude Code makes a folder in the user's .claude/projects for a folder that sessions ran in, also when it keeps no transcript of them."""
    its_folder = Path.home() / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(where_sessions_ran))
    if its_folder.is_dir() and not any(its_folder.iterdir()):
        its_folder.rmdir()


def consuming_repository() -> Path | None:
    """The repository the catalog is a submodule of, or None when the catalog is a clone of its own."""
    superproject = subprocess.run(["git", "-C", str(CATALOG), "rev-parse", "--show-superproject-working-tree"], capture_output=True, text=True).stdout.strip()
    return Path(superproject) if superproject else None


def build_the_folder_a_session_runs_in(folder: Path, arm: Arm, replay: Path, repository: Path | None) -> None:
    folder.mkdir(parents=True)
    put_the_rules_in(folder, arm, repository)
    documents = replay / "documents"
    if documents.is_dir():
        shutil.copytree(documents, folder, dirs_exist_ok=True)


def put_the_rules_in(folder: Path, arm: Arm, repository: Path | None) -> None:
    if repository is None or not (repository / ".claude").is_dir():
        arm.puts_what_the_catalog_has_at(PurePosixPath("rules/universal"), folder / ".claude" / "rules" / "01-universal-shared")
        return

    for instructions in (repository / "CLAUDE.md", repository / ".claude" / "CLAUDE.md"):
        if instructions.is_file():
            target = folder / instructions.relative_to(repository)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(instructions, target)
    its_rules = repository / ".claude" / "rules"
    if its_rules.is_dir():
        copy_the_rules(its_rules, folder / ".claude" / "rules", arm)


def copy_the_rules(source: Path, destination: Path, arm: Arm) -> None:
    """Copies a rules folder. What in it is a link into the catalog is written in the arm's version instead."""
    for entry in sorted(source.iterdir()):
        what_it_is = entry.resolve()
        if what_it_is.is_relative_to(CATALOG):
            arm.puts_what_the_catalog_has_at(PurePosixPath(what_it_is.relative_to(CATALOG).as_posix()), destination / entry.name)
        elif entry.is_dir():
            copy_the_rules(entry, destination / entry.name, arm)
        else:
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, destination / entry.name)


def print_the_verdicts(answers: dict[str, str], the_failing: str, arguments: argparse.Namespace) -> None:
    """Has a fresh session judge each answer against the description of the failing, and prints the count for each arm."""
    judgings = [started_judging(name, answer, the_failing, arguments) for name, answer in answers.items()]
    verdict_on_each: dict[str, Verdict] = {}
    print()
    for judging, result in results_as_they_come(judgings, arguments.timeout_minutes):
        verdict = Verdict.parsed_from(result["result"] if result else None)
        verdict_on_each[judging.name] = verdict
        print(f"   {judging.name}: {verdict.in_a_word}  > {verdict.what_decides_it}")
    failings_of_each_arm: dict[str, list[bool | None]] = {}
    for name in answers:
        failings_of_each_arm.setdefault(re.sub(r"-\d+$", "", name), []).append(verdict_on_each[name].shows_the_failing)
    print()
    for arm_name, failings in failings_of_each_arm.items():
        without_a_verdict = failings.count(None)
        print(f"{arm_name}: {failings.count(True)} of {len(failings)} answers show the failing" + (f", {without_a_verdict} without a verdict" if without_a_verdict else ""))


def started_judging(name: str, answer: str, the_failing: str, arguments: argparse.Namespace) -> FreshSession:
    workplace = Path(tempfile.mkdtemp())
    question = workplace / "question.txt"
    question.write_text(f"""You are judging one answer from a test of a rule. Decide whether the answer shows the failing described below.

## What counts as the failing

{the_failing}

## The answer to judge

{answer}

## How to reply

Reply with exactly two lines, and nothing else.
Line 1: the passage of the answer that decides it, quoted word for word; or, when nothing in the answer is on the matter, a few words saying so.
Line 2: FAILING or NOT FAILING.
""", encoding="utf-8")
    an_empty_folder = workplace / "empty"
    an_empty_folder.mkdir()
    return FreshSession.started(name, question, an_empty_folder, workplace / "verdict.json", arguments.judge_model or arguments.model, tools="")


def print_the_passages(answers: dict[str, str], passages_to_show: str | None) -> None:
    for name, answer in answers.items():
        print(f"\n== {name}")
        if not passages_to_show:
            print(answer)
            continue
        matching = [passage for passage in passages_of(answer) if re.search(passages_to_show, passage, re.IGNORECASE)]
        for passage in matching:
            print("   > " + " ".join(passage.split()))
        if not matching:
            print(f"   Nothing in the answer matches {passages_to_show}")


def passages_of(answer: str) -> list[str]:
    """The answer's paragraphs, with each list item a passage of its own."""
    return [passage.strip() for passage in re.split(r"\n\s*\n|\n(?=\s*(?:[-*]|\d+\.)\s)", answer) if passage.strip()]


if __name__ == "__main__":
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    main()
