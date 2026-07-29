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

Current version: **0.14.0**. See `CHANGELOG.md` for the full history and
`docs/` for the design documents and interactive HTML concepts.

## Hard environment rules (violating these bricks the addon)

**Lua 5.0, not 5.1.** Never use:
- `#` length operator → use `table.getn(t)`
- `string.gmatch` → use `string.gfind`
- `select(...)` → does not exist
- numeric `%` modulo → use `math.mod`
- varargs beyond the implicit `arg` table

**1.12 widget API:**
- Frame handlers receive **implicit globals**: `this`, `event`, `arg1`… —
  there is no `self`/`event` parameter.
- **Definition order matters**: a `local function` must be defined before any
  reference, or forward-declared (`local Foo` … later `Foo = function() end`).
- No `C_Timer`, no secure templates, **no combat lockdown** (casting from code
  is legal in combat — a genuine advantage over retail).
- Timers/tickers = `OnUpdate` with an accumulator on `arg1`.

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

Checks structural balance and Lua 5.1-isms across `Core/` + `Classes/`. There
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

- **Raid-wide interrupt timers** *(in progress)* — the Kick tab observes others'
  kicks locally, which needs them in range. Members now also **broadcast their
  own** interrupt cooldown over `RPCX` (`KICK`), which reaches any distance and
  needs no SuperWoW on the sender. The tab distinguishes the two sources.
- **ClassicAPI** (`github.com/brues-code/ClassicAPI`, VanillaFixes DLL,
  detected via `CLASSIC_API_VERSION`) — **evaluated, deliberately not adopted
  for now.** Its `C_UnitAuras` would give true `expirationTime` and
  server-authoritative, caster-modified durations for other players' buffs,
  retiring the "durations come from the catalog" limitation. If revisited, add
  it as a *third optional tier* behind SuperWoW, never a dependency. Note `#`
  and `%` stay forbidden regardless — they're syntax, not library functions.

## Working style

- Version-bump `Aegis_RallyPower.toc` + README, and write a `CHANGELOG.md` entry
  for every release; be explicit about limitations and Turtle-unverified
  values.
- When behavior must match PallyPower, **read its source and reuse its data**
  rather than re-implementing (see how the pop-out consumes engine tables).
- Commit small; test in-game between steps; `/reload` is the loop.
