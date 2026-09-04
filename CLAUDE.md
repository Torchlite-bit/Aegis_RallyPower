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

Current version: **1.9.0**. See `CHANGELOG.md` for the full history,
`docs/ROADMAP.md` for what is done / shipped-but-unverified / planned, and
`docs/` for the design documents and interactive HTML concepts.

**Where things are written down**, so the two don't drift into duplicating each
other: `docs/ROADMAP.md` holds **status** — what phase an item is in, whether
it has been seen working in-game, and what is still open. This file holds
**rules and invariants** — how a thing must be built and why. A shipped
feature's constraint ("wids are the wire identity of a duty") belongs here; its
progress belongs there.

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
   repaint.

   **The three shapes that are safe** (from Aegis: Exchange, which declares
   this rule suite-wide and is the reference case for it). Pick whichever
   fits — all three are already in this repo:

   - **O(1) / bounded, no item queries.** One pass reading only cheap fields,
     repainting nothing unless the thing is on screen. It cannot participate
     in a cache storm no matter how often it fires.
   - **State-gated.** `Aegis_Sync.lua`'s `CHAT_MSG_ADDON` path does real work
     only for a prefix it owns; the rotation pollers return immediately unless
     `MyClassHas(r)`. Repeat fires cost a comparison.
   - **Dirty flag + once-per-frame flush.** Set a boolean in the handler, do
     the work in an existing `OnUpdate`. Use this whenever the work is a full
     rescan that cannot be made cheap — `auraDirty` in `Aegis_Core.lua` and
     `MarkDirty`/`Flush` in `Aegis_Sync.lua` are the worked examples.

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
./scripts/check.sh
```

One command for everything mechanical in the self-check below: `verify.py`
(structural balance + Lua 5.1-isms across `Core/` + `Classes/` + `PallyPower/`,
the vendored engine scanned as a tripwire), the four lints ported from **Aegis:
Exchange**, every off-client test, and the `PallyPower/` byte-identity check.

```
python3 scripts/verify.py            # balance + language rules
python3 scripts/lint/upvalues.py     # the 32-upvalue ceiling
python3 scripts/lint/scoping.py      # a file-scope local read as a nil global
python3 scripts/lint/definitions.py  # a definition lost to a scripted edit
python3 scripts/lint/version.py      # the three bump sites agree
```

The last four each catch a failure that **compiles cleanly and fails only at
runtime, or not visibly at all** — which is why they exist as tools rather than
checkboxes. `scoping.py` is the automated form of hard rule 12; it works off
`luac -l` bytecode rather than the source text, because the source reads
identically either way.

### Sabotage mode — does the suite actually notice?

```
./scripts/check.sh --sabotage      # or: python3 scripts/sabotage.py [name]
```

A green suite proves nothing on its own. It might be green because the code is
right, or because the assertions **cannot tell right from wrong** — and the
second kind is indistinguishable from the first until something ships broken.
`test_duties.lua` was green while Faerie Fire and Demoralizing Roar rendered as
blank squares, because it did not yet check for an icon at all.

So `scripts/sabotage.py` plants real bugs — the exact mistakes the code is
written to avoid — in a throwaway copy and requires the named suite to **fail**.
A sabotage that slips through is reported loudly: that suite is not testing what
its name claims.

**It has already paid for itself.** `groupbuffs-insertion-order` replaced the
catalog-ordered walk in `GetGroupBuffs` with `pairs()`, and the suite passed:
the ordering check used two buffs, and Lua's hash order for those two names
happens to match catalog order. The check now uses all three, where it doesn't.
The assertion was real and under-powered, which is precisely the failure no
amount of green can reveal.

Run it after adding or changing a test, and before trusting a green suite you
have not exercised. When a sabotage goes **stale** (the `find` string no longer
matches), the code moved — update the entry rather than deleting it.

Nothing under `scripts/` is in the `.toc`, so adding to it is never a
**restart** release and never a version bump.

Behavioural logic that can be isolated from the WoW API gets an off-client test
under `scripts/test_*.lua`, run with any Lua (the addon files are
5.0-compatible so they load unmodified):

```
lua scripts/test_groupbuff.lua   # group-buff model + RPCX round-trip
lua scripts/test_rotation.lua    # kick/taunt rotations + KO/TO/KICK/TNT wire
lua scripts/test_strip.lua       # strip engine: edge snapping + alpha floor
lua scripts/test_duties.lua      # duty catalog: unique wids, tab fits its cards
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
   Totems, Raid Buffs, Debuffs, Rotations, Roles.

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
  reaches any distance and needs no SuperWoW on the sender; the Rotations tab
  distinguishes a synced report from a locally observed one (`r.src`).
