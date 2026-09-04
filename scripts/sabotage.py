#!/usr/bin/env python3
"""Breaks the code on purpose and checks the suites NOTICE.

A green suite proves nothing on its own. It might be green because the code is
right, or because the assertions cannot tell right from wrong -- and the second
kind is indistinguishable from the first until something ships broken. Both
have happened in this suite: Exchange shipped a release that passed every check
and would not load, and RallyPower shipped Faerie Fire and Demoralizing Roar
with blank icons while `test_duties.lua` was green (it did not yet check for an
icon at all).

So each entry below is a REAL bug -- usually the exact mistake the code is
written to avoid -- applied to a throwaway copy of the tree. The named suite
must FAIL. A sabotage that slips through is reported loudly: it means that
suite is not testing what its name claims.

Nothing here touches the working tree. Every mutation is applied inside a
temporary copy, which is deleted afterwards.

Engine ported from Aegis: Exchange (`tests/sabotage.py`); the catalogue is
RallyPower's own, because a sabotage is only meaningful against the invariant
it attacks.

Usage:  python3 scripts/sabotage.py [name-substring]
"""
import os
import shutil
import subprocess
import sys
import tempfile

SUITES = {
    "duties":    "scripts/test_duties.lua",
    "groupbuff": "scripts/test_groupbuff.lua",
    "rotation":  "scripts/test_rotation.lua",
    "strip":     "scripts/test_strip.lua",
    "cc":        "scripts/test_cc.lua",
}

