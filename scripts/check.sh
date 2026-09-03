#!/usr/bin/env bash
# Everything mechanical from CLAUDE.md's pre-commit self-check, in one command.
#
#   ./scripts/check.sh
#
#   ./scripts/check.sh --sabotage    (adds the mutation run, slower)
#
# What it does NOT cover, and never will: anything visual. Layout, colour,
# clipping, whether a strip reads right under pressure - those need a real
# client and a person looking at it. A green run here is permission to commit,
# not evidence the thing works.
#
# --sabotage answers a different question: not "does the code pass" but "would
# the suites NOTICE if it didn't". It plants real bugs in a throwaway copy and
# requires the named suite to fail. It is off by default because it re-runs
# every suite once per mutation; run it after adding or changing a test, and
# before trusting a green suite you have not exercised.
#
# Nothing under scripts/ is in the .toc, so adding to this is never a release
# and never a version bump.
set -u
cd "$(dirname "$0")/.."

SABOTAGE=0
[ "${1:-}" = "--sabotage" ] && SABOTAGE=1

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

if [ "$SABOTAGE" -eq 1 ]; then
    run "sabotage (do the suites notice?)" python3 scripts/sabotage.py
else
    printf '\n(skipped sabotage - run ./scripts/check.sh --sabotage to verify\n'
    printf ' the suites would actually catch a bug)\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
    echo "ALL CHECKS PASSED - still needs an in-game look for anything visual"
else
    echo "CHECKS FAILED"
fi
exit "$fail"