- **Rotations are one engine, two records — untested in-game.** Kick and taunt
  are the same problem, so `ROT` in `Aegis_AssignPanel.lua` holds both (catalog,
  cooldown state, strip, sim) and every function takes a record. `A.*Rotation*`
  in `Aegis_Assign.lua` is keyed the same way; the `A.*Kick*` names survive as
  wrappers because the panel, strip and sync layer all call them. Adding a third
  rotation is a `ROT` entry plus a `ROT_KIND` entry plus a wire tag — do it that
  way, never by copying the engine. **Turtle-unverified:** the `TAUNTS` catalog
  has Warrior Taunt and Druid Growl only; if Turtle gives its tanking paladins
  or shamans a taunt, one entry there is the whole fix.
- **Pet auto-buffing is Hunter-only — untested in-game.** `IsHunterPet` in
  `Aegis_Core.lua` gates the roster-scan path (`FindUnitToBuff`) so `pet=true`
  buffs (Fortitude, Mark of the Wild) only auto-target a Hunter's pet, never a
  Warlock's demon — a demon gets resummoned mid-fight and the buff is usually
  wasted the moment it dies or gets banished. Ownership is read off the raid
  index a pet token shares with its owner (`PetOwnerUnit`); a manually
  targeted pet (the `"target"` shortcut) is unaffected, since that's an
  explicit click, not the automatic scan.
- **Strip snapping and the rotation "next three" — untested in-game.**
  `SnapStrip` in `Aegis_Strip.lua` runs on every strip's `OnDragStop` and lines
  a strip up flush with a screen edge or another strip within 12px. All of its
  arithmetic happens in the DRAGGED frame's own coordinate space — each strip
  carries its own grip scale, so another strip's `GetLeft()` has to be
  converted by the scale ratio or the snap lands visibly wrong at any scale but
  1.0. Covered by `scripts/test_strip.lua`. The rotation strips can also show
  three rows for slots 1-3 of the order (`rotQueue`, off by default); the rows
  follow the ORDER rather than the availability queue so names don't reshuffle
  as cooldowns tick.
- **Transparency has a floor (`AegisRP.StripAlpha`, `Aegis_Strip.lua`).** The
  backdrop is the only carrier of button state, so an alpha near 0 makes every
  state paint identically while the border keeps drawing — outlined boxes with
  empty middles, which players read as a broken addon. The floor is **0.3**,
  applied on read as well as in the slider's range, so an existing low value
  heals itself. 0.15 was tried first and was still too faint for a saturated
  green to read as anything but grey — it satisfied the rule on paper and not
  on screen. Anything new that paints a strip backdrop must go through
  `AegisRP.StripAlpha` rather than reading `stripAlpha` directly. The setting
  is per character, and `/rpc alpha` prints the stored value, the effective
  one, and every visible button's live RGBA — use it before theorising about a
  colour that looks wrong.
- **Per-player buff overrides — DONE, untested in-game.** `pbuff` in
  `Aegis_Assign.lua` (caster x player name -> one buff name, replacing what
  their class row would give), riding an additive `p` section on `RPCX`.
  `PlayerOverrideIndex` in `Aegis_Core.lua` resolves it, and the scan gives an
  overridden player to their own buff index ONLY, while un-overridden players
  still count toward every index so the row's wheel stays instant. An override
  naming an uncastable buff resolves to nil, so the player falls back to the
  row rather than dropping out of coverage.
- **Strip show/hide has one writer: `AegisRP.SetStripShown`.** The Options
  checkboxes, `/rpc kick`, `/rpc taunt` and `S:Toggle` all route through it, so
  the frame and its saved flag cannot disagree. Options builds its list from
  `AegisRP.stripOrder` (creation order - `pairs()` over `AegisRP.strips` is
  unordered and would shuffle the rows between logins), so a new strip appears
  there on its own. Never write `stripHidden_*` directly.
- **Debuff duties cover armor / AP / attack speed — untested in-game.** Druid
  Faerie Fire (wids 26/27 with Demoralizing Roar) shipped, and Warrior Thunder
  Clap + Demoralizing Shout were un-hidden. **Wids are the wire identity of a
  duty** — names never cross, so a Turtle rename can't desync — which makes a
  duplicate wid a silent merge of two duties on every remote client. `19` is
  retired (cancelled Priest Tank Shield) and must never be reused.
  `scripts/test_duties.lua` asserts both, plus that the visible debuff duties
  still fit `DUTY_POOL`; overflow is silent, so a surplus duty just never
  draws. `DUTY_POOL` is 18 (2x9) and 9 rows is the ceiling — a tenth renders
  under the tab's hint text.
