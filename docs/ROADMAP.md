# Roadmap — Aegis: RallyPower

Where the addon is, what is in flight, and what is planned. Current release:
**v1.8.3**. Full history in [`CHANGELOG.md`](../CHANGELOG.md); the rules that
govern the work are in [`CLAUDE.md`](../CLAUDE.md).

Phases are ordered by **dependency**, not importance — a later phase builds on
a data shape or an API an earlier one establishes. Within a phase, items are
staged so each ships something usable on its own.

## Status key

| | Meaning |
|---|---|
| ✅ | **Done and verified in-game.** Confirmed on a real Turtle client. |
| 🟡 | **Shipped, not yet verified in-game.** The code is in a release and the off-client checks pass, but nobody has watched it work. Anything visual or timing-dependent lives here until someone looks. |
| 🚧 | **In progress.** |
| ⬜ | **Planned**, not started. |
| ⛔ | **Declined or cancelled**, with the reason. Kept so the decision is not relearned. |

**Decided vs Open.** Items marked **Open** need a call before implementation
starts. Don't start one without confirming.

---

## Phase 0 — Foundations ✅

The engine, the strip family, and the decision to wrap the vendored PallyPower
rather than rewrite it. All verified in-game and long since shipped.

- ✅ **Class-independent coverage engine** (`Core/Aegis_Core.lua`) — roster
  scan, buff detection by SuperWoW spell id with icon fallback, casting,
  expiry timers.
- ✅ **Shared strip engine** (`Core/Aegis_Strip.lua`) — one visual family, the
  100×34 paladin-template button. Locked.
- ✅ **One module per class** (`Classes/Class_*.lua`) — data and class-specific
  behaviour only; the Core never learns about a class.
- ✅ **Paladin = the legacy engine, wrapped not rewritten.** Locked decision.
  `PallyPower/` stays byte-identical; we extend by save-and-replace.
- ✅ **Options UI** — Settings, Buttons and Raid tabs, generated from the
  active class module's `optionsInfo` contract.

---

## Phase 1 — Assignment & Sync ✅

**Validated on a two-client Turtle test.** This is the backbone every later
phase assumes.

- ✅ **Shared assignment model** (`Core/Aegis_Assign.lua`, v1.1.x) — blessings
  keep PallyPower's format; totems, duties and the raid-buff grid live in
  `AegisRP_Assign`, multi-caster from the start.
- ✅ **`RPCX` sync protocol** (`Core/Aegis_Sync.lua`) — leader / Free
  Assignment permissions, message chunking, tank-slot sharing. Blessings still
  ride `PLPWR`, byte-compatible with stock PallyPower.
- ✅ **Assignment panel** — six tabs: Blessings, Totems, Raid Buffs, Debuffs,
  Rotations, Roles.
- ✅ **Cast observation** (`Core/Aegis_CastWatch.lua`) — `UNIT_CASTEVENT` fires
  on Turtle 1.18.1 and one shared handler feeds every consumer.
  **Known characteristic:** a caster must be seen once before their casts
  register; after that the timer runs locally at any distance.
- ✅ **Raid-wide interrupt timers** (v1.2.0) — members broadcast their own
  interrupt cooldown over `RPCX`, so distance doesn't matter and the sender
  needs no SuperWoW.
- ✅ **Kick rotation** (v1.2.0) — a shared priority order with no turn pointer:
  who is up falls out of the order plus everyone's cooldowns, so there is
  nothing to drift between clients.
- ✅ **Assign by raid group** (v1.2.0) — the Raid Buffs tab is a caster × group
  matrix, because a priest/mage/druid group buff lands on a *party*. Assigning
  by class is a paladin mechanic that had been inherited into a place it
  doesn't fit; the per-class view is still there behind a toggle.
- ✅ **Multi-owner debuffs** (v1.3.0) — stacking debuffs take as many owners as
  the raid actually runs.

---

## Phase 2 — Rotations, strips and per-player control

- ✅ **Taunt rotation** (v1.4.0) — kick and taunt are the same problem, so they
  are one engine with two records rather than two copies. Verified in-game.
  **Turtle-unverified data:** the `TAUNTS` catalog is Warrior Taunt and Druid
  Growl only. If Turtle gives its tanking paladins or shamans a taunt, one
  catalog entry is the whole fix.
- ✅ **Strip edge snapping** (v1.6.0) — screen edges and strip-to-strip, scale
  corrected. Verified in-game.
