"""Runs tasks in fresh Claude Code sessions, in plan mode, and prints which skills each session loaded: so that a how-to
that lives in a skill, such as one moved there from an always-loaded rule, is tested for getting loaded when its task
comes.

    python .claude-shared/rule-testing/see-which-skills-a-task-loads.py <tasks folder>
        [--runs <how many for each task>]   default: 2
        [--tool-calls <how many a session makes before it is stopped>]   default: 8, and 0 lets it finish its plan
        [--model <model>] [--in <folder the sessions run in>] [--keep-in <folder>]

A tasks folder holds a .txt file for each task: what the user would write to have it done, and nothing about skills.
Include a task the skill is not for, to see that it isn't loaded for everything.

Each session runs in the consuming repository itself, or in the folder given with --in, as any session there does: with
its rules, its skills and its code. It is in plan mode: it sees the tools for reading and for editing, reads what it
wants, changes nothing, and answers with its plan. It gets no shell and no MCP servers, and Claude Code keeps no
transcript of it. The plan file it writes under ~/.claude/plans is removed again.

A session is stopped once it has made --tool-calls tool calls. A session that loads a skill for its task does so at
once: of the 20 that loaded one when this was first used (2026-11-15), all had by their third tool call. Planning the
whole task took them 30 to 50 calls more, which cost several times as much and showed nothing more about the loading.
Let them finish, with --tool-calls 0, to read whether the plans follow the skill.

For each session the script prints the skills it loaded, each with the number of tool calls the session made before
it, and how many edits the session tried. What each session wrote and did is kept in the results folder, as a file to
read.

Every run is a fresh session, since a session keeps the rules and the list of skills it started with.
"""
from __future__ import annotations

import argparse
import io
import json
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent
TOOLS_OF_A_SESSION = "Read,Grep,Glob,Skill,Edit,Write"
TOOLS_THAT_EDIT = {"Edit", "Write"}
WHERE_PLAN_MODE_KEEPS_PLANS = Path.home() / ".claude" / "plans"


@dataclass
class FreshSession:
    """A claude session started on one task, in plan mode, which writes what it does to a file, an event to a line."""
    task: str
    name: str
    events_file: Path
    process: subprocess.Popen
    was_stopped: bool = False

    @staticmethod
    def started(task: Path, run: int, runs_in: Path, results: Path, model: str | None) -> FreshSession:
        claude = shutil.which("claude")
        if not claude:
            sys.exit("claude isn't on the PATH")
        command = [claude, "-p", "--strict-mcp-config", "--no-session-persistence", "--permission-mode", "plan",
                   "--tools", TOOLS_OF_A_SESSION, "--output-format", "stream-json", "--verbose"]
        if model:
            command += ["--model", model]
        name = f"{task.stem}-{run}"
        events_file = results / f"{name}.events.jsonl"
        with task.open("rb") as the_task, events_file.open("wb") as its_events, (results / f"{name}.errors.txt").open("wb") as its_errors:
            process = subprocess.Popen(command, cwd=runs_in, stdin=the_task, stdout=its_events, stderr=its_errors)
        return FreshSession(task.stem, name, events_file, process)

    @property
    def is_running(self) -> bool:
        return self.process.poll() is None

    @property
    def what_it_did(self) -> WhatASessionDid:
        return WhatASessionDid.read_from(self.events_file)

    def stop(self) -> None:
        self.process.kill()
        self.process.wait()
        self.was_stopped = True


@dataclass
class WhatASessionDid:
    skills_loaded: dict[str, int] = field(default_factory=dict)
    """Each skill the session loaded, with the number of tool calls it made before that one."""
    tool_calls: int = 0
    edits_tried: int = 0
    """Not counting what it wrote to its plan file."""
    plan_files: list[Path] = field(default_factory=list)
    """The files the session wrote its plan to, which plan mode lets it write."""
    as_text: list[str] = field(default_factory=list)
    """What the session wrote, and a line for each tool call, in order."""

    @staticmethod
    def read_from(events_file: Path) -> WhatASessionDid:
        it = WhatASessionDid()
        for line in events_file.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get("type") == "assistant":
                for part in event.get("message", {}).get("content", []):
                    it.take_in(part)
        return it

    def take_in(self, part: dict) -> None:
        if part.get("type") == "text":
            self.as_text.append(part["text"])
        if part.get("type") != "tool_use":
            return
        tool, its_input = part["name"], part.get("input", {})
        if tool == "Skill":
            self.skills_loaded.setdefault(its_input.get("skill", "?"), self.tool_calls)
        self.tool_calls += 1
        if tool in TOOLS_THAT_EDIT and WHERE_PLAN_MODE_KEEPS_PLANS in Path(its_input.get("file_path", "")).parents:
            self.plan_files.append(Path(its_input["file_path"]))
            self.as_text.append(f"> {tool} of its plan, {its_input['file_path']}:")
            self.as_text.append(its_input.get("content") or its_input.get("new_string", ""))
            return
        if tool in TOOLS_THAT_EDIT:
            self.edits_tried += 1
        self.as_text.append(f"> {tool} {json.dumps(its_input, ensure_ascii=False)[:300]}")

    @property
    def in_a_line(self) -> str:
        loaded = ", ".join(f"{skill} (after {calls_before} tool calls)" for skill, calls_before in self.skills_loaded.items()) or "no skill"
        return f"loaded {loaded}; {self.tool_calls} tool calls, {self.edits_tried} edits tried"