- **A duty carries its own `icon=`.** The card falls back to it whenever the
  viewer can't resolve the spell from their own spellbook — which is everyone
  looking at another class's duty, so a duty without one renders blank for
  almost the whole raid. It used to live in a `DUTY_ICONS` table in the panel;
  as a second place to remember it was promptly forgotten, and Faerie Fire and
  Demoralizing Roar shipped iconless in 1.8.0. `test_duties.lua` now fails on
  a duty with no icon.
- **The engine reads `PP_PerUser` BEFORE it initialises it.** Its
  `ADDON_LOADED` handler runs `PallyPower_MinimapButton_Init()` (which reads
  `minimapbuttonpos` through `cos`/`sin`) *before* `PallyPower_InitConfig()`,
  the function that fills the key in. A character's SavedVariables replace the
  engine's file-scope defaults table wholesale, so a table saved by a version
  predating a key comes back missing it and the read throws
  `bad argument #1 to 'rad'` on this client's degree shims. `Aegis_Popout.lua`
  snapshots the engine's defaults at file scope — the one moment they exist,
  before SavedVariables land — and save-and-replaces `MinimapButton_Init` to
  make `PP_PerUser` whole first. **Do not "fix" this by editing
  `MinimapButton.lua`**: it is vendored, and `or 0` there would also park the
  button at the wrong angle (the engine's default is 30).
- **Per-player assignment has TWO mechanisms, and that is deliberate.** For
  Priest/Mage/Druid it is our `pbuff` model on `RPCX`. For paladin blessings it
  is the engine's own `PallyPower_NormalAssignments` — driven through
  `PallyPower_PerformPlayerCycle`, which cycles, stores AND broadcasts
  `NASSIGN`. Blessings stay byte-compatible on `PLPWR` (locked decision 2), so
  a second source for the same question would desync us from stock PallyPower.
  Do not "unify" these. **`PerformPlayerCycle` reads its caster from
  `PP_SelectedPally`** — whatever the classic grid has selected — so any call
  from our UI must pin it to `UnitName("player")` and restore it, or it edits a
  different paladin's plan.
- **Phase 3 remaining:** crowd-control assignments, and raid markers + roles.
  **`SetRaidTarget` is CONFIRMED present on Turtle 1.18.1** (`/run
  print(SetRaidTarget)` returns a function), so markers are no longer blocked.
  `GetRaidTargetIndex` still wants the same one-line check before anything
  reads a mark back.
- **ClassicAPI** (`github.com/brues-code/ClassicAPI`, VanillaFixes DLL,
  detected via `CLASSIC_API_VERSION`) — **evaluated, deliberately not adopted
  for now.** Its `C_UnitAuras` would give true `expirationTime` and
  server-authoritative, caster-modified durations for other players' buffs,
  retiring the "durations come from the catalog" limitation. If revisited, add
  it as a *third optional tier* behind SuperWoW, never a dependency. Note `#`
  and `%` stay forbidden regardless — they're syntax, not library functions.

## Two rules that keep being relearned (suite-wide)

Both come from **Aegis: SBR**, and both bite here for the same reasons.

- **A detection that cannot answer must never close a gate.** Range,
  visibility, another player's cooldown, a pet's owner and a member's class
  all have a third value — "cannot tell" — and every caller must treat it as
  permission, not refusal. This addon is full of them: `UNIT_CASTEVENT` only
  reaches units the client has seen, `MemberClass` returns nil off-roster,
  and `GetSpellCooldown` says nothing about anyone else. The symptom when it
  is broken is always the same: something silently stops and nothing says
  why. `PlayerOverrideIndex` returning nil for an uncastable buff — so the
  player falls back to their class row rather than dropping out of coverage —
  is this rule applied correctly; copy that shape.
- **A capability is established, not assumed.** Where a source may simply
  never answer on a given client, latch the first real answer and run a safe
  fallback until then. `r.src` (`"sync"` / `"seen"` / nil) and the tri-state
  `r.myHas` (nil = not resolved yet, not "no") are the pattern. SBR's
  cautionary tale is a throttle stamped only on a confirmation that never
  arrived on the reporter's client, so the protection did not exist at all.
  Design intent that quietly evaporates on someone else's setup is worse than
  no design, because it looks correct in the source.

## House style (suite-wide)

- **Write short, neutral and factual.** Changelog entries, PR bodies, commit
  messages and code comments state what changed, why, and what it affects. No
  jokes, no irony, no dramatic framing, no rhetorical questions, no long prose
  where two sentences do. Keep measured numbers and technical detail; cut the
  framing around them. Prefer a short list to paragraphs.
- **Never quote a play report verbatim.** Reports arrive as relayed chat
  messages, and none of it belongs in `CHANGELOG.md`, `README.md`, a code
  comment or a PR body — the person was talking, not writing for publication.
  Paraphrase what the observation ESTABLISHED and drop the wording, the name
  and any characterisation of the remark. Numbers, symptoms and measurements
  are the useful part and carry none of the risk. **Named credit is the
  exception, and only when the user asks for it.**
- **Comments explain WHY, not what.** Don't introduce new dependencies. Don't
  refactor unrelated code inside a feature change. **When you fix a class of
  bug, add a one-line note to this file so it isn't relearned.**

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

**Where this went wrong elsewhere in the suite** (Aegis: Exchange, worth
knowing because the same mistake is easy to make here):

- Ten releases in its 1.x line were numbered MINOR for work that only fixed or
  polished. That is how its number ran to **1.49.1 while `main` sat at
  1.21.1** — the version stopped describing anything.
- **v1.51.0 was numbered MINOR for rebuilding three buttons on a different
  widget template and moving two of them a few pixels** — a large diff, a
  rewritten styling path and a new test suite. The player got the same three
  buttons doing the same three things in a better-looking box. It shipped
  again as **1.50.2**.

**Why every shipped change bumps, rather than once per merge.** The number is a
running account of what happened, which is what makes "quote the version" worth
asking a reporter for: someone on 1.8.1 and someone on 1.8.4 are not running the
same code, and a scheme that only bumps at merge time cannot tell them apart.

**When a release does both**, it is a MINOR — the larger claim wins.

**Every shipped change bumps**, not once per merge. A branch that adds a
capability then fixes three things in it merges as `1.2.3`, not `1.2.0`. The
number is a running account of what happened.

**Not a release, therefore not a bump:** anything under `scripts/` or `docs/`,
and edits to `CLAUDE.md` itself. None of it ships.

---

## Quick self-check before committing Lua

**Most of this list is now automated — run `./scripts/check.sh`.** What it
deliberately does **not** cover is anything visual: layout, colour, clipping,
whether a strip reads right under pressure. That still needs a real client and
a person looking at it. A green run is permission to commit, not evidence the
thing works.

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
- [ ] **No function exceeds 32 upvalues** (`scripts/lint/upvalues.py`).
      `verify.py` and any 5.1 harness will NOT catch this — 5.1's limit is 60
      and the file compiles fine; the 1.12 client simply refuses to load it.
      `CreatePanel` in `Aegis_AssignPanel.lua` is at **29** and warns on every
      run, which is correct: it is one refactor from not loading.
- [ ] Every `local function` is defined before its first reference, or
      forward-declared (`scripts/lint/scoping.py`). A function above the
      declaration reads a nil **global** of the same name — legal Lua, compiles
      cleanly, fails only at runtime.
- [ ] No top-level definition was lost to a scripted edit
      (`scripts/lint/definitions.py`). Run after ANY multi-line or scripted
      edit: the file still compiles when a function goes missing, so nothing
      else notices until a player clicks the thing.
- [ ] The three version sites agree (`scripts/lint/version.py`).
- [ ] No stored setting is **read** at file scope (`X = X or {}` init is fine).
- [ ] `PallyPower/` is byte-identical to stock — `git diff --stat PallyPower/`
      is empty. Extend it by save-and-replace from our side, never by editing.
- [ ] Any off-client tests under `scripts/test_*.lua` still pass.
- [ ] If a test was added or changed: `./scripts/check.sh --sabotage` still
      catches everything, and the new assertion has been shown to FAIL when the
      thing it guards is broken. An assertion never seen to fail is decoration.
- [ ] Tested in-game, or explicitly flagged as untested.

---

## Working style

- **Read the actual file before editing it** — never edit from memory of a
  prior version; the code has moved. Re-read after any scripted edit.
- **Incremental verified batches.** Make a small coherent change, run
  `./scripts/check.sh`, then proceed. Roll multi-file conversions in batches,
  not all at once.
- **Preserve `.toc` load order.** Reordering files breaks the single-pass
  loader; `PallyPower.xml` and its `.lua` must stay in one folder.
- When behavior must match PallyPower, **read its source and reuse its data**
  rather than re-implementing (see how the pop-out consumes engine tables).
- Commit small; test in-game between steps; `/reload` is the loop (except when
  the `.toc` changed — that needs a full restart).
