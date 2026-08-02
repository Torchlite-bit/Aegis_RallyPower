#!/usr/bin/env python3
"""AegisRP structural verifier.

No standalone Lua 5.0 interpreter is assumed, so this catches the two failure
classes that brick a 1.12 addon before it ever loads:

  1. Structural imbalance - unmatched ( ) { } or a function/if/for/while count
     that doesn't equal the `end` count (after stripping comments + strings).
  2. Lua 5.1-isms that do not exist in the 1.12 client's Lua 5.0:
       - the `#` length operator          (use table.getn)
       - string.gmatch                    (use string.gfind)
       - select(...)                      (use table.getn / arg)
       - the numeric `%` modulo operator  (use math.mod)

Run after EVERY edit:
    python3 scripts/verify.py                # Core/ + Classes/ + PallyPower/
    python3 scripts/verify.py path/to.lua    # or specific files

Exit code 0 = all clean; 1 = problems found. In-game testing is still the real
test - runtime errors print to chat.
"""
import re
import sys
import glob
import os

def _long_bracket(src: str, i: int):
    """If src[i:] opens a Lua long bracket ([[ or [=*[ ), return the index just
    past its matching close, else None. Used for both [[strings]] and --[[block
    comments]], which share the syntax."""
    if src[i] != "[":
        return None
    j = i + 1
    while j < len(src) and src[j] == "=":
        j += 1
    if j >= len(src) or src[j] != "[":
        return None
    close = "]" + "=" * (j - i - 1) + "]"
    end = src.find(close, j + 1)
    return len(src) if end == -1 else end + len(close)


def strip_lua(src: str) -> str:
    """Remove comments and string literals so only structural code remains.

    Handles -- line comments, --[[ long comments ]], '...'/"..." strings with
    backslash escapes, and [[ long strings ]]. Long comments matter: treating
    one as a line comment leaves its BODY as live code, and a commented-out
    block full of do/end and brackets then reads as a structural imbalance.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        if src[i:i+2] == "--":
            # --[[ long comment ]] first; otherwise a plain line comment
            end = _long_bracket(src, i + 2) if i + 2 < n else None
            if end is not None:
                i = end
                continue
            j = src.find("\n", i)
            i = j if j != -1 else n
            continue
        end = _long_bracket(src, i)
        if end is not None:                 # [[ long string ]]
            i = end
            continue
        c = src[i]
        if c in "\"'":
            q = c
            i += 1
            while i < n and src[i] != q:
                if src[i] == "\n":          # unterminated: don't run away
                    break
                i += 2 if src[i] == "\\" else 1
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)

def check(path: str) -> bool:
    src = open(path, encoding="utf-8", errors="replace").read()
    t = strip_lua(src)
    problems = []

    pairs = [("(", ")"), ("{", "}"), ("[", "]")]
    for a, b in pairs:
        if t.count(a) != t.count(b):
            problems.append(f"{a}{b} imbalance: {t.count(a)} vs {t.count(b)}")

    # function/if/for/while each take one `end`. A BARE `do ... end` block also
    # takes one, but the `do` belonging to a for/while does not - so count only
    # those `do`s with no for/while ahead of them on the same line.
    openers = len(re.findall(r"\bfunction\b|\bif\b|\bfor\b|\bwhile\b", t))
    for line in t.split("\n"):
        if re.search(r"\bdo\b", line) and not re.search(r"\b(for|while)\b", line):
            openers += 1
    enders = len(re.findall(r"\bend\b", t))
    # `repeat ... until` doesn't use `end`; this codebase doesn't use repeat.
    if openers != enders:
        problems.append(f"block imbalance: {openers} openers vs {enders} end")

    if re.search(r"#\w", t):
        problems.append("Lua 5.1-ism: '#' length operator (use table.getn)")
    if "gmatch" in t:
        problems.append("Lua 5.1-ism: string.gmatch (use string.gfind)")
    if re.search(r"\bselect\s*\(", t):
        problems.append("Lua 5.1-ism: select() (not in Lua 5.0)")
    if re.search(r"[%w%)]\s*%%\s*[%w%(]".replace("%w", r"\w").replace("%)", r"\)").replace("%(", r"\("), t):
        problems.append("Lua 5.1-ism: numeric % operator (use math.mod)")

    name = os.path.relpath(path)
    if problems:
        print(f"FAIL  {name}")
        for p in problems:
            print(f"      - {p}")
        return False
    print(f"OK    {name}  ()={t.count('(')} blocks={openers}")
    return True

def main():
    args = sys.argv[1:]
    if args:
        files = args
    else:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        # PallyPower/ is vendored and meant to stay untouched - scanning it is a
        # tripwire for accidental edits to the engine, not an invitation to edit.
        files = sorted(glob.glob(os.path.join(root, "Core", "*.lua"))) + \
                sorted(glob.glob(os.path.join(root, "Classes", "*.lua"))) + \
                sorted(glob.glob(os.path.join(root, "PallyPower", "*.lua")))
    ok = True
    for f in files:
        ok = check(f) and ok
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
