#!/usr/bin/env python3
"""Sync tracked dotfiles between this repo and `$HOME`.

Usage:
    python sync.py install [--dry-run] [--force]   # repo    -> ~
    python sync.py save    [--dry-run]             # ~       -> repo
    python sync.py fetch                 # git pull + dry-run install
    python sync.py commit                # save + git commit/push

`TRACKED` lists the home-relative paths under management. Files sync by exact
path; directories mirror their entire subtree (new files discovered, deletions
propagated). Nothing outside those tracked entries is ever touched.
"""

from __future__ import annotations

import argparse
import filecmp
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
HOME = Path.home()

# Every per-file line is printed through `report`, so the action word is the one
# place a color is chosen: green means something was written, red means
# something was removed, grey means nothing happened. Colors are dropped
# entirely when stdout isn't a terminal (a piped `sync fetch` stays greppable)
# or when NO_COLOR is set — see https://no-color.org.
ANSI = {"green": "\033[32m", "grey": "\033[90m", "red": "\033[31m"}
RESET = "\033[0m"

ACTION_COLORS = {
    "copy": "green",
    "would copy": "green",
    "delete": "red",
    "would delete": "red",
    "would rmdir": "red",
    "skip": "grey",
    "keep": "grey",
    "missing": "grey",
}

USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def paint(text: str, color: str | None) -> str:
    if not color or not USE_COLOR:
        return text
    return f"{ANSI[color]}{text}{RESET}"


def report(action: str, detail: str) -> None:
    """Print one aligned `<action> <path>` line, colored by the action."""
    print(paint(f"{action:<12} {detail}", ACTION_COLORS.get(action)))

# Home-relative paths under management. A directory mirrors its whole subtree,
# so keep these narrow: `~/.claude` as a whole would drag in tasks/, telemetry/,
# projects/, and every cache Claude Code writes there.
ALIASES_REL = ".config/shell/aliases.zsh"
ALIASES_SOURCE_LINE = f'[ -f "$HOME/{ALIASES_REL}" ] && source "$HOME/{ALIASES_REL}"'

TRACKED = [
    ".claude/CLAUDE.md",
    ".claude/settings.json",
    ".claude/hooks",
    ".claude/skills",
    ".claude/statusline-command.sh",
    ".gitconfig",
    ALIASES_REL,
    ".config/git/hooks",
    ".config/git/ignore",
    ".config/git/issue-prefixes",
    ".config/nvim",
    ".config/worktrunk/config.toml",
]

# Names never mirrored, matched against every path component inside a tracked
# directory. `.git`/`.jj` because a nested repo copied into this one becomes a
# broken gitlink — and ~/.config/nvim keeps its own checkout until that fork is
# retired. The rest is machine-local noise: caches, Finder droppings, and
# Claude Code's per-project permission grants.
UNSYNCED = {".git", ".jj", "__pycache__", ".DS_Store", "settings.local.json"}


class Stats:
    def __init__(self) -> None:
        self.copied = 0
        self.deleted = 0
        self.unchanged = 0
        self.kept = 0


def entry_kind(rel: str) -> str:
    """Whether a tracked entry is a file or a directory.

    Checks the repo first, then `$HOME`, so an entry newly added to TRACKED
    that so far only exists on this machine still resolves on its first save.
    """
    for base in (REPO_ROOT, HOME):
        path = base / rel
        if path.is_dir():
            return "dir"
        if path.is_file():
            return "file"
    return "missing"


def relative_files(root: Path) -> set[Path]:
    """Every syncable file under `root`, relative to it.

    Both directions walk through here, so an `UNSYNCED` name is invisible to the
    whole sync: never copied, and never counted as a deletion on the other side.
    """
    if not root.is_dir():
        return set()
    files: set[Path] = set()
    for dirpath, dirnames, filenames in os.walk(root):
        # Pruning in place is what keeps the walk out of a 1 MB `.git` entirely.
        dirnames[:] = [d for d in dirnames if d not in UNSYNCED]
        here = Path(dirpath)
        for name in filenames:
            path = here / name
            if name not in UNSYNCED and path.is_file():
                files.add(path.relative_to(root))
    return files


def copy_file(src: Path, dst: Path, dry_run: bool, rel_label: str, stats: Stats) -> None:
    action = "would copy" if dry_run else "copy"
    report(action, rel_label)
    if not dry_run:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    stats.copied += 1


