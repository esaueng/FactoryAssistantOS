#!/usr/bin/env python3
"""Check that relative Markdown links in the repo resolve to real files.

AGENTS.md and README.md treat the docs as deliverables with valid cross-links
("Keep cross-links valid; these are deliverables"). This catches the common
rot — a renamed/moved doc leaving a dangling [text](path) link — across all
tracked Markdown files. External (http/https/mailto) and pure-anchor (#...)
links are skipped; an #anchor suffix on a file link is stripped before the
file is checked (anchor targets are not verified).

Usage: lint_links.py FILE.md [FILE.md ...]   (exits non-zero on any dead link)
"""
import os
import re
import sys

# [text](target) — capture target, ignoring images' leading ! the same way.
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def is_external(target):
    return target.startswith(("http://", "https://", "mailto:", "#", "tel:"))


def main(paths):
    dead = 0
    checked = 0
    for path in paths:
        base = os.path.dirname(os.path.abspath(path))
        try:
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read()
        except OSError as exc:
            print(f"LINK ERROR {path}: {exc}", file=sys.stderr)
            dead += 1
            continue
        for target in LINK.findall(text):
            target = target.strip()
            if is_external(target) or not target:
                continue
            # Strip anchor and any surrounding angle brackets / title.
            target = target.split()[0].strip("<>")
            target = target.split("#", 1)[0]
            if not target:
                continue
            checked += 1
            resolved = os.path.normpath(os.path.join(base, target))
            if not os.path.exists(resolved):
                print(f"DEAD LINK {path} -> {target}", file=sys.stderr)
                dead += 1
    print(f"checked {checked} relative link(s); {dead} dead")
    return 1 if dead else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("usage: lint_links.py FILE.md [FILE.md ...]\n")
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
