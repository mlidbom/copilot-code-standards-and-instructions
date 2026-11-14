"""Replays a situation in which a rule went wrong, in fresh Claude Code sessions, under two or more versions of the
shared rules: so that a change to a rule is tested before it is committed, and against a control.

    python .claude-shared/rule-testing/replay-a-rule-change.py <replay folder>
        [--arm <name>=<rules>]...   default: committed=HEAD and working-tree=working-tree
        [--runs <how many for each arm>]   default: 2
        [--model <model>] [--tools <allowed tools>] [--show <regular expression>] [--keep-in <folder>]

A replay folder holds:
    prompt.txt              what each fresh session is asked: the situation as it stood, and the user's message.
    documents/              optional: the files the prompt has the session read, at the paths the prompt names.
    passages-to-show.txt    optional: a regular expression. Only the passages of each answer that match it are
                            printed. Without it, and without --show, whole answers are.

An arm is a version of the catalog's rules, given as <name>=<rules>, where <rules> is one of:
    working-tree    the catalog as it is on disk, uncommitted changes included: the change under test.
    <commit>        the catalog as of that commit, such as HEAD or a1b2c3d^: the control.
    none            no shared rules at all: what the model does by itself.

Each arm gets a folder of its own, holding the replay's documents and the consuming repository's .claude folder, with
the rules that come from the catalog in the arm's version. So the arms differ in the catalog's rules and in nothing
else. Rules at user level are loaded in every arm: this script can't take them out.

Every run is a fresh session, since a session, and the agents it starts, keep the rules they started with. The
sessions get read-only tools and no MCP servers. Whether the failing happened is for the reader to judge, from the
passages printed and the whole answers kept in the results folder.
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

    def puts_the_catalogs_folder(self, folder_in_the_catalog: PurePosixPath, destination: Path) -> None:
        """Writes the catalog's folder to the destination, in this arm's version of the rules."""
        if self.rules == "none":
            return
        if self.rules == "working-tree":
            source = CATALOG / folder_in_the_catalog
            if source.is_dir():
                shutil.copytree(source, destination)
            return
        archived = subprocess.run(["git", "-C", str(CATALOG), "archive", self.rules, folder_in_the_catalog.as_posix()], capture_output=True)
        if archived.returncode != 0:
            print(f"   ({self.name}: the catalog has no {folder_in_the_catalog} as of {self.rules})")
            return
        with tarfile.open(fileobj=io.BytesIO(archived.stdout)) as archive:
            for member in archive:
                contents = archive.extractfile(member)
                if contents is None:
                    continue
                target = destination / PurePosixPath(member.name).relative_to(folder_in_the_catalog)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(contents.read())


@dataclass
class Run:
    arm: Arm
    number: int
    result_file: Path
    process: subprocess.Popen

    @property
    def name(self) -> str:
        return f"{self.arm.name}-{self.number}"


def main() -> None:
    arguments = parsed_arguments()
    replay = Path(arguments.replay).resolve()
    prompt = replay / "prompt.txt"
    if not prompt.is_file():
        sys.exit(f"{replay} has no prompt.txt")
    arms = [Arm.parsed_from(text) for text in arguments.arm] or [Arm("committed", "HEAD"), Arm("working-tree", "working-tree")]
    passages_to_show = arguments.show or passages_to_show_of(replay)
    results = Path(arguments.keep_in).resolve() if arguments.keep_in else Path(tempfile.mkdtemp(prefix="replay-of-a-rule-change-"))
    results.mkdir(parents=True, exist_ok=True)
    repository = consuming_repository()

    print(f"Replaying {replay.name}: {arguments.runs} runs for each of {', '.join(f'{arm.name} ({arm.rules})' for arm in arms)}")
    runs: list[Run] = []
    for arm in arms:
        folder = results / arm.name
        build_the_folder_a_session_runs_in(folder, arm, replay, repository)
        for number in range(1, arguments.runs + 1):
            runs.append(started_run(arm, number, folder, prompt, results, arguments))

    failed = False
    for run in runs:
        try:
            run.process.wait(timeout=arguments.timeout_minutes * 60)
        except subprocess.TimeoutExpired:
            run.process.kill()
        failed |= not report(run, passages_to_show, results)
    print(f"\nThe whole answers, and the folders the sessions ran in, are in {results}")
    sys.exit(1 if failed else 0)


def parsed_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("replay", help="the replay folder: prompt.txt, and optionally documents/ and passages-to-show.txt")
    parser.add_argument("--arm", action="append", default=[], metavar="NAME=RULES", help="RULES is working-tree, none, or a commit of the catalog")
    parser.add_argument("--runs", type=int, default=2, help="fresh sessions for each arm")
    parser.add_argument("--model", help="the model the sessions use, such as the one that got it wrong")
    parser.add_argument("--tools", default="Read,Grep,Glob", help="the tools the sessions may use")
    parser.add_argument("--show", metavar="REGEX", help="print only the passages of each answer that match")
    parser.add_argument("--keep-in", metavar="FOLDER", help="where the results go, instead of a new temporary folder")
    parser.add_argument("--timeout-minutes", type=int, default=20)
    return parser.parse_args()


def passages_to_show_of(replay: Path) -> str | None:
    file = replay / "passages-to-show.txt"
    return file.read_text(encoding="utf-8").strip() if file.is_file() else None


def consuming_repository() -> Path | None:
    """The repository the catalog is a submodule of, or None when the catalog is a clone of its own."""
    superproject = subprocess.run(["git", "-C", str(CATALOG), "rev-parse", "--show-superproject-working-tree"], capture_output=True, text=True).stdout.strip()
    return Path(superproject) if superproject else None


def build_the_folder_a_session_runs_in(folder: Path, arm: Arm, replay: Path, repository: Path | None) -> None:
    if folder.exists():
        shutil.rmtree(folder)
    documents = replay / "documents"
    if documents.is_dir():
        shutil.copytree(documents, folder)
    else:
        folder.mkdir(parents=True)

    its_claude_folder = repository / ".claude" if repository else None
    if its_claude_folder and its_claude_folder.is_dir():
        for instructions in (repository / "CLAUDE.md", its_claude_folder / "CLAUDE.md"):
            if instructions.is_file():
                target = folder / instructions.relative_to(repository)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(instructions, target)
        if (its_claude_folder / "rules").is_dir():
            copy_the_rules(its_claude_folder / "rules", folder / ".claude" / "rules", arm)
    else:
        arm.puts_the_catalogs_folder(PurePosixPath("rules/universal"), folder / ".claude" / "rules" / "01-universal-shared")


def copy_the_rules(source: Path, destination: Path, arm: Arm) -> None:
    """Copies a rules folder. What in it is a link into the catalog is written in the arm's version instead."""
    for entry in sorted(source.iterdir()):
        what_it_is = entry.resolve()
        if what_it_is.is_relative_to(CATALOG):
            arm.puts_the_catalogs_folder(PurePosixPath(what_it_is.relative_to(CATALOG).as_posix()), destination / entry.name)
        elif entry.is_dir():
            copy_the_rules(entry, destination / entry.name, arm)
        else:
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, destination / entry.name)


