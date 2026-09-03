#!/usr/bin/env bash
# Everything mechanical from CLAUDE.md's pre-commit self-check, in one command.
#
#   ./scripts/check.sh
#
# What it does NOT cover, and never will: anything visual. Layout, colour,
# clipping, whether a strip reads right under pressure - those need a real
# client and a person looking at it. A green run here is permission to commit,
# not evidence the thing works.
#
# Nothing under scripts/ is in the .toc, so adding to this is never a release
# and never a version bump.
set -u
cd "$(dirname "$0")/.."

fail=0
run() {   # run <label> <cmd...>
    printf '\n=== %s ===\n' "$1"; shift
    if "$@"; then :; else fail=1; printf '^^ FAILED\n'; fi
}

run "verify (balance + Lua 5.0 rules)"  python3 scripts/verify.py
run "upvalues (32-upvalue ceiling)"     python3 scripts/lint/upvalues.py
run "scoping (local read as a global)"  python3 scripts/lint/scoping.py
run "definitions (lost to an edit)"     python3 scripts/lint/definitions.py
run "version (three bump sites agree)"  python3 scripts/lint/version.py

printf '\n=== off-client tests ===\n'
for t in scripts/test_*.lua; do
    if out=$(lua "$t" 2>&1); then
        printf 'ok   %-28s %s\n' "$(basename "$t")" "$(printf '%s' "$out" | tail -1)"
    else
        fail=1
        printf 'FAIL %s\n%s\n' "$(basename "$t")" "$out"
    fi
done

printf '\n=== vendored engine untouched ===\n'
if [ -z "$(git diff --stat PallyPower/)" ]; then
    echo "ok   PallyPower/ is byte-identical"
else
    fail=1
    echo "FAIL PallyPower/ has been edited - extend it by save-and-replace instead"
    git diff --stat PallyPower/
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    echo "ALL CHECKS PASSED - still needs an in-game look for anything visual"
else
    echo "CHECKS FAILED"
fi
exit "$fail"
