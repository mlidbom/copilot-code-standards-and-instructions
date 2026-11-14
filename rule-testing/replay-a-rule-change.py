"""Replays a situation in which a rule went wrong, in fresh Claude Code sessions, under two or more versions of the
shared rules: so that a change to a rule is tested before it is committed, and against a control.

    python .claude-shared/rule-testing/replay-a-rule-change.py <replay folder>
        [--arm <name>=<rules>]...   default: committed=HEAD and working-tree=working-tree
        [--runs <how many for each arm>]   default: 2
        [--model <model>] [--judge-model <model>] [--tools <allowed tools>] [--keep-in <folder>]
        [--judge <results folder>]   judge the answers already there, and run no sessions
        [--show <regular expression>]

A replay folder holds:
    prompt.txt              what each fresh session is asked: the situation as it stood, and the user's message.
    documents/              optional: the files the prompt has the session read, at the paths the prompt names.
    the-failing.md          optional: what counts as the failing, and what doesn't. With it, each answer is judged
                            by a fresh session of its own, and the script counts the failings for each arm.
    passages-to-show.txt    optional: a regular expression. Without the-failing.md, only the passages of each answer
                            that match it are printed. Without either, and without --show, whole answers are.

An arm is a version of the catalog's rules, given as <name>=<rules>, where <rules> is one of:
    working-tree    the catalog as it is on disk, uncommitted changes included: the change under test.
    <commit>        the catalog as of that commit, such as HEAD or a1b2c3d^: the control.
    none            no shared rules at all: what the model does by itself.

Each arm gets a folder of its own, holding the replay's documents and the consuming repository's .claude folder, with
the rules that come from the catalog in the arm's version. So the arms differ in the catalog's rules and in nothing
else. Rules at user level are loaded in every arm: this script can't take them out.

A session is told its working directory, and the name of that folder changes what it answers: folders named after the
arms, such as with-the-sentence, gave results that folders with plain names did not (2026-11-14). So every arm's folder
is named after the consuming repository, under a temporary folder with a random name.

Every run is a fresh session, since a session, and the agents it starts, keep the rules they started with. The
sessions get read-only tools and no MCP servers. The whole answers are kept in the results folder: read some of them
beside the judge's verdicts, since the judge is a model too.
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
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

CATALOG = Path(__file__).resolve().parent.parent


@dataclass
class Arm:
    name: str
    rules: str

    @staticmethod
    def parsed_from(text: str) -> Arm:
        name, separator, rules = text.partition("=")
        if not separator or not name or not rules:
            sys.exit(f"An arm is <name>=<rules>, such as before=HEAD. Got: {text}")
        return Arm(name, rules)

    def puts_what_the_catalog_has_at(self, path_in_the_catalog: PurePosixPath, destination: Path) -> None:
        """Writes the catalog's file or folder at that path to the destination, in this arm's version of the rules."""
        if self.rules == "none":
            return
        if self.rules == "working-tree":
            source = CATALOG / path_in_the_catalog
            if source.is_dir():
                shutil.copytree(source, destination)
            elif source.is_file():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
            return
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

    @staticmethod
    def started(name: str, prompt: Path, runs_in: Path, result_file: Path, model: str | None, tools: str | None) -> FreshSession:
        claude = shutil.which("claude")
        if not claude:
            sys.exit("claude isn't on the PATH")
        command = [claude, "-p", "--strict-mcp-config", "--output-format", "json"]
        if tools:
            command += ["--allowedTools", tools]
        if model:
            command += ["--model", model]
        with prompt.open("rb") as the_prompt, result_file.open("wb") as the_result, result_file.with_suffix(".errors.txt").open("wb") as its_errors:
            process = subprocess.Popen(command, cwd=runs_in, stdin=the_prompt, stdout=the_result, stderr=its_errors)
        return FreshSession(name, result_file, process)

    def result(self, timeout_minutes: int) -> dict | None:
        """What the session returned, or None when it gave no answer."""
        try:
            self.process.wait(timeout=timeout_minutes * 60)
        except subprocess.TimeoutExpired:
            self.process.kill()
        try:
            result = json.loads(self.result_file.read_text(encoding="utf-8"))
            return result if "result" in result else None
        except (ValueError, OSError):
            return None


@dataclass
class Verdict:
    shows_the_failing: bool | None
    """None when the judge gave no verdict."""
    what_decides_it: str

    @staticmethod
    def parsed_from(the_judges_answer: str | None) -> Verdict:
        lines = [line.strip() for line in (the_judges_answer or "").splitlines() if line.strip()]
        first_line = lines[0].upper().strip("*# .:") if lines else ""
        what_decides_it = " ".join(lines[1:])
        if first_line.startswith("NOT FAILING"):
            return Verdict(False, what_decides_it)
        if first_line.startswith("FAILING"):
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

    print(f"Replaying {replay.name}: {arguments.runs} runs for each of {', '.join(f'{arm.name} ({arm.rules})' for arm in arms)}")
    sessions: list[FreshSession] = []
    where_each_arm_ran: dict[str, Path] = {}
    for arm in arms:
        folder = Path(tempfile.mkdtemp()) / (repository.name if repository else "project")
        build_the_folder_a_session_runs_in(folder, arm, replay, repository)
        where_each_arm_ran[arm.name] = folder
        for number in range(1, arguments.runs + 1):
            name = f"{arm.name}-{number}"
            sessions.append(FreshSession.started(name, prompt, folder, results / f"{name}.json", arguments.model, arguments.tools))

    answers: dict[str, str] = {}
    for session in sessions:
        result = session.result(arguments.timeout_minutes)
        if result is None:
            print(f"   {session.name} gave no answer: see {session.result_file} and the errors file beside it")
            continue
        answers[session.name] = result["result"]
        (results / f"{session.name}.md").write_text(result["result"], encoding="utf-8")

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
    parser.add_argument("--arm", action="append", default=[], metavar="NAME=RULES", help="RULES is working-tree, none, or a commit of the catalog")
    parser.add_argument("--runs", type=int, default=2, help="fresh sessions for each arm")
    parser.add_argument("--model", help="the model the sessions use, such as the one that got it wrong")
    parser.add_argument("--judge-model", help="the model that judges the answers. Default: --model")
    parser.add_argument("--tools", default="Read,Grep,Glob", help="the tools the sessions may use")
    parser.add_argument("--judge", metavar="FOLDER", help="judge the answers (*.md) already in that results folder, and run no sessions")
    parser.add_argument("--show", metavar="REGEX", help="without the-failing.md: print only the passages of each answer that match")
    parser.add_argument("--keep-in", metavar="FOLDER", help="where the results go, instead of a new temporary folder")
    parser.add_argument("--timeout-minutes", type=int, default=20)
    return parser.parse_args()


def text_of(file: Path) -> str | None:
    return file.read_text(encoding="utf-8").strip() if file.is_file() else None


def consuming_repository() -> Path | None:
    """The repository the catalog is a submodule of, or None when the catalog is a clone of its own."""
    superproject = subprocess.run(["git", "-C", str(CATALOG), "rev-parse", "--show-superproject-working-tree"], capture_output=True, text=True).stdout.strip()
    return Path(superproject) if superproject else None


def build_the_folder_a_session_runs_in(folder: Path, arm: Arm, replay: Path, repository: Path | None) -> None:
    documents = replay / "documents"
    if documents.is_dir():
        shutil.copytree(documents, folder)
    else:
        folder.mkdir(parents=True)

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
    failings_of_each_arm: dict[str, list[bool | None]] = {}
    print()
    for judging in judgings:
        result = judging.result(arguments.timeout_minutes)
        verdict = Verdict.parsed_from(result["result"] if result else None)
        failings_of_each_arm.setdefault(re.sub(r"-\d+$", "", judging.name), []).append(verdict.shows_the_failing)
        print(f"   {judging.name}: {verdict.in_a_word}  > {verdict.what_decides_it}")
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
Line 1: FAILING or NOT FAILING.
Line 2: the passage of the answer that decides it, quoted word for word; or, when nothing in the answer is on the matter, a few words saying so.
""", encoding="utf-8")
    an_empty_folder = workplace / "empty"
    an_empty_folder.mkdir()
    return FreshSession.started(name, question, an_empty_folder, workplace / "verdict.json", arguments.judge_model or arguments.model, tools=None)


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
        sys.stdout.reconfigure(encoding="utf-8")
    main()