- ✅ **Strip visibility in Options** (v1.7.0) — one checkbox per strip the
  character actually has, and a single writer for shown state so a frame and
  its saved flag cannot disagree.
- 🟡 **Hunter-only pet auto-buffing** (v1.5.0) — a warlock's demon is
  resummoned mid-fight, so buffing it is usually wasted. A manually targeted
  pet is unaffected; only the automatic scan is scoped.
- 🟡 **Rotation "next three" rows** (v1.6.0) — off by default. The rows follow
  the rotation ORDER, not the availability queue, so names don't reshuffle as
  cooldowns tick.
- 🟡 **Per-player buff overrides** (v1.7.0) — wheel a name in the class-buff
  pop-out to give that one person a different buff from their class row.
  Coverage counting follows, so the row stops calling an overridden member
  "missing" a buff they were never meant to get.
  **Partially exercised in-game**, which is how the paladin pop-out's icon bug
  (v1.8.3) was found.
- ✅ **Debuff duties for armor / AP / attack speed** (v1.8.0) — Faerie Fire and
  Demoralizing Roar added; Thunder Clap and Demoralizing Shout un-hidden. The
  blank-icon regression that shipped with it was found in-game and fixed in
  v1.8.1.

---

## Phase 3 — Raid control 🚧

The remaining feature work.

### 3.1 Crowd-control assignments ⬜
**Unblocked — no prerequisites.** Reuses the duty catalog and the `RPCX` wire
section that are already validated, so it is the most predictable piece left.
Sheep / Sap / Banish / Shackle / Trap, assigned per target.

**Open:** whether CC lives on the existing Debuffs tab or gets its own. The
duty-card pool is at 14 of 18 with a hard ceiling of 18, so a full CC catalog
does not fit alongside the debuffs — that likely settles it, but confirm.

### 3.2 Raid markers + roles ⬜
- ✅ **Prerequisite half-confirmed:** `SetRaidTarget` exists on Turtle 1.18.1
  (`/run print(SetRaidTarget)` returns a function).
- ⬜ **Still needed before building:** `/run print(GetRaidTargetIndex)`.
  Setting a mark and *reading one back* are different APIs. If only the setter
  exists the feature is write-only — the panel could assign marks but never
  show which mob currently carries which — and that needs a different design.

### 3.3 Debuff tab expansion ✅
Shipped as v1.8.0 (see Phase 2). Detection uses `UnitHasDebuffEntry` plus
CastWatch rather than combat-log parsing.

---

## Phase 4 — Reporting ⬜

### 4.1 In-game chat reporting ⬜
Announce the plan to raid chat, with per-tab toggles so a leader posts only
the tab they mean.

### 4.2 Export ⬜
**Constrained, and worth stating plainly:** 1.12 has no file-write API.
"Export" can only mean writing to SavedVariables, which flush on logout or
`/reload` — so anything produced here is readable only after the player leaves
the game. Design around that or drop it; do not promise a file.

---

## Declined and cancelled ⛔

Kept so the reasoning is not relearned.

- ⛔ **Priest Tank Shield** — cancelled in 0.14.0. PW: Shield is reactive spam,
  not a maintained or assigned duty. **Wire id 19 is retired and must never be
  reused.**
- ⛔ **ClassicAPI as a data source** — evaluated and deliberately not adopted.
  Its `C_UnitAuras` would give true `expirationTime` for other players' buffs,
  retiring the "durations come from the catalog" limitation. If revisited, add
  it as a *third optional tier* behind SuperWoW, never a dependency.
- ⛔ **Coalescing the vendored engine's `BAG_UPDATE` bag walk** — a fix was
  written and then reverted (PR #40) once the mailbox hang was traced
  elsewhere. The unbounded scan is still live. Treat it as a known cost, not a
  solved problem: if revisited, the shape is a dirty flag flushed once per
  frame, and the engine must be wrapped rather than edited.
- ⛔ **A bespoke grid bar per class** — every non-paladin class is a strip.
  There is one visual family and no second layout.

---

## Verification debt

The off-client suites (`scripts/check.sh`) cover the model, the wire and the
strip arithmetic. They cover **nothing visual**, and by construction they never
will. Items sitting at 🟡 above are the standing debt: shipped, mechanically
checked, and not yet watched.

`./scripts/check.sh --sabotage` answers the other question — whether a green
suite would actually notice a bug. Run it after changing a test.