# (name, file, find, replace, suite that must fail)
SABOTAGES = [
    # ---- duty catalogue --------------------------------------------------
    # Wids are the wire identity of a duty. A collision silently merges two
    # duties on every remote client, with no error anywhere.
    ("wid-collision", "Classes/Class_Druid.lua",
     'key="FAERIEFIRE", wid=26,',
     'key="FAERIEFIRE", wid=7,',
     "duties"),

    # 19 was the cancelled Priest Tank Shield. Reusing it makes an older client
    # apply a stale assignment to the wrong duty.
    ("retired-wid-19-reused", "Classes/Class_Druid.lua",
     'key="DEMOROAR",   wid=27,',
     'key="DEMOROAR",   wid=19,',
     "duties"),

    # The exact bug that shipped in 1.8.0: no fallback icon, so the card is a
    # blank square for everyone who cannot resolve the spell from their own
    # spellbook -- which is everyone not of that class.
    ("duty-without-icon", "Classes/Class_Druid.lua",
     ' icon="Interface\\\\Icons\\\\Spell_Nature_FaerieFire" }',
     ' }',
     "duties"),

    # Vanilla allows one curse per target, so two owners is a plan that cannot
    # physically happen.
    ("curse-made-multi-owner", "Classes/Class_Warlock.lua",
     'key="CURSE_ELEMENTS",     wid=11, class="WARLOCK", tab="debuff",  spell="Curse of the Elements",  target="none",   multi=false',
     'key="CURSE_ELEMENTS",     wid=11, class="WARLOCK", tab="debuff",  spell="Curse of the Elements",  target="none",   multi=true',
     "duties"),

    # ---- rotations -------------------------------------------------------
    # One engine, two rotations. Sharing an implementation must not mean
    # sharing STATE: a taunt order leaking into the kick order is the whole
    # risk of that refactor.
    ("rotations-share-one-store", "Core/Aegis_Assign.lua",
     'taunt = { save = "tauntOrder", domain = "tauntorder" },',
     'taunt = { save = "kickOrder", domain = "tauntorder" },',
     "rotation"),

    ("rotation-cap-off-by-one", "Core/Aegis_Assign.lua",
     "        if table.getn(s) >= MAX_ROT then return false end",
     "        if table.getn(s) > MAX_ROT then return false end",
     "rotation"),

    # Pruning has to reach EVERY rotation, or a leaver sits in one of them
    # forever. The generic loop exists precisely so adding a rotation cannot
    # forget the pruner.
    ("prune-only-first-rotation", "Core/Aegis_Assign.lua",
     "    for i = 1, table.getn(ROT_ORDER) do\n        local def = ROT_KIND[ROT_ORDER[i]]",
     "    for i = 1, 1 do\n        local def = ROT_KIND[ROT_ORDER[i]]",
     "rotation"),

    # A self-reported cooldown routed to the wrong rotation puts a taunt
    # timer on someone's kick.
    ("cooldown-routed-to-wrong-rotation", "Core/Aegis_Sync.lua",
     'AegisRP.NoteRemoteCooldown((cmd == "KICK") and "kick" or "taunt",',
     'AegisRP.NoteRemoteCooldown("kick",',
     "rotation"),

    # ---- group buffs, overrides and the wire -----------------------------
    # Catalog order is what makes the panel and the wire agree. Insertion
    # order looks fine locally and desyncs the moment it crosses.
    ("groupbuffs-insertion-order", "Core/Aegis_Assign.lua",
     """    local cat = BuffCatalogFor(caster, c)
    for i = 1, table.getn(cat) do
        local nm = cat[i].name or cat[i].group
        if nm and c.gbuff[group][nm] then table.insert(out, nm) end
    end""",
     """    for nm in pairs(c.gbuff[group]) do table.insert(out, nm) end""",
     "groupbuff"),

    ("group-bounds-accept-zero", "Core/Aegis_Assign.lua",
     "    if not g or g < 1 or g > MAX_GROUPS then return nil end",
     "    if not g or g < 0 or g > MAX_GROUPS then return nil end",
     "groupbuff"),

    # The group plan and the class plan are separate. Clearing one must not
    # touch the other -- wiping the hidden view is invisible destruction.
    ("clear-groups-also-wipes-class", "Core/Aegis_Assign.lua",
     """    if not (c and c.gbuff) then return true end
    c.gbuff = nil""",
     """    if not (c and c.gbuff) then return true end
    c.gbuff = nil
    c.cbuff = nil""",
     "groupbuff"),

    # The exact bug the override wire test caught before it shipped: the
    # section silently never goes out, and nothing in game says so.
    ("override-section-never-sent", "Core/Aegis_Sync.lua",
     '        if table.getn(ents) > 0 then table.insert(parts, "p" .. table.concat(ents, ",")) end',
     '        if false then table.insert(parts, "p" .. table.concat(ents, ",")) end',
     "groupbuff"),

    # ---- crowd control ---------------------------------------------------
    # CC shares the duty catalog AND its wid space. Accepting a non-CC wid in
    # the CC section installs a debuff key where every reader expects a CC
    # spell: no error, just a mark that says "Sunder Armor" on remote clients.
    ("cc-accepts-any-wid", "Core/Aegis_Sync.lua",
     '                if m and def and def.tab == "cc" then block.cc[m] = def.key end',
     '                if m and def then block.cc[m] = def.key end',
     "cc"),

    # The exact bug this suite caught before it shipped: the cc domain was not
    # in the dirty list, so every CC edit stayed local and nothing said so.
    ("cc-never-broadcast", "Core/Aegis_Sync.lua",
     '       or domain == "gbuff" or domain == "pbuff" or domain == "cc" then',
     '       or domain == "gbuff" or domain == "pbuff" then',
     "cc"),

    # Marks are walked 1..N so the wire has a deterministic order, exactly as
    # the group section walks the catalog. pairs() looks fine locally.
    ("cc-wire-unordered", "Core/Aegis_Sync.lua",
     """        for m = 1, maxm do
            local key = c.cc[m]""",
     """        for m in pairs(c.cc) do
            local key = c.cc[m]""",
     "cc"),

    # A key nothing in the catalog answers to serialises to nothing: assigned
    # here, invisible everywhere else.
    ("cc-stores-unknown-key", "Core/Aegis_Assign.lua",
     '        if not (def and def.tab == "cc") then return false end',
     '        if false then return false end',
     "cc"),

    # A mark has one owner. If AssignMark stops evicting, handing skull to the
    # warlock leaves the mage on it too and both walk in.
    ("cc-assign-does-not-evict", "Core/Aegis_Assign.lua",
     '        if holders[i].caster ~= caster then A.SetCC(holders[i].caster, m, nil) end',
     '        if false then A.SetCC(holders[i].caster, m, nil) end',
     "cc"),

    # ---- strip engine ----------------------------------------------------
    # Each strip carries its own grip scale. Inverting the conversion still
    # "works" -- it just parks the frame somewhere visibly wrong, and only at
    # a scale other than 1.0.
    ("snap-scale-inverted", "Core/Aegis_Strip.lua",
     "        local k = os / es                      -- their space -> ours",
     "        local k = es / os                      -- their space -> ours",
     "strip"),

    ("snap-threshold-inclusive", "Core/Aegis_Strip.lua",
     "        if d < bestD then best, bestD = cands[i], d end",
     "        if d <= bestD then best, bestD = cands[i], d end",
     "strip"),

    # A paladin has no class-buff strip, so the legacy buff bar is the only
    # thing their Taunt strip can line up with. Dropping it from the target
    # list is invisible except to someone dragging on a paladin.
    ("snap-ignores-engine-frames", "Core/Aegis_Strip.lua",
     "        neighbour(getglobal(fs.name), fs.pad)",
     "",
     "strip"),

    # The buff bar is 110 wide with its buttons 5px in; our strips are 100.
    # Without the pad the snapper lines up frame boxes, and the two columns a
    # player actually sees end up 5px out of step -- which is the whole point
    # of docking a strip against the bar.
    ("snap-ignores-content-pad", "Core/Aegis_Strip.lua",
     "        if pad then ol = ol + pad * k; oright = oright - pad * k end",
     "",
     "strip"),

    # A paladin's uiScale has no slider, so it stays 1 forever: routing them
    # to it means their Kick/Taunt strips can never be matched to the buff bar.
    ("strip-scale-ignores-engine", "Core/Aegis_Strip.lua",
     "    if cls == \"PALADIN\" and PP_PerUser and PP_PerUser.scalebar then",
     "    if false then",
     "strip"),

    # ---- panel docking ---------------------------------------------------
    # The panel carries a grip and the options frame does not, so the fit test
    # has to be in screen pixels. Scale-blind, a panel at 2.0 looks like it has
    # room it does not, and the options frame docks off the edge.
    ("dock-ignores-scale", "Core/Aegis_Strip.lua",
     "    local roomRight, roomLeft = sw - ar * as, al * as",
     "    local roomRight, roomLeft = sw - ar, al",
     "strip"),

    # No flip means a panel dragged to the right edge sends the options frame
    # off screen instead of to its left.
    ("dock-never-flips", "Core/Aegis_Strip.lua",
     "    elseif roomLeft >= needPx then",
     "    elseif false then",
     "strip"),

    # The no-room fallback exists to keep the frame ON screen. Without the
    # width subtraction it lands exactly one frame-width past the right edge.
    ("dock-fallback-offscreen", "Core/Aegis_Strip.lua",
     "        if roomRight >= roomLeft then x = sw / ms - opts:GetWidth() - DOCK_GAP end",
     "        if roomRight >= roomLeft then x = sw / ms end",
     "strip"),

    # The fallback's y is the panel's top converted out of ITS space into ours.
    ("dock-fallback-unconverted-top", "Core/Aegis_Strip.lua",
     '        opts:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, at * as / ms)',
     '        opts:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, at)',
     "strip"),

    # Docking a frame nobody can see moves it out from under a later Show.
    ("dock-ignores-shown", "Core/Aegis_Strip.lua",
     "    if not (panel:IsShown() and opts:IsShown()) then return false end",
     "",
     "strip"),

    # The 1.13.1 bug, restored: SetFrameLevel does not carry a window's
    # children, so the window ends up above its own buttons and eats every
    # click. It looks completely normal on screen.
    ("panel-raised-with-framelevel", "Core/Aegis_Strip.lua",
     "    if f and f.SetToplevel then f:SetToplevel(true) end",
     "    if f and f.SetToplevel then f:SetToplevel(true) end\n"
     "    if f and f.SetFrameLevel then f:SetFrameLevel(f:GetFrameLevel() + 10) end",
     "strip"),

    ("snap-to-hidden-strip", "Core/Aegis_Strip.lua",
     "        if o.IsShown and not o:IsShown() then return end",
     "        if false then return end",
     "strip"),

    # Without the floor the backdrop -- the only carrier of button state --
    # goes invisible and every state paints the same nothing.
    ("alpha-floor-removed", "Core/Aegis_Strip.lua",
     "    if a < ALPHA_FLOOR then a = ALPHA_FLOOR end",
     "",
     "strip"),

    # One writer for shown state. Writing the flag without moving the frame is
    # how a strip ends up hidden with a ticked "Show" box.
    ("visibility-flag-without-frame", "Core/Aegis_Strip.lua",
     "    if not shown then S.frame:Hide()",
     "    if not shown then",
     "strip"),
]


