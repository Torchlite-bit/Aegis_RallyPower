# Roadmap — Aegis: RallyPower

Where the addon is, what is in flight, and what is planned. Current release:
**v1.11.0**. Full history in [`CHANGELOG.md`](../CHANGELOG.md); the rules that
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
- ✅ **Assignment panel** — seven tabs: Blessings, Totems, Raid Buffs, Debuffs,
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
- 🟡 **All four tanking classes in the taunt rotation** (v1.10.0) — Turtle's
  Paladin *Hand of Reckoning* and Shaman *Earthshaker Slam* joined Warrior
  Taunt and Druid Growl, all instant on a 10s cooldown. Exactly the
  "one catalog entry is the whole fix" the v1.4.0 note predicted: two entries,
  no engine change. **Icons are unconfirmed guesses** — they show only on other
  members' rows, since your own takes the real spellbook texture.
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
- 🟡 **Per-player buff overrides — class-buff classes** (v1.7.0) — wheel a name
  in the class-buff pop-out to give that one person a different buff from their
  class row. Coverage counting follows, so the row stops calling an overridden
  member "missing" a buff they were never meant to get. Priest/Mage/Druid only:
  it is the class-buff strip's pop-out.
- 🟡 **Per-player blessings — paladin** (v1.9.0) — the same idea on the legacy
  pop-out, which paladins had never had. Deliberately **not** built on our
  `pbuff` model: blessings ride `PLPWR` byte-compatibly and the engine already
  stores, cycles and broadcasts individual assignments, so this drives
  `PallyPower_PerformPlayerCycle` and syncs to stock PallyPower users too.
- ✅ **Debuff duties for armor / AP / attack speed** (v1.8.0) — Faerie Fire and
  Demoralizing Roar added; Thunder Clap and Demoralizing Shout un-hidden. The
  blank-icon regression that shipped with it was found in-game and fixed in
  v1.8.1.
- ✅ **Strips snap to the legacy PallyPower frames** (v1.11.0) — confirmed
  in-game on a paladin: the Taunt strip now has the buff bar to line up with
  instead of only the screen edge.
- 🟡 **One scale and one edge for a paladin's three bars** (v1.12.0) — "Buff
  bar scale" (and the bar's own scaling grip) now sizes the Kick and Taunt
  strips too, and snapping aligns to the bar's button *column* rather than its
  frame, which is 10px wider. Paladins also gained the strip settings —
  transparency, snapping, locking, Reset Frames and the per-strip Show toggles
  — that the class branch had skipped since before they had strips. Both halves
  are visual and want a look on a real client.
- 🟡 **The Options frame and Assignment panel dock side by side** (v1.13.1) —
  both opened at screen centre and stacked. Only the Options frame moves; on a
  4:3 or 5:4 client the pair does not fit at all, so it goes to the roomier
  screen edge with its top still aligned. Also fixed the two frames drawing
  into each other, which looked like a transparency bug and was interleaved
  frame levels.

---

## Phase 3 — Raid control 🚧

The remaining feature work.

### 3.1 Crowd-control assignments ✅ (sync half 🟡)
**Shipped in v1.13.0 and confirmed on a real client in test mode**: the tab
renders, the rows read, and the two-axis control works. Polymorph / Sap / Blind
/ Banish / Fear / Shackle / Freezing Trap / Hibernate / Entangling Roots,
assigned per raid mark.

**Still 🟡: the `x` wire section between two clients.** Test mode never
broadcasts (`RawSend` returns early), so a solo test cannot exercise it. The
round trip is covered off-client by `scripts/test_cc.lua`; what is unconfirmed
is a leader's CC plan appearing on a second client, the same check that
validated the tank slots.

- **It got its own tab** — the seventh. That was the open question, and the
  card pool settled it as expected: the debuff pool is 14 of a hard 18, so a CC
  catalog could not share it. The tab is a different shape anyway (one row per
  mark, not one card per duty), so it has no pool ceiling of its own.
- **Own tab meant re-laying the tab row**: six buttons at a fixed 120px already
  filled 744 of the frame's 760. The buttons now divide the width, so adding
  one narrows them all instead of running off the edge.
- Spells share the duty catalog (`tab="cc"`, wids 28-36) and so share the one
  append-only wid space; the *assignment* is a separate `cc` domain keyed by
  mark, riding an additive `x` section on `RPCX` (no PROTO bump).
- Clicking a mark icon puts that mark on your current target. `SetRaidTarget`
  is confirmed on Turtle 1.18.1 and the call is still guarded.
- ✅ **The row layout and the two-axis control** (wheel = spell, click = who)
  were checked on a real client in test mode and read correctly.
- **No paladin CC entry.** There is no `Classes/Class_Paladin.lua` — paladins
  run the vendored engine — so Turn Undead and Repentance have no natural home.
  Neither is raid CC in practice; if one is ever wanted, it needs a home file
  decided first.

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
