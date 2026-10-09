#!/usr/bin/env python3
"""Keep CHANGELOG.md to [Unreleased] + the current minor version.

Every released section whose minor is older than the newest release is moved,
unchanged, into docs/changelog/<major.minor>.md, together with its reference
link. Relative links are re-pointed so they still resolve from docs/changelog/;
the wording is untouched. CHANGELOG.md ends with an "Older releases" line
linking every archive. Safe to run repeatedly; a no-op when there is nothing
to move.

Usage: scripts/changelog-rollover.py [CHANGELOG.md]
"""
import re
import sys
from pathlib import Path

# Headings that were released with a typo, mapped to the minor their release
# date puts them in; the heading itself is left unchanged. None so far.
MISNUMBERED = {}

SECTION = re.compile(r"^## \[([^\]]+)\]")
# Only release compare links are footer links; a reference link such as
# `[#28]: …/issues/28` belongs to the section that uses it.
LINK = re.compile(r"^\[(Unreleased|\d+\.\d+\.\d+)\]: \S+")
OLDER = "## Older releases"
RELATIVE_LINK = re.compile(r"\]\((?!https?:|mailto:|#|\.\./\.\./)([^)\s]+)\)")


def repoint(line):
    """Re-point a repo-root-relative link so it resolves from docs/changelog/."""
    return RELATIVE_LINK.sub(r"](../../\1)", line)


def minor(version):
    if version in MISNUMBERED:
        return MISNUMBERED[version]
    return ".".join(version.split(".")[:2])


def sort_key(m):
    return tuple(int(p) for p in m.split("."))


def split(text):
    """Return (header, [(version, lines)], links) for a changelog file."""
    header, sections, links = [], [], []
    current = None
    for line in text.splitlines():
        if LINK.match(line):
            links.append(line)
        elif line.startswith(OLDER):
            current = None  # regenerated below
        elif (m := SECTION.match(line)):
            current = (m.group(1), [line])
            sections.append(current)
        elif current is not None:
            current[1].append(line)
        elif not sections:
            header.append(line)
    return header, sections, links


def strip(lines):
    while lines and lines[-1].strip() in ("", "---"):
        lines = lines[:-1]
    return lines


def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "CHANGELOG.md")
    archive_dir = path.parent / "docs" / "changelog"
    header, sections, links = split(path.read_text())

    released = [v for v, _ in sections if v != "Unreleased"]
    if not released:
        return
    keep_minor = minor(released[0])

    kept = [(v, l) for v, l in sections if v == "Unreleased" or minor(v) == keep_minor]
    moved = {}
    for v, l in sections:
        if v != "Unreleased" and minor(v) != keep_minor:
            moved.setdefault(minor(v), []).append((v, l))

    kept_versions = {v for v, _ in kept}
    kept_links = [l for l in links if LINK.match(l).group(1) in kept_versions]
    moved_links = {}
    for l in links:
        v = LINK.match(l).group(1)
        if v not in kept_versions:
            moved_links.setdefault(minor(v), []).append(l)

    archive_dir.mkdir(parents=True, exist_ok=True)
    for m, secs in moved.items():
        target = archive_dir / f"{m}.md"
        old_secs, old_links = [], []
        if target.exists():
            _, old_secs, old_links = split(target.read_text())
        body = [
            f"# Changelog — {m}.x",
            "",
            "Moved from [CHANGELOG.md](../../CHANGELOG.md), which holds the current releases. Wording unchanged; relative links re-pointed to resolve from here.",
            "",
        ]
        for _, lines in secs:
            body += [repoint(l) for l in strip(lines)] + ["", "---", ""]
        for _, lines in old_secs:
            body += strip(lines) + ["", "---", ""]
        body = strip(body) + [""]
        all_links = moved_links.get(m, []) + old_links
        if all_links:
            body += all_links + [""]
        target.write_text("\n".join(body))

    archives = sorted((p.stem for p in archive_dir.glob("*.md")), key=sort_key, reverse=True)
    out = strip(header) + [""]
    for _, lines in kept:
        out += strip(lines) + ["", "---", ""]
    out = strip(out) + [""]
    if archives:
        out += [OLDER, "", " · ".join(f"[{a}](docs/changelog/{a}.md)" for a in archives), ""]
    if kept_links:
        out += kept_links + [""]
    path.write_text("\n".join(out))


if __name__ == "__main__":
    main()