def run_one(root, sab):
    name, path, find, replace, suite = sab
    target = os.path.join(root, path)
    src = open(target, encoding="utf-8").read()
    if find not in src:
        return "STALE", ("the sabotage no longer matches the source -- the "
                         "code changed and this entry needs updating")
    open(target, "w", encoding="utf-8").write(src.replace(find, replace, 1))

    proc = subprocess.run(["lua", SUITES[suite]], cwd=root,
                          capture_output=True, text=True)
    # Restore for the next sabotage in the same copy.
    open(target, "w", encoding="utf-8").write(src)

    if proc.returncode != 0:
        return "CAUGHT", None
    return "MISSED", (proc.stdout.strip().splitlines() or ["(no output)"])[-1]


def main(argv):
    only = argv[1] if len(argv) > 1 else None

    root = tempfile.mkdtemp(prefix="aegisrp-sabotage-")
    try:
        for d in ("Core", "Classes", "scripts"):
            shutil.copytree(d, os.path.join(root, d))

        # Sanity: the suites must PASS on the unmodified copy, or every
        # "CAUGHT" below is meaningless.
        print("baseline (unmodified copy):")
        baseline_ok = True
        for suite, path in sorted(SUITES.items()):
            proc = subprocess.run(["lua", path], cwd=root,
                                  capture_output=True, text=True)
            if proc.returncode == 0:
                print("  ok   %s" % suite)
            else:
                baseline_ok = False
                print("  FAIL %s already fails before any sabotage" % suite)
                print(proc.stdout.strip())
        if not baseline_ok:
            print("\nbaseline is not green -- fix that before trusting "
                  "sabotage results")
            return 1

        print("\nsabotages (each MUST be caught):")
        missed, stale, caught = [], [], 0
        for sab in SABOTAGES:
            name = sab[0]
            if only and only not in name:
                continue
            status, detail = run_one(root, sab)
            if status == "CAUGHT":
                caught += 1
                print("  ok     %-34s caught by %s" % (name, sab[4]))
            elif status == "STALE":
                stale.append((name, detail))
                print("  stale  %-34s %s" % (name, detail))
            else:
                missed.append((name, sab[4], detail))
                print("  MISSED %-34s %s did NOT notice" % (name, sab[4]))
                print("         suite said: %s" % detail)

        print("")
        if missed:
            print("%d sabotage(s) went unnoticed. Those suites are not "
                  "testing what their names claim:" % len(missed))
            for name, suite, _ in missed:
                print("  - %s (%s)" % (name, suite))
            return 1
        if stale:
            print("%d sabotage(s) no longer match the source and need "
                  "updating:" % len(stale))
            for name, _ in stale:
                print("  - %s" % name)
            return 1
        print("sabotage: ALL %d CAUGHT" % caught)
        return 0
    finally:
        shutil.rmtree(root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
