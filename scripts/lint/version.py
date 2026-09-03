#!/usr/bin/env python3
"""The version number, checked in every place it is written.

WHY THIS EXISTS. A bump touches THREE files and nothing but attention has held
them together. Miss one and the addon reports a version that does not match the
release it is -- which matters more than it sounds, because "check the version"
is the first line of every bug report, and a stale number sends the reporter
and the reader to different code.

RallyPower has no `A.version` global (Exchange does, and SBR has a `ver` in its
core lua). `PallyPower_Version` belongs to the vendored engine and is NOT ours
to bump, so this deliberately ignores it -- see CLAUDE.md.

What it deliberately does NOT check is whether the bump was the RIGHT KIND.
Minor-versus-patch is a judgement about whether a release added a capability,
and CLAUDE.md is where that judgement is written down; a lint that guessed at
it from changelog headings would be wrong often enough to be ignored, and an
ignored lint is worse than none.

Usage:  python3 scripts/lint/version.py
"""
import re
import sys

SEMVER = r"(\d+\.\d+\.\d+)"


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def main():
    found = {}
    problems = []

    m = re.search(r"^## Version:\s*" + SEMVER, read("Aegis_RallyPower.toc"), re.M)
    if m:
        found["Aegis_RallyPower.toc (## Version:)"] = m.group(1)
    else:
        problems.append("Aegis_RallyPower.toc: no '## Version: X.Y.Z' line")

    m = re.search(r"^# Aegis: RallyPower \(v" + SEMVER + r"\)", read("README.md"), re.M)
    if m:
        found["README.md (H1)"] = m.group(1)
    else:
        problems.append("README.md: H1 is not '# Aegis: RallyPower (vX.Y.Z)'")

    # newest CHANGELOG entry: the first "## [X.Y.Z]" under [Unreleased]
    m = re.search(r"^## \[" + SEMVER + r"\]", read("CHANGELOG.md"), re.M)
    if m:
        found["CHANGELOG.md (newest entry)"] = m.group(1)
    else:
        problems.append("CHANGELOG.md: no '## [X.Y.Z]' entry")

    # CLAUDE.md is not a release site, but a stale number there misleads the
    # next session about where the project is, so it is checked and reported
    # separately rather than failing the run.
    m = re.search(r"^Current version: \*\*" + SEMVER + r"\*\*", read("CLAUDE.md"), re.M)
    claude = m.group(1) if m else None

    for label, v in sorted(found.items()):
        print("  %-36s %s" % (label, v))
    if claude:
        print("  %-36s %s  (not a release site)" % ("CLAUDE.md (Current version)", claude))

    versions = set(found.values())
    if len(versions) > 1:
        problems.append("the three release sites disagree: "
                        + ", ".join(sorted(versions)))
    elif versions and claude and claude not in versions:
        print("\nwarn CLAUDE.md says %s but the release is %s -- not a release "
              "site, but it misleads the next session" % (claude, list(versions)[0]))

    if problems:
        print("\nversion: FAILED")
        for p in problems:
            print("  - " + p)
        return 1
    print("\nversion: ok (%s)" % (list(versions)[0] if versions else "?"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
