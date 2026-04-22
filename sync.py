#!/usr/bin/env python3
"""Sync `.claude/` between this repo and `~/.claude/`.

Usage:
    python sync.py install [--dry-run]   # repo/.claude  -> ~/.claude
    python sync.py save    [--dry-run]   # ~/.claude     -> repo/.claude

Top-level children of `repo/.claude/` define what is tracked. Files sync by
exact path; directories mirror their entire subtree (new files discovered,
deletions propagated). Nothing outside those tracked entries is ever touched.
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path

REPO_CLAUDE = Path(__file__).resolve().parent / ".claude"
HOME_CLAUDE = Path.home() / ".claude"


class Stats:
    def __init__(self) -> None:
        self.copied = 0
        self.deleted = 0
        self.unchanged = 0


def tracked_entries(repo_claude: Path) -> list[Path]:
    if not repo_claude.is_dir():
        sys.exit(f"error: {repo_claude} does not exist or is not a directory")
    return sorted(repo_claude.iterdir())


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
        src_root, dst_root = REPO_CLAUDE, HOME_CLAUDE
    else:
        src_root, dst_root = HOME_CLAUDE, REPO_CLAUDE

    print(f"{direction}: {src_root} -> {dst_root}" + ("  [dry-run]" if dry_run else ""))

    stats = Stats()
    for entry in tracked_entries(REPO_CLAUDE):
        name = entry.name
        src = src_root / name
        dst = dst_root / name
        if entry.is_file():
            sync_file_entry(src, dst, name, dry_run, stats)
        elif entry.is_dir():
            sync_dir_entry(src, dst, name, dry_run, stats)

    print(f"\n{stats.copied} copied, {stats.deleted} deleted, {stats.unchanged} unchanged")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subs = parser.add_subparsers(dest="command", required=True)
    for cmd, help_text in [("install", "repo/.claude -> ~/.claude"), ("save", "~/.claude -> repo/.claude")]:
        sp = subs.add_parser(cmd, help=help_text)
        sp.add_argument("--dry-run", action="store_true", help="preview without writing")

    args = parser.parse_args()
    run(args.command, args.dry_run)


if __name__ == "__main__":
    main()
