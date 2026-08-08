#!/usr/bin/env python3
"""Sync tracked dotfiles between this repo and `$HOME`.

Usage:
    python sync.py install [--dry-run]   # repo    -> ~
    python sync.py save    [--dry-run]   # ~       -> repo
    python sync.py fetch                 # git pull + dry-run install
    python sync.py commit                # save + git commit/push

`TRACKED` lists the home-relative paths under management. Files sync by exact
path; directories mirror their entire subtree (new files discovered, deletions
propagated). Nothing outside those tracked entries is ever touched.
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
HOME = Path.home()

# Home-relative paths under management. A directory mirrors its whole subtree,
# so keep these narrow: `~/.claude` as a whole would drag in tasks/, telemetry/,
# projects/, and every cache Claude Code writes there.
ALIASES_REL = ".config/shell/aliases.zsh"
ALIASES_SOURCE_LINE = f'[ -f "$HOME/{ALIASES_REL}" ] && source "$HOME/{ALIASES_REL}"'

TRACKED = [
    ".claude/CLAUDE.md",
    ".claude/skills",
    ".gitconfig",
    ALIASES_REL,
    ".config/worktrunk/config.toml",
]


class Stats:
    def __init__(self) -> None:
        self.copied = 0
        self.deleted = 0
        self.unchanged = 0


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
    if not root.is_dir():
        return set()
    return {p.relative_to(root) for p in root.rglob("*") if p.is_file()}


def copy_file(src: Path, dst: Path, dry_run: bool, rel_label: str, stats: Stats) -> None:
    action = "would copy" if dry_run else "copy"
    print(f"{action:<12} {rel_label}")
    if not dry_run:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    stats.copied += 1


def delete_file(path: Path, dry_run: bool, rel_label: str, stats: Stats) -> None:
    action = "would delete" if dry_run else "delete"
    print(f"{action:<12} {rel_label}")
    if not dry_run:
        path.unlink()
    stats.deleted += 1


def prune_empty_dirs(root: Path, dry_run: bool) -> None:
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            if dry_run:
                print(f"{'would rmdir':<12} {path.relative_to(root.parent)}/")
            else:
                path.rmdir()


def sync_file_entry(src: Path, dst: Path, rel_label: str, dry_run: bool, stats: Stats) -> None:
    if src.is_file():
        if dst.is_file() and filecmp.cmp(src, dst, shallow=False):
            print(f"{'skip':<12} {rel_label} (identical)")
            stats.unchanged += 1
        else:
            copy_file(src, dst, dry_run, rel_label, stats)
    elif dst.is_file():
        delete_file(dst, dry_run, rel_label, stats)


def sync_dir_entry(src_dir: Path, dst_dir: Path, name: str, dry_run: bool, stats: Stats) -> None:
    src_files = relative_files(src_dir)
    dst_files = relative_files(dst_dir)

    for rel in sorted(src_files):
        label = f"{name}/{rel.as_posix()}"
        src = src_dir / rel
        dst = dst_dir / rel
        if dst.is_file() and filecmp.cmp(src, dst, shallow=False):
            print(f"{'skip':<12} {label} (identical)")
            stats.unchanged += 1
        else:
            copy_file(src, dst, dry_run, label, stats)

    for rel in sorted(dst_files - src_files):
        label = f"{name}/{rel.as_posix()}"
        delete_file(dst_dir / rel, dry_run, label, stats)

    prune_empty_dirs(dst_dir, dry_run)


def run(direction: str, dry_run: bool) -> None:
    if direction == "install":
        src_root, dst_root = REPO_ROOT, HOME
    else:
        src_root, dst_root = HOME, REPO_ROOT

    print(f"{direction}: {src_root} -> {dst_root}" + ("  [dry-run]" if dry_run else ""))

    stats = Stats()
    for rel in TRACKED:
        kind = entry_kind(rel)
        if kind == "missing":
            print(f"{'missing':<12} {rel} (absent from both repo and ~ — skipped)")
            continue

        src = src_root / rel
        dst = dst_root / rel

        # A tracked root absent on the source side means it hasn't been
        # bootstrapped yet, not that it was deleted. Mirroring here would wipe
        # the destination copy, so skip. Deletions *within* a tracked directory
        # still propagate via sync_dir_entry.
        if not src.exists():
            print(f"{'skip':<12} {rel} (absent on source side — nothing to sync)")
            continue

        if kind == "file":
            sync_file_entry(src, dst, rel, dry_run, stats)
        else:
            sync_dir_entry(src, dst, rel, dry_run, stats)

    print(f"\n{stats.copied} copied, {stats.deleted} deleted, {stats.unchanged} unchanged")

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
    subs.add_parser("fetch", help="git pull + dry-run install")
    subs.add_parser("commit", help="save + git commit/push")

    args = parser.parse_args()
    if args.command == "fetch":
        fetch()
    elif args.command == "commit":
        commit()
    else:
        run(args.command, args.dry_run)


if __name__ == "__main__":
    main()