def delete_file(path: Path, dry_run: bool, rel_label: str, stats: Stats, allow: bool = True) -> None:
    if not allow:
        report("keep", f"{rel_label} (deletion declined)")
        stats.kept += 1
        return
    action = "would delete" if dry_run else "delete"
    report(action, rel_label)
    if not dry_run:
        path.unlink()
    stats.deleted += 1


def prune_empty_dirs(root: Path, dry_run: bool) -> None:
    """Drop directories a sync emptied, deepest first so parents collapse too.

    `UNSYNCED` trees are off limits: a sync never writes into `~/.config/nvim/.git`,
    so an empty `.git/refs/tags/` in there is that repo's business, not ours.
    """
    if not root.is_dir():
        return
    candidates = []
    for dirpath, dirnames, _ in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in UNSYNCED]
        if (path := Path(dirpath)) != root:
            candidates.append(path)

    for path in sorted(candidates, key=lambda p: len(p.parts), reverse=True):
        if not any(path.iterdir()):
            if dry_run:
                report("would rmdir", f"{path.relative_to(root.parent)}/")
            else:
                path.rmdir()


def sync_file_entry(src: Path, dst: Path, rel_label: str, dry_run: bool, stats: Stats, allow_deletes: bool = True) -> None:
    if src.is_file():
        if dst.is_file() and filecmp.cmp(src, dst, shallow=False):
            report("skip", f"{rel_label} (identical)")
            stats.unchanged += 1
        else:
            copy_file(src, dst, dry_run, rel_label, stats)
    elif dst.is_file():
        delete_file(dst, dry_run, rel_label, stats, allow_deletes)


def sync_dir_entry(src_dir: Path, dst_dir: Path, name: str, dry_run: bool, stats: Stats, allow_deletes: bool = True) -> None:
    src_files = relative_files(src_dir)
    dst_files = relative_files(dst_dir)

    for rel in sorted(src_files):
        label = f"{name}/{rel.as_posix()}"
        src = src_dir / rel
        dst = dst_dir / rel
        if dst.is_file() and filecmp.cmp(src, dst, shallow=False):
            report("skip", f"{label} (identical)")
            stats.unchanged += 1
        else:
            copy_file(src, dst, dry_run, label, stats)

    for rel in sorted(dst_files - src_files):
        label = f"{name}/{rel.as_posix()}"
        delete_file(dst_dir / rel, dry_run, label, stats, allow_deletes)

    if allow_deletes:
        prune_empty_dirs(dst_dir, dry_run)


def planned_deletions(src_root: Path, dst_root: Path) -> list[str]:
    """Destination files a real sync would delete, mirroring `run`'s walk."""
    doomed: list[str] = []
    for rel in TRACKED:
        kind = entry_kind(rel)
        src, dst = src_root / rel, dst_root / rel
        if kind == "missing" or not src.exists():
            continue
        if kind == "file":
            if not src.is_file() and dst.is_file():
                doomed.append(rel)
        else:
            for sub in sorted(relative_files(dst) - relative_files(src)):
                doomed.append(f"{rel}/{sub.as_posix()}")
    return doomed


def confirm_install_deletions(force: bool) -> bool:
    """Deletions under `~` need a yes; copies are recoverable from git, these aren't.

    Files present in `~` but not in the repo are usually work authored on this
    machine that hasn't been `save`d yet — wiping them silently is how a new
    skill dies. Returns whether deletions may proceed; declining (or a
    non-interactive stdin) still lets the copy pass run.
    """
    doomed = planned_deletions(REPO_ROOT, HOME)
    if not doomed or force:
        return True

    print("install would DELETE from ~ (present locally, absent in repo):")
    for label in doomed:
        print(paint(f"    {label}", "red"))
    print("If these are un-saved local work, answer no and run `sync save` first.")
    try:
        answer = input(f"Delete {len(doomed)} file(s)? [y/N] ").strip().lower()
    except EOFError:
        answer = ""
    if answer != "y":
        print("keeping local files — copies will still sync\n")
        return False
    print()
    return True