def main() -> None:
    arguments = parsed_arguments()
    tasks = sorted(Path(arguments.tasks).glob("*.txt"))
    if not tasks:
        sys.exit(f"No .txt files in {arguments.tasks}")
    runs_in = Path(arguments.runs_in).resolve() if arguments.runs_in else consuming_repository()
    if not runs_in or not runs_in.is_dir():
        sys.exit("Give the folder the sessions run in, with --in: the catalog isn't a submodule of a repository here.")
    results = Path(arguments.keep_in).resolve() if arguments.keep_in else Path(tempfile.mkdtemp(prefix="skills-a-task-loads-"))
    results.mkdir(parents=True, exist_ok=True)

    print(f"{len(tasks)} tasks, {arguments.runs} sessions each, in {runs_in}")
    sessions = [FreshSession.started(task, run, runs_in, results, arguments.model) for task in tasks for run in range(1, arguments.runs + 1)]
    wait_for(sessions, stopping_each_after=arguments.tool_calls, timeout_minutes=arguments.timeout_minutes)

    sessions_that_loaded: dict[str, Counter] = {task.stem: Counter() for task in tasks}
    for session in sessions:
        it = session.what_it_did
        (results / f"{session.name}.md").write_text("\n\n".join(it.as_text), encoding="utf-8")
        for plan_file in it.plan_files:
            plan_file.unlink(missing_ok=True)
        sessions_that_loaded[session.task].update(it.skills_loaded.keys())
        print(f"   {session.name}: {it.in_a_line}" + (", then stopped" if session.was_stopped else ""))

    print("\nSessions that loaded each skill, of", arguments.runs, "for each task:")
    for task, loaded in sessions_that_loaded.items():
        print(f"   {task}: " + (", ".join(f"{skill} {count}" for skill, count in loaded.items()) or "none"))
    print(f"\nWhat each session wrote and did: {results}")


def wait_for(sessions: list[FreshSession], stopping_each_after: int, timeout_minutes: int) -> None:
    """Waits until every session has ended, stopping each once it has made that many tool calls: 0 for no limit."""
    give_up_at = time.monotonic() + timeout_minutes * 60
    while any(session.is_running for session in sessions) and time.monotonic() < give_up_at:
        time.sleep(3)
        for session in sessions:
            if session.is_running and 0 < stopping_each_after <= session.what_it_did.tool_calls:
                session.stop()
    for session in sessions:
        if session.is_running:
            session.stop()


def parsed_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tasks", help="a folder with a .txt file for each task")
    parser.add_argument("--runs", type=int, default=2, help="sessions for each task")
    parser.add_argument("--tool-calls", type=int, default=8, help="a session is stopped once it has made this many tool calls: 0 lets it finish its plan")
    parser.add_argument("--model", help="the model the sessions run on")
    parser.add_argument("--in", dest="runs_in", help="the folder the sessions run in: by default the repository the catalog is a submodule of")
    parser.add_argument("--keep-in", help="the folder for what the sessions wrote and did: by default a new temporary one")
    parser.add_argument("--timeout-minutes", type=int, default=30)
    return parser.parse_args()


def consuming_repository() -> Path | None:
    """The repository the catalog is a submodule of, if it is one here."""
    superproject = subprocess.run(["git", "-C", str(CATALOG), "rev-parse", "--show-superproject-working-tree"], capture_output=True, text=True).stdout.strip()
    return Path(superproject) if superproject else None


if __name__ == "__main__":
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8")
    main()
