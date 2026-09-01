# CLAUDE.md — Aegis: RallyPower (folder: Aegis_RallyPower)

Project brief for Claude Code. Read this fully before editing anything.

## What this is

**Aegis: RallyPower** (part of the Aegis addon series, like Aegis_SBR).
Naming rules: the install folder and TOC are **`Aegis_RallyPower`**; our code
namespace, globals, frame names, and saved variables use the **`AegisRP`**
prefix (`AegisRP_Settings`, `AegisRP.Assign`, …); Core files are
`Core/Aegis_*.lua`. The embedded PallyPower engine keeps its own
`PallyPower_*`/`PP_*` names and the `PLPWR` addon-message prefix (locked
byte-compat with stock PallyPower); our sync channel prefix stays `RPCX`.
It extends
the PallyPower paladin buff addon to **all nine
classes** — a unified raid buff/utility coordinator for **Turtle WoW 1.18.1**,
which is a **1.12.1 client (Lua 5.0)** with the **SuperWoW** and **VanillaFixes**
client mods. It is a fork of PallyPowerTW; the **visual and functional gold
standard is PallyPower 3.3.5 (WotLK)** — reference source:
`github.com/AznamirWoW/PallyPower` (clone it; `PallyPower_Wrath.xml` +
`PallyPowerValues.lua` are the spec for frames, colors, dimensions).

Current version: **1.2.0**. See `CHANGELOG.md` for the full history and
`docs/` for the design documents and interactive HTML concepts.

## HARD RULES — never violate these

Not style preferences. Each one produces a runtime error, a silent failure, or
a file the client refuses to load. Shared with **Aegis: Exchange**; the two
addons keep these rules identical so a habit learned in one is safe in the
other.

### Language (Lua 5.0)

1. **Lua 5.0 only.** No `string.match`, no `string.gmatch`, no `:match()`.
   Use **`string.find`** (with captures) and **`string.gfind`** — the 5.0 name
   for what later Lua calls `gmatch`.
2. **No `#` length operator** → `table.getn(t)`. **No `table.setn`.**
3. **No `%` modulo operator** → `math.mod(a, b)`. No integer division either —
   combine `math.floor` with `math.mod`.
4. **Varargs use the `arg` table and `arg.n`.** `select()` does not exist.
5. Fine to use: `string.gsub`, `find`, `gfind`, `format`, `sub`, `lower`,
   `upper`. Only the `match`/`gmatch` family is banned.

### Events

6. **Handlers read the GLOBALS `event`, `arg1`, `arg2`…** — never
   `function(self, event, ...)`. On this client OnEvent receives no arguments;
   the client sets `this`, `event` and `arg1..argN` as globals.