def run(direction: str, dry_run: bool, force: bool = False) -> None:
    if direction == "install":
        src_root, dst_root = REPO_ROOT, HOME
    else:
        src_root, dst_root = HOME, REPO_ROOT

    print(f"{direction}: {src_root} -> {dst_root}" + ("  [dry-run]" if dry_run else ""))

    # Guard install deletions only: `save`'s destination is the repo, where a
    # bad deletion is one `git checkout` away. Dry runs stay unguarded so
    # `fetch` keeps showing the full plan, deletions included.
    allow_deletes = True
    if direction == "install" and not dry_run:
        allow_deletes = confirm_install_deletions(force)

    stats = Stats()
    for rel in TRACKED:
        kind = entry_kind(rel)
        if kind == "missing":
            report("missing", f"{rel} (absent from both repo and ~ — skipped)")
            continue

        src = src_root / rel
        dst = dst_root / rel

        # A tracked root absent on the source side means it hasn't been
        # bootstrapped yet, not that it was deleted. Mirroring here would wipe
        # the destination copy, so skip. Deletions *within* a tracked directory
        # still propagate via sync_dir_entry.
        if not src.exists():
            report("skip", f"{rel} (absent on source side — nothing to sync)")
            continue

        if kind == "file":
            sync_file_entry(src, dst, rel, dry_run, stats, allow_deletes)
        else:
            sync_dir_entry(src, dst, rel, dry_run, stats, allow_deletes)

    summary = f"\n{stats.copied} copied, {stats.deleted} deleted, {stats.unchanged} unchanged"
    if stats.kept:
        summary += f", {stats.kept} kept (deletions declined)"
    print(summary)

    if direction == "install":
        remind_about_aliases()


def remind_about_aliases() -> None:
    """Nudge if `~/.zshrc` doesn't source the aliases file we just installed.

    `.zshrc` is deliberately untracked — it holds per-machine PATH exports — so
    a fresh machine receives `aliases.zsh` with nothing sourcing it. Stays quiet
    once the line is present, so this only speaks up when it's actually needed.
    """
    if not (HOME / ALIASES_REL).is_file():
        return
    try:
        zshrc = (HOME / ".zshrc").read_text()
    except OSError:
        zshrc = ""
    if ALIASES_REL in zshrc:
        return

    print(
        f"\nHey! Your aliases are installed, but ~/.zshrc doesn't source them yet."
        f"\nTo load them, run:\n\n    echo '{ALIASES_SOURCE_LINE}' >> ~/.zshrc"
        f"\n\nThen open a new shell (or: source ~/.zshrc)."
    )


def run_git(args: list[str]) -> None:
    subprocess.run(["git", *args], cwd=REPO_ROOT, check=True)


def git_out(args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def ensure_on_main() -> None:
    """Get onto `main`; a colocated jj repo leaves git HEAD detached."""
    if git_out(["branch", "--show-current"]) == "main":
        return
    if git_out(["rev-parse", "HEAD"]) != git_out(["rev-parse", "main"]):
        sys.exit("error: HEAD is detached away from main — resolve that before syncing")
    run_git(["checkout", "main"])


def fetch() -> None:
    ensure_on_main()
    run_git(["pull", "--ff-only"])
    print()
    run("install", dry_run=True)


def commit() -> None:
    ensure_on_main()
    run("save", dry_run=False)
    print()
    run_git(["status", "--short"])

    message = ""
    while not message:
        message = input("Commit message: ").strip()

    confirm = input(f'Commit "{message}" to main and push? [y/N] ').strip().lower()
    if confirm != "y":
        print("aborted")
        return

    run_git(["add", "-A"])
    run_git(["commit", "-m", message])
    run_git(["push"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subs = parser.add_subparsers(dest="command", required=True)
    for cmd, help_text in [("install", "repo -> ~"), ("save", "~ -> repo")]:
        sp = subs.add_parser(cmd, help=help_text)
        sp.add_argument("--dry-run", action="store_true", help="preview without writing")
        if cmd == "install":
            sp.add_argument("--force", action="store_true", help="delete from ~ without confirming")
    subs.add_parser("fetch", help="git pull + dry-run install")
    subs.add_parser("commit", help="save + git commit/push")

    args = parser.parse_args()
    if args.command == "fetch":
        fetch()
    elif args.command == "commit":
        commit()
    else:
        run(args.command, args.dry_run, getattr(args, "force", False))


if __name__ == "__main__":
    main()