def started_run(arm: Arm, number: int, folder: Path, prompt: Path, results: Path, arguments: argparse.Namespace) -> Run:
    claude = shutil.which("claude")
    if not claude:
        sys.exit("claude isn't on the PATH")
    command = [claude, "-p", "--allowedTools", arguments.tools, "--strict-mcp-config", "--output-format", "json"]
    if arguments.model:
        command += ["--model", arguments.model]
    result_file = results / f"{arm.name}-{number}.json"
    with prompt.open("rb") as the_prompt, result_file.open("wb") as the_result, (results / f"{arm.name}-{number}.errors.txt").open("wb") as its_errors:
        process = subprocess.Popen(command, cwd=folder, stdin=the_prompt, stdout=the_result, stderr=its_errors)
    return Run(arm, number, result_file, process)


def report(run: Run, passages_to_show: str | None, results: Path) -> bool:
    """Prints what the run answered, and returns whether it gave an answer."""
    print(f"\n== {run.name}")
    try:
        result = json.loads(run.result_file.read_text(encoding="utf-8"))
        answer = result["result"]
    except (ValueError, KeyError, OSError):
        print(f"   No answer. See {run.result_file} and {run.result_file.with_suffix('').name}.errors.txt beside it.")
        return False
    (results / f"{run.name}.md").write_text(answer, encoding="utf-8")
    print(f"   {result.get('num_turns')} turns, with {', '.join((result.get('modelUsage') or {}).keys()) or 'an unnamed model'}")
    if not passages_to_show:
        print(answer)
        return True
    matching = [passage for passage in passages_of(answer) if re.search(passages_to_show, passage, re.IGNORECASE)]
    for passage in matching:
        print("   > " + " ".join(passage.split()))
    if not matching:
        print(f"   Nothing in the answer matches {passages_to_show}")
    return True


def passages_of(answer: str) -> list[str]:
    """The answer's paragraphs, with each list item a passage of its own."""
    return [passage.strip() for passage in re.split(r"\n\s*\n|\n(?=\s*(?:[-*]|\d+\.)\s)", answer) if passage.strip()]


if __name__ == "__main__":
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8")
    main()