7. **A handler for an event that can STORM must be O(1), state-gated, or
   coalesced behind a once-per-frame flush.** Never an unbounded rescan, never
   a per-item client query, inline in the handler.

   This is a freeze rule, not a tidiness rule — and **this addon is the
   cautionary case**. On 1.12 the client populates its item cache lazily, so
   the *first* time a session opens mail with unseen attachments it re-fires
   `BAG_UPDATE` (the stock `MAIL_SHOW` handler calls `OpenBackpack()`) dozens
   of times in a few frames. RallyPower has no mailbox feature and still
   stalled ~18s, purely because the vendored engine answered every fire with a
   full bag walk (`PallyPower.lua:576` → `PallyPower_ScanInventory`).

   A coalescing fix for that was written and then **reverted** (PR #40) once the
   mail hang was traced elsewhere, so the unbounded scan is still live. Treat it
   as a known cost, not a solved problem: if it is revisited, the shape is a
   dirty flag flushed once per frame, and the vendored engine must be wrapped
   rather than edited.

   **Never inline in a stormable handler:** `GetItemInfo` per item, any
   `GameTooltip:Set*` per item, a full bag or inventory walk, or a list
   repaint. If a handler needs one, it needs a dirty flag.

   Stormable events we touch: `BAG_UPDATE`, `UNIT_AURA`,
   `PLAYER_AURAS_CHANGED`, `CHAT_MSG_ADDON`, `UNIT_CASTEVENT`.

### Hooking

8. **No `hooksecurefunc`, no secure hooks** — they don't exist in 1.12. Hook by
   **saving the original and replacing it**, then calling the saved original.
   Canonical examples: `Core/Aegis_Popout.lua` (`orig_PallyPower_UpdateUI`,
   and the `PallyPower_AutoBuffAll` replacement).

### The 32-upvalue ceiling

9. **A function may read at most 32 file-scope locals. Lua 5.0 refuses to LOAD
   a file that breaks this** — `too many upvalues (limit=32)` — so the whole
   addon dies, not just that feature.

   Every file-scope `local` a function references costs one upvalue. A big
   builder function plus a few new layout constants is all it takes.
   **We are already at 29**: `CreatePanel` in `Core/Aegis_AssignPanel.lua`.
   Three more file-scope locals in that file, referenced from that function,
   and the addon stops loading.

   The group-buff grid is the worked example: its nine layout constants went
   into one `GBUF` table, so `CreatePanel` grew by exactly **one** upvalue (the
   builder it calls) instead of ten. As nine separate locals it would have hit
   38 and the addon would not have loaded.

   **Nothing local catches this.** `verify.py` won't, and a Lua 5.1 harness
   won't — 5.1's limit is 60. The only signal is:

   ```
   luac5.1 -l -p Core/Aegis_AssignPanel.lua | grep upvalues
   ```

   **The fix is a table.** Thirteen constants as thirteen locals cost thirteen
   upvalues; the same thirteen as fields of one table cost one. Group new
   panel/layout constants into a table rather than adding another file-scope
   local next to an already-large function.

### SavedVariables

10. **SavedVariables are `nil` until `ADDON_LOADED` fires.** Never *read* a
    stored value at file scope. The `X = X or {}` init form at the top of a
    file is safe and is what we use (`AegisRP_Settings`, `AegisRP_Roles`,
    `AegisRP_Assign`); reading `AegisRP_Settings.someOption` at file scope is
    not — it sees the default, never the player's saved choice.

### Frames & widget API

11. Frame handlers receive **implicit globals**: `this`, `event`, `arg1`…
12. **Definition order matters**: a `local function` must be defined before any
    reference, or forward-declared (`local Foo` … later `Foo = function() end`).
    This is the single most common way to brick this addon.
13. Use **`getglobal()` / `setglobal()`** for dynamic frame names — never `_G`.
14. Build frames with **`CreateFrame`** using **vanilla templates only**
    (`UIPanelButtonTemplate`, `UIDropDownMenuTemplate`, `GameTooltipTemplate`).
15. No `C_Timer`, no secure templates, **no combat lockdown** — casting from
    code is legal in combat, a genuine advantage over retail.
16. Timers/tickers = `OnUpdate` with an accumulator on `arg1`.
17. **`UIDropDownMenu` has a button ceiling.** A menu built from the full raid
    overflows it and silently clips names (`Too many buttons in
    UIDropDownMenu`). Filter the list to plausible candidates — see
    `TANK_CLASSES` in `Core/Aegis_AssignPanel.lua`.

### Adding a file

18. **Adding a `.lua` means editing the `.toc`, and that needs a FULL client
    restart, not `/reload`** — 1.12 reads the file list at startup. Mark such a
    release **restart** in `CHANGELOG.md`.

---

## Environment specifics

**SuperWoW** (detected via `SUPERWOW_VERSION`) — always guard and always keep a
bare-1.12 fallback:
- `UnitBuff(unit, i)` additionally returns the aura **spell id** (3rd return);
  `UnitDebuff` returns it 4th.
- `CastSpellByName(spell, unit)` casts directly at the unit (no target dance).
- Buff/debuff **ids are learned at runtime** from the icon seed — never
  hard-code aura ids (Turtle's may differ from Vanilla).

**Turtle deltas:** blessing durations are forced (10 min normal / 30 min
greater). Totem/sting/curse durations use Vanilla defaults at the top of each
class module — verify on-realm and edit there if Turtle differs. Spell-name
matching is exact; if a Turtle rename breaks a lookup, fix the name string.

## Verification workflow (mandatory)

After **every** edit:

```
python3 scripts/verify.py
```

Checks structural balance and Lua 5.1-isms across `Core/` + `Classes/` +
`PallyPower/`. The vendored engine is scanned as a tripwire — it should stay
untouched, and a failure there means something edited it.

Behavioural logic that can be isolated from the WoW API gets an off-client test
under `scripts/test_*.lua`, run with any Lua (the addon files are
5.0-compatible so they load unmodified):

```
lua scripts/test_groupbuff.lua   # group-buff model + RPCX round-trip
```

Anything that crosses the wire should have one — a silent serialise/deserialise
bug corrupts raid assignments with no error, which is the worst failure mode
the sync layer has.

Beyond that there
is no standalone Lua here; the real test is in-game — errors print to chat
(the Core wraps risky paths in `pcall` and prints `AegisRP error: …`).
Use `/rpc test` (test mode) to exercise everything on an under-levelled
character: all options appear (unlearned marked `*`), clicks simulate casts
and start real timers.

## Architecture map

Load order (`Aegis_RallyPower.toc`):
```
Locale\*                       localization
PallyPower\*                   the ORIGINAL PallyPower engine (see below)
Core\Aegis_Core.lua     class-independent coverage engine + class-buff strip
Core\Aegis_Strip.lua    shared strip engine + helpers
Classes\Class_*.lua            one module per class
Core\Aegis_Options.lua  the tabbed options frame
Core\Aegis_Popout.lua   loads LAST (legacy hover handler + paladin test graft)
```

**Every non-paladin class is now a strip.** There is one visual family: the
100×34 paladin-template button, stacked in a movable titled strip (drag dot,
scale grip, saved position). Priest/Mage/Druid render the **class-buff strip**
(`AegisRP.BuildClassBuffs`, one button per raid class, with the player
pop-out on hover); Warrior/Shaman/Hunter/Warlock/Rogue render their own
self-contained strips. No bespoke grid bar exists anymore.

**Paladin = the legacy engine, wrapped not rewritten (locked decision).**
`PallyPower\PallyPower.lua/.xml` run unmodified; `PallyPower.xml` loads its lua
via a relative `<Script>` (they must stay in the same folder). The player
pop-out (`Core\Aegis_Popout.lua`) grafts onto its buff bar by replacing
`PallyPowerBuffButton_OnEnter`, reading the engine's own per-button data
(`btn.have/need/range/dead`, `LastCastPlayer`) and casting through its
spellbook tables (`AllPallys`, `GetNormalBlessings`). The pop-out rows are an
exact replica of the WotLK `PallyPowerPopupTemplate` (100×34, Smooth skin +
Blizzard Tooltip border, official colors: Good `0,0.7,0` / NeedAll `1,0,0` /
Special `0,0,1`, all 0.5 alpha).

**Class-buff classes** (Priest, Mage, Druid): declare
`M = AegisRP:NewClass("TOKEN"); M.buffs = { {name, group, icons, ids?,
pet, dur, gdur, selfcast}, ... }` (+ optional `M.utility`), plus
`M:OnActivate()` = `AegisRP.BuildClassBuffs()` and `M:Toggle()` =
`AegisRP.BuildClassBuffs():Toggle()`. The Core scans the roster, detects
by SuperWoW spell-id (learned from the icon seed) with icon fallback, casts via
`CastBuffOn`, and renders one strip button per raid class (wheel = which buff
for that class, L = group cast, R = smart single, hover = player pop-out).

**Strip classes** (Warrior, Shaman, Hunter, Warlock, Rogue): declare
`M:OnActivate()` (build UI) and `M:Toggle()`. Build UI with the strip engine:
```
strip = AegisRP.NewStrip(key, title)
strip:AddButton{ refresh=fn(b), onClick=fn(b,btn), onWheel=fn(b,delta), tooltip=fn(b,tt) }
strip:Finish()
```
Button helpers inside `refresh`: `b:SetIcon/SetLabel/SetSub/SetTimer` and
`b:SetState("good"|"need"|"off")`. Engine helpers (all cached where hot):
`AegisRP.FindSpell(name)` (spellbook, invalidated on SPELLS_CHANGED),
`FindBagItem(pattern)` (bags, invalidated on BAG_UPDATE),
`UnitHasDebuffEntry(unit, entry)` (icon-seed id-learning),
`CastAtTarget(name)`, `FmtTime(sec)`, `TexBase(path)`,
`AegisRP.IsTestMode()`.
**Buttons are 100×34, 26px icon, 2px gap — the paladin template. Locked.**

**Saved variables:** `AegisRP_Settings` (per character: `testMode`,
strip positions `stripPos_*`, selections `shamanSel`/`hunterSting`/
`lockCurse`/`roguePoison`, hidden flags) + the legacy `PallyPower_*` tables.

## Locked design decisions

1. **PallyPower 3.3.5 parity** — extract exact specs from the reference repo
   before styling anything; never approximate from screenshots.
2. **PLPWR sync interop** — paladin blessing sync stays byte-compatible with
   stock PallyPower/PallyPowerTW; new-class data rides an extended channel.
3. **Paladin engine: wrap, don't rewrite.**
4. **v1 modules are personal-accurate**; cross-player coordination belongs to
   the sync milestone.
5. Non-Paladin classes are **deliberately simplified subsets** of the Paladin
   template (see `docs/DESIGN_ALLCLASSES.md`).

## Milestone: Assignment & Sync — **COMPLETE** (validated in-game)

All three steps shipped and were confirmed on a two-client Turtle test:

1. **Shared assignment data model** — `Core/Aegis_Assign.lua`. Blessings keep
   PallyPower's format; totems, duties and the raid-buff grid live in
   `AegisRP_Assign`, multi-caster from the start.
2. **Sync protocol** — `Core/Aegis_Sync.lua` on `RPCX` (blessings still ride
   `PLPWR` untouched). Leader / Free Assignment permissions, message chunking,
   and tank-slot (`TS`) sharing. **Verified**: a leader's MT/OT plan appears on
   a second client, which shows `lead=no` and the leader's slots.
3. **Assignment panel** — `Core/Aegis_AssignPanel.lua`, six tabs: Blessings,
   Totems, Raid Buffs, Debuffs, Kick, Roles.

**Cast observation is validated.** `UNIT_CASTEVENT` fires on Turtle 1.18.1,
`UnitName()` resolves GUIDs, `SpellInfo()` resolves ids, and `evt` is `CAST` on
a completed cast. `Core/Aegis_CastWatch.lua` owns the addon's single handler;
consumers use `AegisRP.CastWatch.Subscribe(fn(caster, target, spell, id, evt))`.
**Known characteristic:** a caster must be seen *once* before their casts
register — the event only reaches units the client can see. After that the
timer runs locally at any distance.

Stragglers from this milestone are resolved: Mage Scorch and Warrior Sunder
debuff buttons shipped; Paladin aura/seal/RF toggles were already provided by
the legacy self-bar. **Priest Tank Shield is cancelled** — PW: Shield was
deliberately dropped in 0.14.0 (reactive spam, not a maintained/assigned duty);
wire id 19 is retired and must never be reused.

The **Options UI** (`docs/OPTIONS_UI_SPEC.md`) is built: Settings, Buttons and
Raid tabs, the last carrying per-character targeted duties. Follow the spec's
module `optionsInfo` contract so one Buttons tab keeps serving every class.

## Next up

- **Raid-wide interrupt timers — DONE, validated in-game.** Members broadcast
  their own interrupt cooldown over `RPCX` (`KICK`, `Aegis_Sync.lua`), which
  reaches any distance and needs no SuperWoW on the sender; the Kick tab
  distinguishes a synced report from a locally observed one (`kickSrc`).
- **ClassicAPI** (`github.com/brues-code/ClassicAPI`, VanillaFixes DLL,
  detected via `CLASSIC_API_VERSION`) — **evaluated, deliberately not adopted
  for now.** Its `C_UnitAuras` would give true `expirationTime` and
  server-authoritative, caster-modified durations for other players' buffs,
  retiring the "durations come from the catalog" limitation. If revisited, add
  it as a *third optional tier* behind SuperWoW, never a dependency. Note `#`
  and `%` stay forbidden regardless — they're syntax, not library functions.

## README / CHANGELOG upkeep

- **The badge block at the top of `README.md` is maintained by the project
  owner.** Grouped deliberately: Discord (`5865F2`), then the 1.18.1 servers —
  Octo WoW purple (`8A2BE2`), Capy WoW brown (`8B5A2B`); then the optional DLLs
  on their own row, orange (`ff8c00`, "Recommended"). Keep the shields.io style
  (`flat-square`, `labelColor=555`); do not reorder, re-row or restyle unasked.
- **Nothing is Required.** The addon runs on a stock 1.12 client; every
  SuperWoW call site has a fallback. Do not add a "Required" badge back.
- **A badge must be earned in code.** Nampower and ClassicAPI badges were
  removed because a grep of `Core/` and `Classes/` finds no calls to either.
  UnitXP_SP3 keeps one because it is genuinely read
  (`Aegis_Options.lua`, line-of-sight toggle). Same test for anything new: a
  code change that actually depends on it, or no badge.
- **The H1 carries the version** — `# Aegis: RallyPower (v1.1.0)` — so it is a
  bump site.
- One Discord invite, `https://discord.gg/hsgPTNkSX`. If it ever appears in
  more than one place, change every occurrence together or none.
- Every version bump gets a `CHANGELOG.md` entry. Mark a release **restart**
  when it adds a new `.lua` to the `.toc`.
- Be explicit about limitations and Turtle-unverified values.

### A version bump touches THREE places

Miss one and the in-game version stops matching the release:

1. `Aegis_RallyPower.toc` — `## Version:`
2. `README.md` — the **H1**: `# Aegis: RallyPower (vX.Y.Z)`
3. `CHANGELOG.md` — a new entry

(There is no `A.version` global in our Lua; `PallyPower_Version` belongs to the
vendored engine and is not ours to bump.)

### WHICH number to bump

`MAJOR.MINOR.PATCH`. **RallyPower has had a public release, so MAJOR is 1.**

- **MAJOR (`1`.x.y) — stability.** Moves only for a change that breaks a
  player's existing setup without a migration — a SavedVariables format they
  cannot upgrade into, a removed feature people depend on, or an `RPCX`
  protocol change that silently desyncs mixed-version raids. Not for "a lot has
  changed": size is not breakage.
- **MINOR (1.`x`.0) — a new capability.** The addon can do something it could
  not do before: a new tab, a new tracked buff, a new strip. The test: *could a
  player notice a new thing, not merely a better thing?* Resets PATCH to 0.
- **PATCH (1.x.`y`) — a fix or small correction.** Bug fixes, typos, wording,
  colour, layout, and a rewritten routine that computes the same thing more
  correctly. **No new capability.**

**Changing HOW something is built is not a capability.** A layout change is a
PATCH. So is a colour, a rename, a refactor, and a corrected calculation — even
when the diff is large. Ask what the player can now DO, never how much moved.

**When a release does both**, it is a MINOR — the larger claim wins.

**Every shipped change bumps**, not once per merge. A branch that adds a
capability then fixes three things in it merges as `1.2.3`, not `1.2.0`. The
number is a running account of what happened.

**Not a release, therefore not a bump:** anything under `scripts/` or `docs/`,
and edits to `CLAUDE.md` itself. None of it ships.

---

## Quick self-check before committing Lua

`python3 scripts/verify.py` covers the language rules and structural balance
across `Core/` + `Classes/` + `PallyPower/`. It does **not** cover upvalues,
definition order, or anything visual — those still need the checks below and a
real client.

- [ ] No `string.match` / `string.gmatch` / `:match()` — used `string.find` /
      `string.gfind`.
- [ ] No `#` — used `table.getn`. No `table.setn`.
- [ ] No `%` operator — used `math.mod`.
- [ ] No `select()`; varargs use `arg` / `arg.n`.
- [ ] Event handlers read `event` / `arg1…` globals (not `self, event, ...`).
- [ ] **No handler for a stormable event** (`BAG_UPDATE`, `UNIT_AURA`,
      `PLAYER_AURAS_CHANGED`, `CHAT_MSG_ADDON`, `UNIT_CASTEVENT`) does an
      unbounded rescan, a per-item query, or a repaint inline — it is O(1),
      state-gated, or behind a dirty flag flushed once per frame.
- [ ] No `hooksecurefunc` / secure hooks — saved original + replaced.
- [ ] **No function exceeds 32 upvalues** —
      `luac5.1 -l -p <file> | grep upvalues`. `verify.py` and any 5.1 harness
      will NOT catch this; the client refuses to load the file.
      `CreatePanel` in `Aegis_AssignPanel.lua` is already at **28**.
- [ ] Every `local function` is defined before its first reference (or
      forward-declared). Re-check after any scripted or multi-line edit.
- [ ] No stored setting is **read** at file scope (`X = X or {}` init is fine).
- [ ] `PallyPower/` is byte-identical to stock — `git diff --stat PallyPower/`
      is empty. Extend it by save-and-replace from our side, never by editing.
- [ ] Any off-client tests under `scripts/test_*.lua` still pass.
- [ ] Tested in-game, or explicitly flagged as untested.

---

## Working style

- When behavior must match PallyPower, **read its source and reuse its data**
  rather than re-implementing (see how the pop-out consumes engine tables).
- Commit small; test in-game between steps; `/reload` is the loop (except when
  the `.toc` changed — that needs a full restart).
