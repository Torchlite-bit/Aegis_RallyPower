# Changelog — Aegis: RallyPower

All notable changes to **Aegis: RallyPower** (formerly RallyPowerCP) are
recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com) and the project uses semantic
versioning (MAJOR.MINOR.PATCH).

Aegis: RallyPower is a fork of **PallyPowerTW** (by ivanovlk), itself based on
the original **PallyPower** team. It targets Turtle WoW 1.18.1 on the 1.12
client. Author: **Subtilizer (Torchlite)**. (Entries below from 0.14.0 and
earlier predate the rebrand and say "RallyPowerCP" — same addon.)

---

## [Unreleased]

## [1.13.1] — 2026-09-04
### Fixed
- **The Options frame and the Assignment panel no longer open on top of each
  other.** Both anchored to screen centre, so opening the second put it
  squarely over the first. They dock side by side now, tops aligned: Options to
  the right of the panel when there is room on screen, to its left otherwise.
  Only the Options frame moves — the panel has a position the player dragged
  and that we persist, so it keeps it.
- **The Options frame's backdrop was 0.85 opaque against the panel's 0.96**, so
  wherever the two overlapped the panel showed straight through it. Both are
  0.96 now.
- **Two frames in the same strata can interleave their frame levels**, which
  puts the lower one's buttons above the upper one's backdrop — that reads as a
  frame having gone half-transparent rather than as a z-order problem. The
  frame being shown is now raised above the other, and both are `toplevel` so a
  click brings one forward.

### Notes
- Dragging the panel re-docks Options, and so does rescaling it with the corner
  grip: both change how much room is left beside it.
- **A 4:3 or 5:4 client cannot fit the pair.** `UIParent` is 768 units tall and
  768 × aspect wide — 1024 at 4:3, 960 at 5:4 — against a 760-wide panel plus a
  360-wide Options frame plus the gap. There Options goes to whichever screen
  edge has more room, top still aligned: the overlap is then only the deficit
  instead of one frame covering the other, and dragging the panel aside gives
  it room. On 16:9 and 16:10 the pair fits with space to spare.
- Covered by `scripts/test_strip.lua`: which side it picks, the screen-pixel
  comparison across two different frame scales, and the no-room fallback
  landing on screen rather than past the edge. Five matching sabotages; all 30
  caught.

## [1.13.0] — 2026-09-04
### Added (crowd control)
- **A seventh Assignment panel tab: Crowd Ctrl.** One row per raid mark, in
  kill order (Skull first), saying which spell goes on it and who casts it.
  Nine spells across five classes: Polymorph, Sap, Blind, Banish, Fear,
  Shackle Undead, Freezing Trap, Hibernate, Entangling Roots.
- **Two controls per row, because one is unusable at raid size.** Wheel picks
  the spell — a short list, filtered to classes actually in the group — and
  click picks who casts it. A single combined list of every (player, spell)
  pair is over thirty entries in a 40-man.
- Changing the spell hands the mark to the first candidate for it, so wheeling
  to Banish answers "Banish — <the warlock>" rather than asking for a second
  click. The holder is kept when their class can still cast the new spell.
- **Clicking a mark icon puts that mark on your current target.** `SetRaidTarget`
  is confirmed present on Turtle 1.18.1; the call is guarded anyway.
- Lead/assist assigns anyone. Everyone else claims or drops their own mark,
  with their own class's spells — the same rule the duty cards use.
- Synced to the raid over `RPCX` as an additive `x` section, so mixed-version
  raids need no protocol bump: an older client skips the tag it doesn't know.

### Fixed
- **The `cc` domain was not in the sync layer's dirty list**, so every CC edit
  would have stayed on the client that made it with nothing to say so. Found by
  `scripts/test_cc.lua` before release.

### Changed
- **The panel's tab buttons now divide the frame width** instead of each taking
  a fixed 120px. Six already filled 744 of 760, so a seventh ran off the edge;
  adding one now narrows them all.
- Crowd-control spells share the existing duty catalog (`tab="cc"`, wids
  28-36), so there is one append-only wire-id space and a CC entry cannot
  collide with a debuff. They are assigned through a separate mark-keyed
  domain, so the Debuffs tab and its 18-card pool are untouched.

### Notes
- Not yet seen in game. The row layout and the two-axis control want a look on
  a real client; `docs/ROADMAP.md` carries 3.1 at 🟡.
- New off-client suite `scripts/test_cc.lua`: the model, the mark-major view
  derived from the caster-major store, the `x` wire round-trip, refusal of a
  non-CC wid arriving in the CC section, and a leaver's mark falling vacant.
  Five matching sabotages added; all 25 caught.
- No new file in the `.toc`, so this is a `/reload`, not a restart.
- No paladin entry: there is no paladin class module to register one in, and
  neither Turn Undead nor Repentance is raid crowd control in practice.

## [1.12.0] — 2026-09-04
### Added (one scale, one alignment, for a paladin's three bars)
- **"Buff bar scale" now scales the Kick and Taunt strips too, on a paladin.**
  A paladin has no class-buff strip of ours — the legacy buff bar is theirs —
  so the two systems had no slider in common: our "UI scale" is not on that
  class's Settings tab at all, leaving it pinned at 1.0 while the bar it docks
  against moved. One slider now sizes all three.
- The engine's own scaling **grip** does the same, not just the slider. It
  writes `PP_PerUser.scalebar` directly, so it bypassed the options entirely;
  `PallyPower_ScaleFrame` is save-and-replaced from our side (`PallyPower/`
  stays byte-identical) and our strips follow the drag.
- **Paladins get the strip settings.** Transparency, edge snapping, frame
  locking, Reset Frames and per-strip Show toggles were non-paladin only, which
  was correct when a paladin ran nothing of ours and wrong since they gained
  Kick and Taunt strips in 1.10.0 — until now there was no way to hide, fade,
  lock or reset those from the options at all.
- Option **sliders show their tooltip**. They already carried a `tip` and
  nothing read it, so the transparency slider's explanation of its 0.3 floor
  was written and never displayed.

### Fixed
- **A strip docked against the buff bar now lines up with it.** The bar is 110
  wide with its buttons inset 5px; our strips are 100 with none. Snapping frame
  edges lined up two boxes and left the two visible button columns 5px out of
  step — and the column is the only part of either frame a player can see.
  Snapping is now to the content box, and because the bar's column is exactly
  our width, one snap squares up both sides.
- The legacy transparency slider is labelled **"Buff bar transparency"**: it
  never applied to the Aegis strips, which now have their own slider beside it.

### Notes
- Not yet seen in game. The scale sync and the column alignment are both
  visual, so `docs/ROADMAP.md` carries them as shipped-but-unverified.
- Covered by `scripts/test_strip.lua`: which slider owns a strip's size per
  class, and the one drop (302px from a bar at 300) that tells a padded snapper
  apart from an unpadded one. Two matching sabotages added.

## [1.11.0] — 2026-09-04
### Added (strips snap to the paladin bar)
- **A strip now snaps to the legacy PallyPower frames, not just to other Aegis
  strips.** Snapping walked our own strip registry only, and a paladin runs the
  legacy engine and has no class-buff strip — so on that character the Taunt
  strip's only sensible neighbour, the buff bar, was invisible to the snapper
  and there was nothing to line up with but the screen edge.
- `PallyPowerBuffBar` and `PallyPowerFrame` are looked up **by name at drag
  time** rather than held: they belong to the engine, may not exist on a
  non-paladin, and are hidden until it decides to show them. A hidden or absent
  one is skipped.
- One direction only: our strips snap to the engine's frames. Dragging the
  engine's own bar does not snap to our strips — its drag handlers belong to
  the vendored engine, and reaching into those is a larger change than this
  earns.

### Testing
- `scripts/test_strip.lua` covers the new targets: snapping to the legacy bar's
  edge, stacking under it, a hidden engine frame being ignored, and an absent
  one being skipped rather than erroring.
- New `snap-ignores-engine-frames` sabotage. The refactor also moved the
  scale-conversion line, which turned `snap-scale-inverted` **stale** — the
  runner reported it rather than passing quietly, which is the behaviour that
  entry exists for. Repaired; all 18 caught.

## [1.10.1] — 2026-09-04
### Changed
- **Wheeling a name in the paladin pop-out now says what it did, and names the
  consequence.** Setting an individual blessing makes the engine's Greater
  Blessing path deliberately SKIP that player — a greater blessing is cast per
  class, so someone singled out should not be swept up in it. That is correct,
  but its only symptom was the class button reporting *"Couldn't find a
  target"*, which says nothing about why. Solo, or with one member of that
  class, singling out the only candidate made the class button look broken.
  The wheel is what makes that state easy to reach, so the wheel is now what
  explains it: it reports the blessing it set, or that the player went back to
  the class blessing.

### Added
- **`/rpc rot`** prints the live state of both rotations: which store is in use
  (the saved one, or test mode's preview, which is not saved), who is in each,
  your own position, and your lead / free-assign status. "It isn't sticking"
  has several causes that look identical from the strip — never added, added
  then pruned, added to the preview store while test mode was on and then read
  back from the saved one, or refused by the leader gate — and this separates
  them instead of leaving it to be guessed.

## [1.10.0] — 2026-09-04
### Added (paladins and shamans can hold the taunt rotation)
- **Turtle's own tanking taunts joined the catalog**: Paladin **Hand of
  Reckoning** and Shaman **Earthshaker Slam**, alongside Warrior Taunt and
  Druid Growl. Both are instant on a 10s cooldown — the same as the two already
  there — so they fit the one-cooldown-per-class shape with no engine change.
  Paladins and shamans now appear in the Rotations tab's taunt list, get a
  Taunt strip, and get the turn sound.
- This is the fix the v1.4.0 note predicted. The taunt catalog was flagged
  Turtle-unverified with "if Turtle gives its tanking paladins or shamans a
  taunt, one entry there is the whole fix" — it was two entries and nothing
  else, because the rotation engine never knew which classes it served.
- Test mode's preview taunt rotation now seats a paladin and a shaman
  (Tirion, Rehgar) as well, so `/rpc test` exercises all four.

### Known limitations
- **The icons are guesses.** Name, range, cooldown and effect came from the
  in-game tooltips; the art did not. These are Turtle custom spells and their
  icons may be anything. It only affects OTHER members' rows — your own row
  takes the real texture from your spellbook — and one line in the `TAUNTS`
  catalog corrects it.
- **Earthshaker Slam requires a shield, and we cannot see another player's
  equipment.** A shaman therefore shows as available whether or not they have
  one, and the leader decides — the same call already made for listing a fury
  warrior in the taunt list. A detection that cannot answer must not close a
  gate.

## [1.9.0] — 2026-09-04
### Added (paladins can set a per-player blessing from the pop-out)
- **Mouse-wheel a name in the paladin pop-out to give that player a different
  blessing from the rest of their class row.** Per-player overrides shipped in
  1.7.0 for the class-buff pop-out (Priest/Mage/Druid) only — a paladin runs
  the legacy engine and has no class-buff strip at all, so the feature had
  never existed on the one pop-out paladins actually use. It was reported as
  "no longer working"; it had never worked there.
- **Driven through PallyPower's own mechanism, not our `pbuff` model.**
  Blessings are the one domain that still rides `PLPWR` byte-compatibly, and
  the engine already stores individual assignments, cycles them and broadcasts
  `NASSIGN` — `PallyPower_PerformPlayerCycle` is what its classic grid's own
  wheel calls. So this syncs to stock PallyPower users too, and the cast path
  and the icon (fixed in 1.8.3) already honoured it. A second source for the
  same question would have desynced the two.
- One adjustment was needed: `PerformPlayerCycle` takes its caster from
  `PP_SelectedPally` — whoever the **classic grid** has selected. The pop-out
  is always about your own bar, so the selection is pinned to you for the call
  and restored afterwards. Without that, wheeling here would quietly edit a
  different paladin's assignments.

Numbered MINOR rather than PATCH: nothing was broken, so this is not a fix.
The pop-out gains an input it did not have, and a paladin who does not open
the classic grid can now do something they could not do before.

## [1.8.3] — 2026-09-03
### Fixed
- **The paladin pop-out drew the class blessing on every row, even for players
  with an individual assignment.** A paladin who had given one member Wisdom
  while the class row was Might saw Might on both rows — while a right-click on
  that row correctly cast Wisdom. The pop-out was telling you the opposite of
  what it would do.
- Cause: the icon was resolved **once, outside the row loop**, from the hovered
  button's class-wide `buffID`, then stamped on every row. The cast path had
  always consulted `GetNormalBlessings` for the individual assignment; only the
  draw path did not. The two now resolve identically, including the same
  "do I actually know that blessing" gate, so the icon can't promise a blessing
  the click would not cast.
- The class-buff pop-out (Priest/Mage/Druid) was already correct — it has
  resolved per row since per-player overrides shipped in 1.7.0.

## [1.8.2] — 2026-09-03
### Fixed
- **`bad argument #1 to 'rad' (number expected, got nil)` on login.** The
  engine's `ADDON_LOADED` handler calls `PallyPower_MinimapButton_Init()` —
  which positions the minimap button with `cos`/`sin` of
  `PP_PerUser.minimapbuttonpos` — *before* `PallyPower_InitConfig()`, the
  function whose job is to fill that key in. On this client `cos`/`sin` are
  degree shims that call `rad()`, so a missing value throws there.
- **It bites on upgrade, not on a fresh install.** The engine assigns
  `PP_PerUser` a full defaults table at file scope, but a character's
  SavedVariables then replace that table *wholesale* — so a table saved by a
  version that predates a key comes back without it, and the repair runs one
  call too late.
- Fixed from our side, as the vendored engine requires: `Core/Aegis_Popout.lua`
  snapshots the engine's own defaults at file scope (the one moment they are
  readable, before SavedVariables land) and save-and-replaces
  `PallyPower_MinimapButton_Init` to fill any missing key before the original
  runs. Values you actually chose are never touched — only absent ones.
- This repairs **every** key a stale saved table is missing, not just the one
  that happened to crash, so the next absent key doesn't become the next bug
  report.

## [1.8.1] — 2026-09-03
### Fixed
- **Faerie Fire and Demoralizing Roar had blank icons on the Debuffs tab.** A
  duty card resolves its icon from your own spellbook first and falls back to a
  stored one — and the fallback is what almost everyone sees, since a mage
  can't resolve a druid spell. The two new duties in 1.8.0 had no fallback, so
  they rendered as empty squares for anyone who wasn't a druid.
- **The icon now rides on the duty definition instead of a parallel
  `DUTY_ICONS` table in the panel.** That table was a second place to remember
  when adding a duty, and it was promptly forgotten — which is the whole reason
  1.8.0 shipped two blank cards. The icon sits next to the wid, spell and
  duration it belongs with, and `scripts/test_duties.lua` now fails on any duty
  without one (verified by deliberately removing one).

## [1.8.0] — 2026-09-03
### Added (the Debuffs tab covers the raid's actual mitigation)
- **Faerie Fire and Demoralizing Roar are now druid duties**, with strip
  buttons to match. Faerie Fire has two spells — the caster one and the Feral
  talent version usable in forms — and both are listed, so a feral gets a
  button they can press while shifted; they apply the same debuff and share an
  icon, so tracking covers either. An untalented druid never sees the Feral
  one. Durations are Vanilla defaults (40s / 30s) and **Turtle-unverified**.
- **One duty per effect, not per spell.** The raid plan cares that Faerie Fire
  is up, not which of the two spells put it there.

### Changed
- **Thunder Clap and Demoralizing Shout are visible on the Debuffs tab.** They
  had been hidden as "group utility rather than something one caster maintains
  on the kill target" — but a raid assigns them exactly that way, and they are
  the attack-speed and attack-power halves of the mitigation the tanks are
  counting on. They stay single-owner: they refresh rather than stack, so a
  second owner adds nothing but confusion about whose job it is.
- The duty-card pool grew from 16 to 18 (two columns of nine). Fourteen debuff
  duties are visible now, and overflow is *silent* — a surplus duty simply
  never draws — so the extra room matters. Nine rows is the ceiling: a tenth
  would render underneath the tab's hint text.

### Testing
- New `scripts/test_duties.lua`: loads the real model and all eight class
  modules and checks the catalog whole — every duty well-formed, **wids
  unique**, the retired wid 19 never reused, and the visible debuff duties
  still fitting the card pool. Wids are what duties travel as on the wire, so a
  collision silently merges two duties on every remote client with no error
  anywhere; that is not something inspection catches across eight files.

## [1.7.1] — 2026-09-03
### Fixed
- **The Transparency floor was still too low to do its own job.** 1.6.1 added a
  floor of 0.15 so the backdrop — the only thing carrying covered/needed/
  expiring — could never go fully invisible. But a saturated green at 0.15 over
  a dark game background is not meaningfully different from grey: the state was
  legible in principle and invisible in practice, which is why an affected
  character still looked flat next to a healthy one. The floor is now **0.3**.
  Every colour carries 0.5 as its natural alpha, so 0.3 leaves a real range to
  adjust within while guaranteeing the colour actually reads.
- **Reset Frames now restores transparency and per-strip scale, not just
  position.** Transparency is per character and makes a strip look *broken*
  rather than look transparent, so "why does this one alt look wrong" needed a
  one-click answer that doesn't require knowing which slider caused it. The
  button and its tooltip say so.
- The Transparency tooltip now states that it is a per-character setting — that
  is precisely the clue that explains one alt looking washed out beside another.

### Added
- **`/rpc alpha`** reports what each strip button is *actually* painted:
  the stored and effective transparency, and the live RGBA of every visible
  button. A washed-out green and a plain grey are indistinguishable by eye, so
  this separates "wrong state" from "right state, too transparent" instead of
  leaving it to be guessed from a screenshot.

## [1.7.0] — 2026-09-02
### Added (per-player buff overrides)
- **Mouse-wheel a player's row in the hover pop-out to give that one person a
  different buff from the rest of their class row.** Every raid has the one
  warrior who wants Shadow Protection while the rest of the row takes
  Fortitude; until now honouring that meant retargeting the whole row and
  hand-fixing everyone else. An overridden name carries a gold `*`.
- **Wheeling all the way round returns to "no override."** An override you can
  set but not obviously clear is a trap, and a hover panel has no room for a
  clear button — so the cycle runs through the usable buffs and then back to
  the class default.
- **Coverage counts it properly.** An overridden player counts only toward
  their own buff, so the class row stops calling them "missing Fortitude" when
  they were never meant to get it — and their pop-out row is coloured and timed
  against the buff they actually get. Everyone else still counts toward every
  buff, so the row's own wheel keeps switching instantly.
- **Overrides sync** on a new additive `p` section of the `RPCX` block, so
  older clients skip it rather than desyncing (no protocol bump). Clearing the
  Raid Buffs tab in per-class view now clears the overrides with the rows they
  are exceptions to, so none are left pointing at buffs nobody assigned.
- An override naming a buff you can't cast — unlearned, or switched off on the
  Buttons tab — falls back to the class row instead of dropping that player out
  of coverage silently.

### Added (strip visibility in Options)
- **Options > Settings now lists every strip this character has, each with a
  show/hide checkbox** — Kick, Taunt, and the class strip (Shout, Totems,
  Stings, or the buff strip). Previously this was slash-commands only.
- The list is built from the strips that actually exist, so a warrior sees
  three rows and a priest sees one, and anything added later appears on its own.
- Show/hide now has a **single writer** (`AegisRP.SetStripShown`): the
  checkboxes, `/rpc kick`, `/rpc taunt` and a strip's own toggle all route
  through it, so a frame's shown state and its saved flag can't disagree. The
  when-to-show rules still get the last word.

### Testing
- `scripts/test_groupbuff.lua` covers the override model and its wire section:
  set/replace/clear, name-sorted listing, the full round-trip, and an
  out-of-range buff index being dropped on receive. This caught a real bug
  before it shipped — the serialiser read a caster name that wasn't in scope,
  so the section silently never went out.
- `scripts/test_strip.lua` covers the visibility invariant: frame and saved
  flag agreeing in both directions, and an unbuilt strip remembering the choice
  rather than erroring.

## [1.6.1] — 2026-09-02
### Fixed
- **Transparency could turn a whole strip into empty outlines.** The
  Transparency slider went down to 0, and it is a single global multiplier on
  the one thing that carries state — green covered, red needed, amber expiring,
  grey off. Near zero every state paints the same nothing, and because
  `SetBackdropColor` only affects the fill, the border keeps drawing: you get
  outlined boxes with empty middles, which reads as a broken addon rather than
  a transparent one, with nothing on screen saying why. The setting is **per
  character**, so the giveaway is one alt looking flat while another looks
  right.
- The slider now floors at **0.15** — still very see-through, never
  unreadable — and the floor is applied on *read* as well, so a character that
  already had it at 0 fixes itself without touching the slider. The
  covered-but-expiring colour goes through the same floor, so it can't be the
  one state that vanishes.

### Testing
- `scripts/test_snap.lua` is now `scripts/test_strip.lua` and covers both
  pieces of strip-engine arithmetic (35 checks): the existing snapping cases,
  plus the alpha floor — unset falling back to the colour's own alpha, a set
  value passing through, 0 and 0.05 being raised to the floor, and the floor
  and full opacity being left alone.

## [1.6.0] — 2026-09-02
### Added (frames snap to edges)
- **Drop a strip near a screen edge and it lines up flush.** Within 12 pixels
  of an edge — of the screen, or of another strip — the strip snaps rather than
  landing nearly-but-not-quite aligned. Strips snap to each other four ways per
  axis: edges flush, or sitting directly against one another, so stacking a
  Kick strip under a Taunt strip is one drag instead of a pixel hunt.
- **Scale is handled properly.** Every strip carries its own grip scale, so
  another strip's coordinates are in a different space; the snapper converts
  them into the dragged frame's space by the scale ratio first. Getting that
  backwards would still "work" while parking the frame somewhere visibly wrong,
  which is why it has a test rather than only a look in-game.
- Toggle in **Options > Settings > Snap frames to edges** (on by default).

### Added (the next three in a rotation)
- **The Kick and Taunt strips can show three rows for slots 1-3 of the order** —
  who holds each, and whether they are up, ready, on cooldown, or dead/away.
  **Options > Settings > Show the next three in the rotation**, off by default:
  the single button already answers "is it me", and the tooltip already lists
  the whole order on demand.
- **The rows follow the ORDER, not the availability queue.** Position 2 is
  always the same person until a leader changes the rotation, so the rows stay
  put and your eye learns them; only the status on the right moves. Rows that
  tracked "the next three who are ready" would reshuffle every few seconds as
  cooldowns came back, which is the opposite of useful under pressure.

### Fixed
- **The Kick and Taunt strips shared one button-visibility key.** Both used
  `rotation`, and `Reflow` gates a button on `AegisRP_Settings["btn_" .. key]`,
  so anything that hid one strip's button would have hidden the other's with
  it. They are keyed per rotation now. Latent rather than reachable — the
  Buttons tab is generated from the active class module and never listed
  either — but it would have bitten the moment they were surfaced.

### Testing
- New `scripts/test_snap.lua` (27 checks): screen edges on both axes, the
  12px threshold being exclusive at exactly 12, strip-to-strip alignment in all
  four directions, a strip ignoring its own and hidden strips' edges, the scale
  conversion in the direction that matters, the settings gate, and an
  unpositioned frame being skipped rather than erroring.

## [1.5.0] — 2026-09-02
### Added (pet auto-buffing is Hunter-only)
- **Auto-buffing pets now only targets Hunter pets.** A buff flagged
  `pet=true` (Fortitude, Mark of the Wild) used to consider every pet in the
  raid a valid target for the round-robin scan and the smart-buff key,
  including a Warlock's demon. A demon is resummoned mid-fight and gets
  banished, dismissed or dies far more often than a Hunter's pet does, so a
  buff cast on one is usually wasted the moment that happens. The scan now
  checks the pet's owner (`IsHunterPet`, `Core/Aegis_Core.lua`) and skips
  anything that isn't a Hunter's.
- **Manually targeting a pet is unaffected.** The `"target"` shortcut in
  `FindUnitToBuff` — buff whatever you have targeted first, before the roster
  scan runs — still buffs any friendly pet you've explicitly clicked, Warlock
  demons included. Only the *automatic* scan is scoped to Hunters; and
  explicit target always wins.

## [1.4.1] — 2026-09-02
### Fixed
- **The Raid Buffs tab's By Class / By Group switch overlapped the class icon
  header.** It anchored at `NAME_W, -40` while the class icons start at
  `NAME_W+9, -42`, so the pill was painted directly on top of Warrior and
  Rogue's icons, and its 92px box was too narrow for "View: By Class" /
  "View: By Group" besides. Moved to the panel's top-right corner — the same
  spot the Rotations tab's own view switch already uses without incident —
  and widened so the label fits inside its border.

## [1.4.0] — 2026-09-01
### Added (taunt rotation)
- **There is now a taunt rotation, and it works exactly like the kick one.**
  Set a priority order of tanks; whoever sits highest and is off cooldown is
  up. Taunting puts you on cooldown and hands the top spot to the next person
  by itself, and anyone dead, absent or on cooldown is skipped — so nothing
  has to be advanced by hand and there is no turn pointer to drift out of sync.
- **Its own strip** (`/rpc taunt`), with the same four states the kick strip
  has — **TAUNT NOW** / On deck / Holding / Cooldown — and its own sound
  toggle in Options. A protection warrior has a kick *and* a taunt, so both
  strips can be up at once and they track independently.
- **Warrior Taunt and Druid Growl only.** Mocking Blow is a taunt too, but at a
  two-minute cooldown it is never part of a rotation, and one cooldown per
  class means listing it would time every warrior's Taunt wrong. Turtle's
  tanking paladins and shamans hold threat without a taunt as far as we have
  verified on-realm; if that changes, one line in the `TAUNTS` catalog is the
  whole fix.
- **Taunt cooldowns sync like kick ones.** Members broadcast their own over
  `RPCX` (`TNT`), which is exact and reaches any distance without SuperWoW on
  the sender; with SuperWoW we also observe casts as a fallback for people
  running a plain client. The shared order rides `TO`, leader-gated like `KO`.

### Changed
- **The Kick tab is now the Rotations tab**, with a Kick/Taunt switch in its
  top-right — the same control the Raid Buffs tab uses. Two tabs would have
  been the obvious thing, but the tab row is full at six and the two grids are
  the same list with a different ability column, so a view switch beats a
  cramped seventh tab. **Clear** on that tab now clears the rotation you are
  looking at, not just its timers, and never touches the hidden one.
- **Kicks and taunts are one implementation, not two.** `ROT` holds a record
  per rotation (catalog, cooldown state, strip, simulation) and every engine
  function takes one, so a fix to the rotation rules lands in both and a third
  rotation costs a table entry rather than another 400 lines. The model layer
  is keyed the same way (`A.GetRotation("taunt")`); the older `A.GetKickOrder`
  family survives as wrappers, so nothing calling them changed.
- One cooldown poller and one turn-cue ticker now serve both rotations instead
  of one each — a warrior with both abilities costs the same `OnUpdate` work
  as a rogue with one.
- Test mode simulates whichever rotations you are actually in, so a mage no
  longer gets taunt chatter and a druid no longer gets interrupt chatter.
- Roster pruning drops leavers from every rotation at once, so adding a
  rotation can't quietly leave stale names in it.

### Testing
- New `scripts/test_rotation.lua` (42 checks): the two rotations stay
  independent stores, the kick-named wrappers still behave, the cap and the
  leader gate hold, pruning reaches both, each rotation rides its own wire
  message without leaking into the other, `-` clears, and `KICK`/`TNT` route to
  the right rotation while nonsense values are dropped.

## [1.3.0] — 2026-09-01
### Added (several people can own the same debuff)
- **Stacking debuffs now take as many owners as you want.** Sunder Armor and
  Scorch are cumulative — a real raid runs two or three warriors on Sunder and
  a pair of mages on Scorch — but the Debuffs tab could only ever name **one**
  person per duty, so the assignment never matched what the raid was actually
  doing. Clicking a stacking card now **adds** an owner rather than replacing
  the last one; right-click drops the most recently added. Cycling past the
  last candidate clears the duty, as before.
- **Non-stacking duties are unchanged and stay single-owner.** Curses and
  Expose Armor overwrite each other on the target, so exactly one person should
  hold them; those cards still cycle one name at a time. The card tooltip has
  always said which kind a duty is (“any number” vs “one owner”) — now the
  panel behaves that way too.
- Each owner still broadcasts **their own** claim in **their own** `RPCX`
  block, so multi-owner duties need no protocol change and mixed-version raids
  degrade to what an older client understands. Asserted by
  `scripts/test_groupbuff.lua`.

### Fixed
- **Class names no longer bleed through the Raid Buffs group grid.** Switching
  the tab to the group view hid the class *icons* but left their *labels*
  drawn, so “Warrior”, “Shaman”, “Priest” and “Pet” sat underneath the
  group headers. The builder now keeps a reference to each label so the view
  switch can hide it with its icon.

## [1.2.0] — 2026-09-01
### Added (Raid Buffs tab: assign by raid group)
- **The Raid Buffs tab can now assign by raid group.** Rows are still your
  priests, mages and druids; columns are now **groups 1–8**, and each cell
  holds one small toggle per buff that caster can give — so *"Priest 1 covers
  groups 2 and 3, and group 2 gets Fortitude **and** Spirit"* is a few clicks
  in one row, rather than something the panel simply couldn't express.
- **Why by group.** A priest/mage/druid group buff (Prayer of Fortitude,
  Arcane Brilliance, Gift of the Wild) lands on a **party**. Assigning by class
  is a *paladin* mechanic — Greater Blessings are cast per class, which is why
  PallyPower is class-shaped — and the class grid had been inherited into a
  place it doesn't fit.
- **Coverage now reads per group**: "No buffer for group: 4, 7" instead of by
  class, because that's the gap that actually matters for these buffs.
- **The per-class view is still there**, behind a *View: By Group / By Class*
  toggle at the top of the tab (remembered per character). It wasn't deleted
  because it does one thing nothing else can: a leader editing it retargets
  that caster's own strip buttons. The strip's mouse-wheel only ever sets your
  own.
- **Clear only clears the view you're looking at.** The two are separate plans,
  and wiping the hidden one would be invisible destruction. Asserted by test.

### Notes
- Untested in-game — the grid is visual and needs a real client. `/rpc test`
  seats the preview raid, so the tab can be exercised solo.
- `CreatePanel` went from **28 to 29** of the 32-upvalue ceiling. The nine new
  layout constants live in one `GBUF` table on purpose: as separate file-scope
  locals they would have pushed it to 38, and Lua 5.0 refuses to *load* a file
  that breaks the limit — the whole addon, not just the tab.

## [1.1.1] — 2026-09-01
### Added (group-buff assignment model — foundation, no UI yet)
- **Raid buffs can now be assigned by raid group, with several buffs per
  group.** `Priest 1 covers groups 2 and 3`, and group 2 can carry *both*
  Spirit and Stamina from the same caster. Model + sync only in this release;
  the Raid Buffs tab still shows the class grid until the UI lands.
- **Why a second domain instead of replacing the class grid.** Assigning by
  *class* is a **paladin** mechanic — Greater Blessings are cast per class,
  which is why PallyPower is class-shaped and why blessings keep that model
  untouched. A priest/mage/druid group buff (Prayer of Fortitude, Arcane
  Brilliance, Gift of the Wild) lands on a **party**, so group assignment is
  the shape raids actually organise around. The class grid was inherited from
  the paladin design into a place it doesn't fit. The two answer different
  questions and both stay: `cbuff` is "which buff do I give class X" (the
  strip's per-class wheel), `gbuff` is "which groups do I cover, with what".
- New model API in `Core/Aegis_Assign.lua`: `SetGroupBuff`, `HasGroupBuff`,
  `ToggleGroupBuff`, `GetGroupBuffs`, `GetCoveredGroups`, `ClearGroupBuffs`,
  `MaxGroups`. A group holds a **set**, and empties itself out of the table
  when its last buff is removed so serialised blocks stay small.
- **No protocol version bump was needed.** The new `g` payload section
  (`g<group>.<buffIndex>` pairs, same shape as the existing `b` section) is
  additive, and the deserialiser's tag dispatch already skips sections it
  doesn't recognise — so a v1.1.0 client receiving group buffs ignores that
  one section and keeps everything else, rather than desyncing. This is
  asserted by test, not assumed.
- **New off-client test** — `lua scripts/test_groupbuff.lua`, 26 checks
  covering the model, catalog-ordered output, bounds rejection, a full
  serialise → broadcast → receive round-trip through the real sync layer, and
  forward compatibility in both directions (a v1 payload still parses; an
  unknown future tag is skipped without harming the sections around it).
  Restores the `scripts/test_*.lua` convention that went out with the PR #40
  revert.
### Fixed (`/pp buff` crashed when anyone was dead)
- **`PallyPower_AutoBuffAll` threw `attempt to compare number with nil`.** The
  engine writes a buff-bar count as `"3 (1)"` the moment someone in the raid is
  dead (`PallyPower.lua:1507`), but its own reader does `tonumber(text) > 0`
  (`PallyPower.lua:3738`) — and `tonumber("3 (1)")` is `nil`. So `/pp buff` and
  `/pp autobuff` errored for the whole pull as soon as there was a corpse.
  **Not a version mismatch or a line-number shift** — this is a latent bug in
  stock PallyPowerTW that only needs a dead raid member to surface, and the
  reported line 3738 matches our file exactly.
- Fixed by **replacing the function from our side** rather than editing
  `PallyPower/`, keeping the vendored engine byte-identical to stock: the count
  is now read as the *leading* number, so `"3 (1)"` correctly means "3 still
  need it", and a button whose text isn't a count is skipped instead of
  throwing. `"0 (2)"` correctly does nothing — only corpses are missing it.

### Fixed (post-release hygiene)
- **Double-load removed.** `PallyPower.lua` and `MinimapButton.lua` were listed
  in the TOC *and* `<Script>`-included by their own XML, so each executed twice.
  The TOC entries are gone; the XML stays the loader (which is why the .lua and
  .xml must live in one folder). Load order is unchanged, and the vendored
  engine files are still byte-identical to stock.
- **`KICK` broadcasts are rate-limited** to one per second per sender
  (`Aegis_Sync.lua`). The poller only fires on a ready→cooldown edge so it was
  already self-limiting in practice, but this is the one path that bypasses the
  debounced flush. The shortest real interrupt cooldown is 6s (Earth Shock), so
  nothing legitimate is dropped. The guard lives in the sender, so every caller
  is covered rather than just the poller.
- **The two always-on kick tickers no longer run for classes without an
  interrupt.** Class is resolved once and cached (`MyClassKicks`), so a priest
  or druid stops doing per-tick work for a feature they can't use, and
  `AegisRP.HasInterrupt()` now shares that one cache.

### Changed (verifier covers the vendored engine)
- **`scripts/verify.py` now scans `PallyPower/` too** — a tripwire against
  accidental edits to the engine we've committed to leaving untouched.
- Doing that required fixing two real blind spots in the checker, which would
  have mis-read our own code just as easily:
  - **`--[[ long comments ]]` were parsed as line comments**, leaving the
    comment *body* to be counted as live code. A commented-out block full of
    `do`/`end` then read as a structural imbalance. Long strings (`[[ ]]`,
    `[=[ ]=]`) are handled now as well.
  - **Bare `do ... end` blocks weren't counted as openers**, so every one
    looked like an unmatched `end`.
  With both fixed the whole tree passes, our own files unchanged.

### Notes
- **`PP_Presets` is correctly declared** — an earlier audit flagged it as a
  saved variable with no UI, which was wrong. The blessing-preset system is
  live in `MinimapButton.lua` and reachable two ways: the classic frame's
  Presets button (`PallyPower.xml:1635`) and our own panel's Presets button for
  paladins (`Aegis_AssignPanel.lua:2655`). No change made.

---

## [1.1.0] — 2026-07-30
### Added (Cast-exact shared timers — validated on Turtle)
The `UNIT_CASTEVENT` observation was confirmed working in-game on Turtle 1.18.1
(the event fires, GUIDs resolve to names via `UnitName`, spell ids resolve via
`SpellInfo`, and `evt` is `CAST` on a completed cast), so the feature it gated
is in.
- **Other players' buffs are now timed.** Previously `expiry[]` only ever held
  *your own* casts, so a buff another priest put up showed as "covered" with no
  timer, and never triggered the expiry ding. The addon now watches other
  casters and records the same deadline it would for your own cast. Because the
  coverage scan, the player pop-out, the strip and smart-targeting all already
  read the one shared `expiry[]` store, **they all gain raid-wide timers from
  this single hook** — no per-consumer wiring.
- **New `Core/Aegis_CastWatch.lua`** — one `UNIT_CASTEVENT` handler for the whole
  addon, with a `Subscribe(fn(caster, target, spell, id, evt))` API, memoised
  spell-id→name resolution, and pcall-isolated watchers so one erroring consumer
  can't blind the others. The Kick tab's private handler moved onto it (same
  behaviour, one event registration instead of two).
- **Only completed casts count** (`CAST`, not `START`), so an interrupted cast
  can't leave a phantom timer; and the coverage scan still self-corrects,
  clearing a recorded deadline the moment the buff isn't actually on the unit.
- **New setting** — *Options → Buttons → Behaviour → "Time other players'
  buffs"* (default on; the tooltip reports whether SuperWoW was detected).
  Without SuperWoW nothing changes: timers stay limited to your own casts.
- **Limitation:** durations come from the buff catalog, not the wire, so a
  non-default-rank cast is timed at the catalog duration (all the tracked raid
  buffs are single-duration across ranks in Vanilla, so this is only a concern
  if Turtle changes one).
- `/rpc castdbg` now logs the target as well as the caster, and reports through
  the shared watcher.
- **Range note (confirmed in testing):** `UNIT_CASTEVENT` only reaches you for
  units the client can currently see, so a caster has to come into range *once*
  before their casts register. After that the timer runs locally and keeps
  counting no matter how far apart you get — it's the first sighting that needs
  proximity, not the tracking.

### Added (Mage Scorch debuff tracking)
- **Mage Scorch button** added to the class-buff strip as a debuff-tracking
  button alongside Intellect/Brilliance. The button shows your target's Scorch
  state (refreshed or needs applying) and exact countdown if present (learned
  from your cast). Like Warrior Sunder, it tracks locally and only your own
  casts - exact raid-wide timers are a future sync enhancement. The strip's
  Options tab includes a "Debuff buttons" toggle to hide/show it (default on).

### Added (Message chunking for large assignment blocks)
- **Automatic message chunking** handles the rare case where a complex assignment
  block exceeds the ~255-char addon-message limit. Large payloads are split
  across multiple CHUNK messages and reassembled on receive (30s timeout for
  stale chunks). The sender transparently picks between BLK (single message) and
  CHUNK (multi-message) based on serialized size. Receiver handles both formats
  identically to ensure zero-impact forward compatibility.

### Changed (`/rpc slots` now shows whether sync is actually flowing)
- The diagnostic flags **test mode** ("these are preview slots - nothing is sent
  or received") and **solo** ("not grouped"). Test mode is a local sandbox —
  tank slots live in a separate preview store, `RawSend` suppresses every RPCX
  message, and `ApplyTankSlots` ignores incoming ones — so slot output there
  says nothing about whether sync works. Without the note it reads like a
  passing two-client test when no message ever left the client.
- When you *are* grouped it adds **wire telemetry**: when the tank order was
  last sent and last received (and from whom), plus a count of all RPCX messages
  received. One client's output now shows whether sync is live, instead of
  needing two side by side and a guess.

### Fixed (Roles tab: tank dropdown overflow in a full raid)
- The **Main Tank / Off-Tank dropdowns** now list only tank-capable classes
  (Warrior, Paladin, Druid, Shaman — Turtle WoW has a tanking shaman spec). In a
  40-man the old "everyone" list overran the UIDropDownMenu button cap ("Too many
  buttons in UIDropDownMenu") and clipped names off the bottom; restricting it to
  classes that can actually hold aggro keeps the menu short and removes
  nonsensical picks (a rogue/mage/priest tank). A tank already set is always
  still offered so a stale slot stays clearable. (Tank-capable classes are a
  one-line edit at the top of the Roles section if a Turtle spec changes who can
  tank.)

### Added (Kick rotation — a shared interrupt order, and a strip that tells you when you're up)
- **The rotation is just a priority order.** Whose turn it is isn't stored
  anywhere — it's *"the highest person in the order whose kick is actually
  ready"*. Using your kick puts you on cooldown, which hands the top spot to the
  next person by itself. Nothing to drift between clients, nothing to reset
  after a wipe, and no turn counter to sync: every client computes the same
  answer from the same shared data.
- **Dead, absent and on-cooldown members are skipped**, so the rotation never
  stalls waiting behind someone who can't act. This only works because kick
  cooldowns now travel raid-wide.
- **New kick strip** (`/rpc kick`, interrupt classes only) — your personal cue,
  answering one question at a glance rather than showing a roster:
  **KICK NOW** (red) · **On deck** (amber) · **Holding** (green) ·
  **Cooldown** (grey). Red still means *act*, matching every other strip in the
  addon. It names who's up when it isn't you, and who follows when it is.
  Hovering lists the whole rotation with live cooldowns.
- **Sound when you reach the top** (Options → Behaviour, default on) — you're
  watching the boss, not the strip. It fires on the transition only, so sitting
  at the top waiting for a cast doesn't machine-gun it.
- **Kick tab plans it**: click a name to add or remove them from the rotation,
  mouse-wheel to move them up or down it. Leader-gated like tank slots, shared
  over `RPCX` (`KO`), and the tab marks who is **UP** and who's **next**.
- The strip engine gains an **amber `warn` state** for "not yet, but be ready" —
  the same meaning yellow already carried on the Core's class rows.

### Added (Test mode simulates a live rotation)
- With `/rpc test` on, a pretend mob starts casting every few seconds and
  whoever is up interrupts it, starting their cooldown and advancing the order.
  **Your own strip cycles through all four states unattended**, so the feature
  can be judged solo instead of needing five interrupt-capable people. Each
  simulated kick is announced in chat so the order is followable.
- The simulated rotation is seeded from the preview raid (a warrior, rogue,
  shaman, mage and warlock — every cooldown length in play) and lives in the
  preview store, so it never touches a real raid's plan or the wire.

### Added (Raid-wide interrupt timers)
- **Your interrupt is now broadcast** the moment it goes on cooldown (`RPCX`
  `KICK`), so the Kick tab is right for members you can't see. Watching someone
  cast needs them **in range**; a broadcast doesn't — which closes the gap
  where a distant kicker showed "Ready" while actually on cooldown.
- It reads **your own cooldown** rather than a cast event, so it needs **no
  SuperWoW on the sender** — even a bare 1.12 client contributes its kicks to
  everyone else's tab. It sends the true remaining time, so talent-reduced
  cooldowns and the sampling delay both come out right.
- Self-reported, so there's no leader gate — you can only ever announce your
  own cooldown. Sent immediately rather than batched through the flush.
- **The tab now says which source it used**: "Exact - reported by their Aegis,
  any distance" versus "Observed from their cast (needed them in range)". A
  synced report always wins over an observed one.

### Planned / under consideration
- **ClassicAPI aura tier** — the VanillaFixes DLL's `C_UnitAuras` exposes true
  `expirationTime` and server-authoritative, caster-modified durations for other
  players' buffs, which would retire the catalog-duration limitation. Evaluated
  and deliberately deferred; if adopted it goes in as a third optional tier
  behind SuperWoW, never as a dependency.

---

## [0.14.0] — 2026-07-12
**Raid roles: mark tanks & healers, and give tanks their own blessing.**

### Changed (Assignment panel: Utility → Kick tab; Roles redesign)
- **Utility tab removed.** It duplicated what each caster already sets for
  themselves in **Options → Raid** (Fear Ward, Innervate, Soulstone — those
  duties, their targeting, and their sync are all unchanged), so the panel tab
  went away rather than keeping two places to set the same thing.
- **New Kick tab** in its place — an interrupt tracker. One row per
  interrupt-capable member present (Warrior Pummel/Shield Bash, Rogue Kick,
  Shaman Earth Shock, Mage Counterspell, Warlock Spell Lock), showing who has
  a kick and whether it's ready or on cooldown. **Your own** interrupt shows an
  exact live cooldown; **others** are best-effort — with SuperWoW their kicks
  are observed from their casts (`UNIT_CASTEVENT`) and timed locally, otherwise
  they're shown ready. Exact raid-wide interrupt timers are a sync-milestone
  follow-up. (Turtle-unverified cooldowns are one-line edits in the
  `INTERRUPTS` table.)
- **Diagnostics**: `/rpc castdbg` toggles raw `UNIT_CASTEVENT` logging (to
  validate the cast observation on Turtle - verbose, for a short test then
  off); `/rpc slots` prints the shared tank-slot plan plus your leader /
  free-assign state, to compare across two clients.
- **Roles tab redesigned** around named tank slots: a **Main Tank** and up to
  **two off-tanks**, each picked from a dropdown. Under each slot a second
  **blessing dropdown** ("gets (instead of Salv):") shows at a glance what
  that tank currently gets and lets you pick the blessing it receives instead
  of its class default — listing only blessings a paladin present can
  actually cast. Healer marking moves to the grid below (left-click a name to
  toggle Healer). The tank *membership* still
  rides `PallyPower_Tanks` (so the no-Salvation rule, tank blessings, and
  stock-PallyPower interop all keep working); the MT/OT **order** is shared
  over RPCX (new leader-gated `TS` message) so the whole raid sees one tank
  plan.

### Changed (rebrand: RallyPowerCP → Aegis: RallyPower, the FULL rename)
Joins the Aegis addon series (like Aegis_SBR). Pre-release, so the rename goes
all the way down — **delete any old `RallyPowerCP` folder and install fresh as
`Aegis_RallyPower`; old SavedVariables are not carried over.**
- **Display**: the addon presents as **Aegis: RallyPower** everywhere — addon
  list, chat prefix (`Aegis:` / `[Aegis]`), errors, options title, panel
  header, key-binding header, credits, new-version notice (all locales).
  `/aegis` joins `/rpc` as a slash alias.
- **Folder + TOC**: the addon installs as `Aegis_RallyPower/` with
  `Aegis_RallyPower.toc`; all bundled art/sound paths and the engine's
  `icons_prefix` / `ADDON_LOADED` check follow the new folder.
- **Files**: `Core/RallyPowerCP_*.lua` → `Core/Aegis_*.lua`.
- **Code + saved variables**: the `RallyPowerCP` namespace and every
  `RallyPowerCP_*` global/frame/saved-variable renamed to `AegisRP` /
  `AegisRP_*` (`AegisRP_Settings`, `AegisRP_Assign`, `AegisRP_Roles`, …).
- **Unchanged**: the embedded PallyPower engine keeps its own names
  (`PallyPower_*`, `PP_*`) and the `PLPWR` channel — locked byte-compat with
  stock PallyPower — and the `RPCX` sync prefix stays (it's brand-neutral).

### Added (Shaman "All Totems" button)
- The shaman strip gains an **All Totems** button ahead of the four element
  buttons: one click drops the selected totem of every element in order
  (Earth → Fire → Water → Air). Totems share the global cooldown, so the
  casts are paced automatically ~1.5s apart (an `OnUpdate` pump fires each
  one as the GCD clears — legal from code on the 1.12 client); totems on a
  **real** cooldown (Grounding, Mana Tide, Fire Nova…) are skipped. The
  button shows the shaman class icon, live progress while dropping
  ("dropping 2/4"), green with the earliest expiry timer when the full set
  is down, red with a "drop N" count when totems are missing.
  **Right-click** clears every totem timer (you recalled them). In test
  mode the click simulates all four instantly. Toggle it in the Shaman
  Buttons options ("All Totems button"). A 10-second failsafe stops the
  queue if casting stalls (dead, feared, etc.).

### Added (Warrior Sunder Armor button)
- The Warrior strip gains a **Sunder Armor** button beside Battle Shout: it
  tracks Sunder on your current target via the icon-seed debuff matcher
  (SuperWoW-exact where available, texture fallback otherwise) - green with a
  cast-derived timer while it's up, red when the target is missing it, grey
  with no hostile target - and clicking applies/refreshes it. Toggle it in the
  Warrior Buttons options. (Thunder Clap / Demoralizing Shout stay
  catalog-only; the Mage Scorch button is a follow-up.)

### Removed
- **Power Word: Shield** dropped from the Priest entirely - both the utility
  strip button and the `PWSHIELD` assignment duty. It's spammed reactively
  rather than assigned/maintained, so it didn't fit the coordination model.
  Wire id 19 is retired (never reused; the wire stays forward-compatible).

### Added ("My raid assignments" - personal targets in the Raid tab)
- The Options **Raid** tab now shows a personal, per-character panel of MY
  targeted duties (Warlock **Soulstone**, Druid **Innervate**, Priest **Fear
  Ward**) - one dropdown each to put it on a **specific player**, a marked
  **Tank**/**Healer**, anyone (my choice), or nobody. It
  writes my own row in the shared model (always self-editable, synced to the
  raid); a leader's Utility-tab plan can still override it. Paladins get a
  pointer to the Roles tab for alternate tank blessings.
- (For now the Priest's buttons act on these at cast time; the Warlock/Druid
  targets are recorded + synced but auto-cast wiring waits on their own
  utility buttons.)

### Added (role targeting: Fear Ward on the tank; Raid options tab)
- **Utility duties can now target a role.** On the panel's **Utility** tab,
  right-click a targeted duty (Fear Ward, Innervate, Soulstone) to send it to
  the **Tank** or **Healer** (or leave it to the caster's choice); the card
  shows `Caster -> Tank`. The target is stored in the duty value
  (`@TANK` / `@HEALER`) and syncs like the rest.
- **The Priest's Fear Ward button casts on the assigned role.**
  When you hold the duty with a `@TANK`/`@HEALER` target, the strip button
  casts on the marked tank/healer (resolved from PallyPower's Tanks/Healers)
  and shows `on Tank` under the name — falling back to its normal target if
  that role isn't present.
- **Options → Raid tab repurposed** from a stub into a real pane: an **Open
  Assignment Panel** button, a synced **Free Assignment** toggle, and
  **Report assignments to chat** / **Re-request sync** buttons, with a note on
  the PLPWR vs RPCX split.

### Fixed (roles testing round 1)
- **Tank blessing override now only offers blessings a paladin can actually
  cast.** PallyPower fires the per-player override only when the paladin has
  that blessing (`PallyPower.lua` line 3232), so cycling to one they lacked
  silently dropped the tank's blessing (Salvation skipped, nothing cast). The
  cycle now skips non-castable blessings, and the write only lands on paladins
  who can cast the pick. (Reminder: the override is a *normal* single-target
  blessing — apply it by right-clicking the class button or using Auto-buff,
  exactly like PallyPower; a plain left-click casts only the greater blessing
  and skips the tank.)
- **Un-marking a tank clears its blessing override**, so an ex-tank stops
  overriding its class blessing (the lingering override was why a
  de-selected player still lost Salvation).

### Added (Roles tab)
- A sixth **Roles** tab on the assignment panel lists every raid/party member
  (preview raid in test mode) in a two-column grid. **Left-click a name** to
  cycle **Tank → Healer → none**.
- **Byte-compatible with PallyPower**: roles are stored in PallyPower's own
  `PallyPower_Tanks` / `PallyPower_Healers` tables and broadcast with the
  identical `TANK` / `HEALER` / `CLTNK` / `CLHLR` messages, so a player you
  mark here shows up for stock-PallyPower users (and vice versa) and drives
  PallyPower's own tank logic — most notably **no Salvation on a marked
  tank**.
- **Per-tank blessing override** (the "give tanks a different blessing"
  feature): **right-click or mouse-wheel a tank** to cycle the blessing it
  gets instead of its class default, shown as an icon on the row. This is
  PallyPower's per-player `NormalAssignments` with the identical `NASSIGN`
  message, applied across the known paladins so the tank gets it whoever
  buffs them.
- Roles are **leader-gated** (or open with Free Assignment on), like the rest
  of the panel; the tab header shows the tank/healer counts, and **Clear**
  wipes all role marks. Nothing role-related touches the RPCX channel — it
  all rides PLPWR through the untouched PallyPower engine.

---

## [0.13.0] — 2026-07-12
**The Assignment & Sync milestone.** A five-tab *"Who Covers What"* panel
(right-click a strip's title or the paladin buff bar, or `/rpc assign`) now
coordinates the whole raid: Blessings drive the classic PallyPower grid
byte-for-byte (Aura/Seal columns and per-paladin rank/talent/Symbol info
included), while Totems, Raid Buffs, Debuffs and Utility ride a new shared
assignment model that **broadcasts across the raid** over an `RPCX` channel
separate from PLPWR. A leader's plan reaches every client and drives their
strips; every class strip and the panel gained a PallyPower-style scale grip;
and test mode seats a full 40-man preview raid so it all works solo. Blessings
stay 100% compatible with stock PallyPower users.

### Fixed (sync testing round 2)
- **Duties now respect class.** A duty may only be held by a caster of its
  class - a priest can no longer claim Sunder Armor, and clicking a duty with
  nobody of its class present no longer assigns it to you; it clears any stale
  holder instead. Enforced in the model (`Assign.SetDuty`) and the panel, and
  a heal pass drops any wrong-class duty saved before this (so the old
  "everything assigned to me" state cleans itself up on the next roster
  change or `/reload`).
- **Test mode no longer forces everyone to leader.** Grouped test mode now
  respects the real party/raid leader, so a two-client test simulates
  lead/member roles properly; solo test mode stays fully editable as before.
- **Debuffs tab trimmed** to the raid-maintained utility debuffs. Hidden from
  the tab (via a new `hidden` duty flag): Thunder Clap and Demoralizing Shout
  (group-utility shouts), and Serpent Sting, Curse of Agony and Curse of Doom
  (personal DPS DoTs, not a utility debuff someone is assigned to maintain).
  Wire ids stay reserved and the model/sync still carry them, so nothing else
  breaks (the Hunter sting wheel and Warlock curse wheel are unaffected) and
  any of them can be shown again in one line. The tab keeps the Curses
  (Elements / Shadow / Weakness / Recklessness / Tongues), Sunder Armor,
  Expose Armor, Scorch, Viper Sting and Scorpid Sting.

### Fixed (sync testing round 1)
- **Leaders can now edit other players' rows again.** The local edit gate
  (`Assign.CanEdit`, the panel's `LeaderLike`, the pills) compared
  `IsPartyLeader() == 1`, but on this client the leader API returns
  `true`/`false` — so `== 1` was always false and a leader could only edit
  their own row. All leader checks now use PallyPower's truthy semantics via
  one `Assign.IAmLead()` helper, which also fixes the **party leader** case
  in the sync layer (`PallyPower_CheckRaidLeader(me)` never matched the
  player's own party leadership, so a party leader never broadcast others'
  blocks).
- **Free Assignment is now a real synced feature.** It's a raid-wide flag
  the **leader** controls; toggling it broadcasts over RPCX so every client
  reflects it, and while it's on **any member may edit any row**. Non-leaders
  clicking the pill get a "leader only" message instead of being locked out.
  (Blessing free-assign stays PallyPower's own per-paladin flag, as before.)
- **Refresh** now also re-requests RPCX sync (`/rpc sync`), not just the
  PallyPower blessing report — one button reconciles the whole plan on demand.
- **Test mode now works inside a party**: the preview raid's rows survive a
  roster change while test mode is on and **never touch the wire** (a new
  `RallyPowerCP.PreviewNames` set gates both the sync broadcast and the
  roster prune), so you can exercise every tab solo even while grouped.

### Added (Assignment & Sync — step 2: the RPCX sync protocol)
The final milestone piece: the totem, duty, and raid-buff-grid assignments the
panel shows now **broadcast to the raid** and **receive** others', so a raid
leader's plan actually reaches everyone. Implements `docs/DESIGN_SYNC.md`.
Requires two RallyPowerCP clients to see end-to-end. **Blessings are
untouched** — they keep syncing over the legacy `PLPWR` channel, so
stock-PallyPower interop is unaffected.
- **`Core/RallyPowerCP_Sync.lua`** — a new `RPCX` addon-message channel
  (separate from PLPWR) that serializes each caster's block to a compact wire
  form (`BLK <caster> <seq> cTOKEN;t<wids>;d<entries>;b<pairs>`), using the
  catalog **wire ids** so spell names never cross the wire (Turtle-rename
  safe) and unknown ids are skipped rather than misparsed (forward-compat).
- **Flows**: `REQ` on entering world / roster change (others reply with their
  blocks, and I push mine); a **0.5 s debounced broadcast** on any local edit;
  whole-block replace on receive with an echo guard so applying a remote block
  never re-broadcasts. Roster leavers are pruned, exactly like PallyPower.
- **Permissions** mirror PallyPower verbatim: a block for a caster is accepted
  from that caster (self-assign) or from **lead/assist** (who may push anyone's
  plan); conflicts resolve arrival-order last-writer-wins. The strips and panel
  need no new wiring — they already read the model, so remote assignments
  appear the moment a block lands.
- **`/rpc sync`** forces a full re-request + re-broadcast; the panel's Sync
  pill now reads **SYNC** and its tooltip explains the PLPWR / RPCX split.
- Fast-follows (documented, not in this step): cast-exact shared timers via
  SuperWoW `UNIT_CASTEVENT`, message chunking, and Free Assignment for
  non-paladins.

### Added (Assignment & Sync — step 1: the shared data model)
Foundation only; nothing consumes it yet (sync = step 2, panel = step 3), so
there is no user-visible change. Implements `docs/DESIGN_ASSIGNMENTS.md`.
- **`Core/RallyPowerCP_Assign.lua`** — a caster-major store
  (`RallyPowerCP_Assign`, new SavedVariablePerCharacter) covering the **totem**
  and **duty** domains, with **blessings delegated to the untouched PallyPower
  tables** (adapter accessors only; byte-compatible PLPWR interop preserved).
  Mutators/readers (`SetTotem`/`SetDuty`/`GetDutyCasters`/`GetTotemCoverage`/…),
  a `CanEdit` permission gate (self or lead/assist), roster pruning, a
  `Subscribe` change event, and an ephemeral **`RallyPowerCP.AssignStatus`**
  intent-vs-actually-up mirror (never saved). Stable append-only `wid`s and a
  per-caster `seq` are reserved for the future `RPCX` wire format.
- **Duty/totem catalogs** are declared by the class modules at load
  (`RallyPowerCP.Assign.RegisterDuty` / `RegisterTotems`): Priest/Mage/Druid
  raid buffs, Warrior/Rogue/Warlock/Mage/Hunter debuffs, Warlock/Priest/Druid
  utility, and the Shaman totem lists — nothing class-specific lives in the
  engine.

### Added (Raid Buffs grid, scale grips, live test bar, totem polish)
- **Raid Buffs tab is now a caster × class grid** (the blessings tab's shape
  applied to Priest/Mage/Druid): each cell cycles which buff that caster
  gives that class, over a new **class-buff domain** in the assignment model
  (`Assign.SetClassBuff`/`GetClassBuff`). **The class-buff strips follow
  their own row** — assigning Thorns to a druid's Warrior column retargets
  their Warrior button, and wheeling a strip button self-assigns in the
  model (two views of one row), so buffers can split the raid by class.
  The old single-owner raid-buff duty cards are replaced by the grid.
- **Scale grips everywhere**: the PallyPower resize corner (same art, same
  cursor math, self-contained code) now sits on every class strip and on
  the assignment panel's bottom-right. Drag to scale 0.5–2.0; scale and the
  re-anchored position persist per frame; the global UI-scale slider resets
  per-strip overrides; Reset Position also resets the panel's scale.
- **Paladin test-mode bar is live**: the ten class buttons now show your
  REAL blessing assignments (green assigned / red not; the demo icon only
  marks empty slots) and **mouse-wheel cycling works** — the engine's
  cleanup left a table in `classID` (breaking the template handler) and the
  stock wheel path skips blessings nobody needs, which solo in test mode
  was everything. Assignments made in the panel repaint the bar instantly.
- **Class-buff strips match the paladin bar exactly**: class icon + buff
  icon side by side (new second-icon slot in the strip engine), no text
  labels — the pop-out and tooltips carry the words.
- **Totem chips show the totem's icon** (your spellbook first, static
  fallback art for other shamans) and the **Group column is automatic** —
  it shows the shaman's live raid subgroup instead of a manual assignment,
  since totems only reach their own group. Preview raiders sit in fixed
  groups (five a group).
- **Aura cell cycling skips the resistance auras** on the Blessings tab
  (identical on every paladin); the write + `AASSIGN` broadcast stay
  byte-identical to the legacy right-click path.

### Changed (Blessings tab round 4: aura row trimmed, cells centred)
- The aura skills row now shows only the **rankable auras** (Devotion,
  Retribution, Concentration, Sanctity) — the three resistance auras are
  identical on every paladin and were pure noise.
- Skills icons grew to 16px on a wider 22px pitch and the rank text to 8px,
  so the two strips read comfortably in the 170px column.
- The assignment cells (aura/seal/blessing chips) are now **vertically
  centred against the full 62px row** instead of hugging its top edge.

### Changed (Blessings tab round 3: spell tooltips actually resolve, aura skills row, wider left column)
- **Spell tooltips fixed for real**: the legacy ID tables hold SHORT names
  ("Wisdom", "Retribution", "the Crusader") which never match a spellbook
  entry, so the spell lookup always fell back to the summary tooltip. Cell
  tooltips now rebuild the full name with the locale's own patterns
  ("Blessing of …", "… Aura", "Seal of …") before the spellbook lookup — a
  paladin hovering an assigned blessing/aura/seal now gets the real spell
  text (totem chips and duty cards already used exact full names and light
  up for the class that knows them).
- **Second skills row: auras.** Under each paladin's blessing ranks, a row of
  their seven auras with rank+talent overlaid (from `AllPallysAuras`), since
  talents improve auras — the assigner can see who is best specced for the
  aura duty. Preview paladins: Protection +5 Devotion, Retribution +3
  Retribution Aura.
- **Roomier left column**: the name/skills column widened to 170px with a
  thin gold separator before the Aura column, rows deepened to 62px (6
  pooled rows) and the frame grew to 760×680; totem chips and duty cards
  widened to match.

### Changed (Blessings tab round 2: skills column, Aura/Seal moved left, tooltip fix)
- **Aura and Seal are now the FIRST two columns** of the grid (slots 1-2, as
  requested), followed by the ten buff classes.
- **Per-paladin skills strip**, imitating the classic frame's left column:
  under each paladin's name, an icon for every blessing they can cast with
  its **rank and talent points** ("6+5") overlaid, and the number of
  **Symbols of Kings** in their bags on the subtitle line ("34 sym", from the
  legacy `SYMCOUNT` broadcasts) — so the assigner can see at a glance who has
  the best rank/talents for each blessing. Preview paladins show max ranks
  with +5 on their spec's blessing. Blessing rows grew to 50px (7 pooled
  rows); the frame is 700×640.
- **Tooltip fix**: `GameTooltip:SetSpell` now passes the literal `"spell"`
  book type, and every tooltip handler is wrapped so an OnEnter error prints
  `RallyPowerCP error: … (tooltip)` to chat instead of silently killing the
  tooltip (the likely cause of tooltips not appearing at all).

### Added (Blessings tab: Aura + Seal columns, real spell tooltips)
- **Aura and Seal columns** on the Blessings tab, exactly like the classic
  PallyPower frame: two extra cells per paladin (gold-labelled, headed by the
  Devotion Aura / Righteousness icons) cycling through the legacy engine's own
  `PallyPower_PerformCycle(name, 10/11)` aura/seal paths — edits write
  `PallyPower_AuraAssignments`/`PallyPower_SealAssignments` and send the
  byte-identical `AASSIGN`/`SASSIGN` messages, so stock PallyPower users
  receive them unchanged. Preview paladins cycle all 7 auras / 6 seals
  locally. The frame widened to 700px for the twelve columns.
- **Real spell tooltips**: hovering a blessing/aura/seal cell, a totem chip or
  a duty card now shows the actual spell tooltip (name, rank, description)
  when the spell is in your spellbook, with the assignment context appended
  below — so the assigner can read what each spell does. Spells outside your
  spellbook keep the plain summary tooltip.

### Fixed (post-test polish round 2)
- **Preview-paladin blessings now survive `/reload`**: the fake paladins'
  assignments moved from a session-only table into the saved settings
  (`RallyPowerCP_Settings.testBless`); they are still wiped when test mode
  turns off, and the legacy tables / PLPWR wire still never see fake names.
- **Options frame grows for tall tabs**: the Shaman Buttons tab (four totem
  dropdowns + shared behaviour section) overflowed the fixed 480px frame,
  leaving the last dropdown on the border. Each tab now reports its content
  height and the frame gains bottom breathing room when needed.
- **Closer to the concept**: panel widened to 640×620 with concept-scale
  cells (45px blessing cells / 30px chips, 98px element chips, 292px duty
  cards), the tab row now sits flush on the content box with the active tab
  merging into it, and grid/typography spacing was retuned throughout.

### Changed (assignment panel rebuilt to the concept spec)
The panel now follows `docs/RallyPowerCP_assignment_concept.html` instead of
approximating it: a 566×612 gold-framed "Who Covers What" dialog with status
pills (Lead/Solo, clickable **Free Assign** toggle, PLPWR sync, TEST RAID),
concept-styled tabs (green dot = live, amber = local-until-sync), per-tab
header/description, class-coloured caster rows with spec subtitles, chip-style
cells (blessing icons, element-coloured totem chips, "+" empty cells), a
**coverage line** (red "No blessing: Priest, Shaman" / green all-covered), and
duty tabs rendered as two-column **cards** with icons and class-coloured
holder names plus an "N/M assigned" counter.
- **Test mode seats a full 40-man preview raid** of lore characters (Varian,
  Uther, Arthas, Thrall, Jaina, Sylvanas, …) covering every class **and spec**,
  so every tab is exercisable solo. Preview blessing edits stay in a
  session-only table (the legacy tables and the PLPWR wire never see fake
  names); preview totem/duty rows are swept by `PruneToRoster` when test mode
  turns off.
- **Classic bottom-button row** (same features as the PallyPower frame):
  **Refresh** (legacy rescan + REQ broadcast), **Clear** (current tab;
  blessings go through the byte-compatible legacy `CLEAR`), **Options** (opens
  the RallyPowerCP tabbed options), **Reset Position**, and **Presets**
  (paladins; the same presets dropdown as the classic frame).
- **Right-clicking the paladin buff bar now opens this panel** (left-click
  keeps the classic assignment frame; graft replaces
  `PallyPowerBuffBar_MouseUp` — `PallyPower.lua` untouched), and the classic
  frame's **Options button now opens the RallyPowerCP options panel**
  (`/rpc legacy` still reaches the old options frame).
- **Permission fixes**: `Assign.CanEdit` now treats solo players as their own
  leader and allows every edit in test mode, so totem/duty assignment works
  outside a group (previously a solo shaman couldn't cycle other rows at all);
  the panel repaint is wrapped in `pcall` and reports errors to chat instead
  of leaving a half-drawn grid. The panel position is saved per character.

### Added (Assignment & Sync — step 3: the assignment panel)
One frame for the whole raid's assignments (`Core/RallyPowerCP_AssignPanel.lua`),
opened by **right-clicking a strip's title area** or **`/rpc assign`** (works for
every class, Paladin included). Five tabs:
- **Blessings — live and PLPWR-byte-compatible.** Rows are the paladins known
  from `PLPWR` broadcasts; cells cycle through the legacy engine's OWN
  `PallyPower_PerformCycle`/`Backwards` (permission-gated by
  `PallyPower_CanControl`), so edits write the untouched PallyPower tables and
  send the same `ASSIGN` messages the `/pp` grid sends. A paladin can use this
  panel **instead of** the classic grid, and raid paladins on stock
  PallyPower/PallyPowerTW receive the assignments unchanged. Left-click next /
  right-click previous / wheel; shift sets all classes (legacy `MASSIGN`).
- **Totems** — shaman × element grid plus a "covered party" column, over the
  shared assignment model (click/wheel cycles the catalog; `-` = unassigned;
  `own` = their own subgroup).
- **Buffs / Debuffs / Utility** — the module-declared duty catalogs with a
  "who's responsible" cell per duty: lead/assist cycles through the class's
  candidates, everyone else claims/unclaims themselves.
- The non-blessing tabs are **local until the sync milestone**: your own row
  already drives your strip buttons (step 1b); rows set for others start
  broadcasting when `RPCX` sync lands.
- Pooled rows, ESC-closes, movable, remembers its last tab; 1s repaint plus
  instant repaint on any model change. In **test mode** you are always listed
  as a candidate, so every tab is exercisable solo.

### Added (Assignment & Sync — step 1b: strips are views of my own row)
The first live consumer of the data model (design §9). Solo behaviour is
unchanged; the model simply follows your picks — and when the sync milestone
lands, a leader's assignment will take over the same buttons automatically.
- **Effective selection = assignment first, local preference second, first
  known last.** The Shaman totem buttons, Hunter sting button and Warlock
  curse button now read your own row in `RallyPowerCP_Assign` before the
  `shamanSel`/`hunterSting`/`lockCurse` preferences (which remain the
  solo/offline fallback — no migration). An assignment naming a spell you
  don't know falls through gracefully.
- **Wheeling (or picking in the options dropdown) self-assigns**: it writes
  the local preference AND your own caster block in the shared model —
  PallyPower free-assign style, editing your own row. Stings and curses hold
  exactly one duty key at a time (picking one clears the others).
- **Warlock curse catalog completed**: `CURSE_WEAKNESS` / `RECKLESSNESS` /
  `TONGUES` / `AGONY` / `DOOM` registered with append-only wids 21–25, so
  every wheel option is representable as a duty.
- Out of scope by design: Rogue poisons (weapon buffs, not duties), the
  Expose/Battle Shout buttons (no cycle to assign), and the Priest/Mage/Druid
  per-class buff mapping (blessing-shaped, not a duty; the raid-buff duties
  cover "who maintains it" instead).
- **Solo test:** `/run RallyPowerCP.Assign.SetTotem(UnitName("player"),
  "Earth", "Tremor Totem")` — the Earth button switches to Tremor on the next
  tick; wheel it and `/run` `GetTotem` to see the assignment follow.

## [0.12.0] — 2026-07-09
**One visual family: every non-paladin class is now a strip.** Priest, Mage,
Druid and Warrior were rebuilt from scratch on the strip engine, so all nine
classes look and behave the same way; the bespoke grid bar is gone.

### Added (config options for the non-paladin classes)
The options panel gained the applicable PallyPower-style settings for every
non-paladin class, each wired to real behaviour:
- **Settings** — **Transparency** slider (strip-button backdrop opacity) and
  **Horizontal layout** (lay the strip left-to-right). Buff/grid scale is
  already covered by the existing **UI scale** slider (our classes have one
  frame, not the paladin's two).
- **Buttons → Behaviour** — **Smart buffs** (skip already-buffed players;
  off = allow re-casting), **Sound when a buff runs out** (gates the expiry
  ding), **UnitXP SP3 line-of-sight** (reuses the engine's
  `PallyPower_CheckTargetLoS` in our targeting; shared `PP_PerUser` setting),
  and a **Scan frequency (s)** slider (drives the roster-rescan interval).
- **Intentionally omitted:** HD Icons and Color Buff Bar — both are
  Paladin/PallyPower-art-specific (our buttons use live spell icons and their
  own status colours), so they'd be no-op toggles here.

### Changed
- **Priest / Mage / Druid → the class-buff strip** (`RallyPowerCP.BuildClassBuffs`):
  one 100×34 strip button per raid class, showing that class's assigned buff
  (buff icon + gold class-name label + grey buff sub-label), red with a
  need-count when members lack it, green/yellow with a timer when covered.
  Scroll a button to change that class's buff (Fortitude / Divine Spirit /
  Shadow Protection, Intellect, Mark / Thorns), left-click casts the group
  version, right-click tops off the next member, hover opens the same player
  pop-out the paladin bar uses. Priest's utility buttons (PW: Shield / Fear
  Ward) are appended to the strip with the same anatomy. The frame, drag,
  scale grip and saved position all come from the strip engine, so these read
  identically to Shaman / Hunter / Warlock / Rogue.
- **Warrior → a self-contained self-cast strip** (the Warlock-armor pattern):
  one Battle Shout button, green with a cast-derived timer while the shout is
  on you, red when it's missing; click casts (refreshing nearby party), test
  mode simulates. `btn_shout` options toggle.
- **The hand-rolled buff bar is retired.** `Core/RallyPowerCP_Core.lua` dropped
  `CreateBar` / `LayoutButtons` / the class-row + utility-row builders / the
  single-button click-cycle-tooltip helpers / `SavePosition` and the
  `ROW_`/`BAR_`/`UTIL_` geometry (~560 lines). The roster/coverage scan,
  timers, casting, pop-out, expiry ding, SmartBuff key binding and options
  hooks are unchanged and now feed the strip.

### Added
- **Strip engine**: buttons gain an optional `def.onEnter`/`def.onLeave` (the
  class-buff buttons use it to open the pop-out instead of a tooltip) and a
  `def.visible()` predicate (roster-presence gating; all class buttons show in
  test mode).
- **Test mode — all class buttons everywhere.** Priest/Mage/Druid show one
  button per class regardless of the real roster (scroll each to preview its
  buffs). **Paladin**: the legacy blessing bar is grafted to force all ten
  class buttons visible in test mode (wrapping the global `PallyPower_UpdateUI`;
  `PallyPower.lua` is untouched) so a paladin previews the full layout solo,
  the same way `/rpc test` shows every other class its full set.

### Notes / limitations
- Turtle-unverified: exercised statically only (`scripts/verify.py`). On-realm
  checklist — a grid class (Druid/Priest): `/rpc test` shows all nine class
  buttons, the sub-labels name the right buffs and the wheel cycles; a strip
  class (Shaman/Rogue): no regressions; a Paladin: the legacy bar fills with
  all class buttons in test mode and is otherwise untouched.
- The paladin test-mode buttons are a decorative preview (they keep the empty
  `classID`/`buffID` the engine set, so clicks don't cast); only the common
  vertical bar layout is repainted.

---

## [0.11.0] — 2026-07-09
**3.3.5 pop-out parity for the grid classes + the options panel absorbs the
classic PallyPower options** (right-click the minimap icon on any class).

### Changed
- **Grid pop-out unified to the PallyPowerPopupTemplate replica** (Priest,
  Mage, Druid, Warrior — previously 0.3-era 26px colour bars in a 160px
  panel): 100×34 rows with the Smooth skin + Blizzard Tooltip border, the
  official `C_GOOD`/`C_NEEDALL`/`C_SPECIAL` presets (0.5 alpha), 16×16 buff
  icon dimmed to 0.4 on players missing the buff, "R" range letter
  (green/red), "D" dead marker, and the main-tank icon — identical to the
  Paladin pop-out. Rows stack flush in a bare floating container anchored
  `TOPRIGHT → TOPLEFT (-4, 0)` of the class row.
- **Class rows are now 100×34 with a 2px gap** and the Smooth-skin backdrop,
  matching the paladin template; row status colours use the official presets
  (expiring stays yellow `1,1,0.5,0.5`).
- **Local MT/MA roles render on the tank icon** (white / cyan tint;
  CTRL+click still cycles MT → MA → none). The old role letter and the
  `RoleLabel`/`RoleColor` helpers are gone; "R" now means range, as in the
  reference.
- **Minimap right-click opens the RallyPowerCP options for every class**,
  Paladin included. The classic PallyPower frame stays reachable via
  **`/rpc legacy`** as an escape hatch.

### Added
- **Classic PallyPower options merged into the panel** without forking
  state: checkboxes drive the same XML widgets + handler functions the
  classic frame uses (its `uiDirty` refresh flag is file-local, so the
  engine's own handlers are the only sanctioned path — and the classic
  frame's widgets stay in sync); sliders write `PP_PerUser` and call
  `PallyPower_UpdateUI` / `PallyPowerGrid_Update`. `PallyPower.lua` is
  untouched.
  - Paladin **Settings**: lock frames · horizontal buff bar · hide Blizzard
    aura bar · buff-bar scale · grid scale · transparency · minimap
    button/skin · test mode.
  - Paladin **Buttons**: Aura / Seal / Righteous Fury buttons · smart
    buffs · normal-blessing preference · expiry sound · HD icons · color
    buff bar · UnitXP SP3 line-of-sight · scan frequency.
  - All classes: **Show minimap button** (the shared `minimapbuttonshow`).
- Buttons-tab audit fix: the utility-row toggle no longer requires the
  module to also declare grid buffs.

### Limitations
- Turtle-unverified: exercised statically only. On-realm test: hover a
  Priest/Druid class row (pop-out parity + CTRL+click roles), toggle strip
  buttons on a Shaman, and on a Paladin flip Aura/Seal/RF/scale from the
  panel and `/reload` to confirm persistence.
- 3.3.5-only options with no counterpart in this PallyPower fork (report
  channel, Show Pets, Salv in Combat, aura/seal tracker dropdowns, Wait for
  Players, buff-duration and layout dropdowns) are omitted — the fork's
  real `PP_PerUser` keys are authoritative. Background/border/status-colour
  pickers stay fixed at the 3.3.5 defaults (locked decision).

---

## [0.10.0] — 2026-07-08
**Options UI, Milestone A** — the tabbed options frame from
`docs/OPTIONS_UI_SPEC.md`: **Settings** and **Buttons** tabs live, **Raid**
tab stubbed until the Assignment & Sync milestone.

### Added
- **Tabbed options frame** (`Core/RallyPowerCP_Options.lua`), hand-built from
  1.12 building blocks (no Ace3): tooltip-skinned frame, hand-styled tabs,
  `OptionsCheckButtonTemplate` / `OptionsSliderTemplate` /
  `UIDropDownMenuTemplate` / `GameMenuButtonTemplate` widgets, ESC-close via
  `UISpecialFrames`. Open with **`/rpc options`** (any class) or
  **right-click the minimap icon** (non-Paladins; Paladins keep
  `PallyPower_Options`).
- **Settings tab** (all local, per character, applied live): show when
  solo / in party / in raid; show tooltips; test mode (same flag as
  `/rpc test`); UI scale slider 0.5–1.5 (default 1.0 — strips, class bar and
  pop-out; the Paladin engine keeps its own `/pp` scale); minimap icon skin
  dropdown; lock frame positions; Reset Frames button.
- **Buttons tab, generated per class** via the `M.optionsInfo` module
  descriptor contract (`check`/`select`/`slider`/`button`/`header`/`note`
  entries bound to `RallyPowerCP_Settings` keys, optional `get`/`set`/
  `onChange`). Strip classes (Shaman, Hunter, Warlock, Rogue) declare
  per-button enables (`btn_*`; strips re-flow and collapse) and dropdowns
  bound to the **same keys the mouse-wheel writes** (`shamanSel.*`,
  `hunterSting`, `lockCurse`, `roguePoison.*`) — dropdown and wheel are two
  views of one setting. Grid classes (Priest, Mage, Druid, Warrior) get
  auto-generated per-buff checks from `M.buffs` (`gridbuff_*`, honored in the
  buff-usable check) plus a utility-row toggle. Paladins see a note pointing
  at the authoritative legacy `/pp` options.
- **Raid tab** — deferred note; arrives with Assignment & Sync (Milestone B).

### Changed
- `/rpc test`, the options checkbox and the minimap flow all drive one shared
  `RallyPowerCP_SetTestMode`; `/rpc reset` shares its logic with the Reset
  Frames button.

### Limitations
- Turtle-unverified: built against 1.12 FrameXML templates that PallyPower's
  own XML already uses on this client, but the frame has not yet been
  exercised in-game — `/rpc options` on a strip class AND a grid class is the
  required on-realm test.
- The reference panel's background/border/status-color pickers are
  deliberately omitted (locked 3.3.5-parity decision).

---

## [0.9.0] — 2026-07-07
**Test mode** — preview and exercise the whole addon on an under-levelled
character. Toggle with **`/rpc test`** (any class).

### Added
- **`/rpc test`** toggles test mode (saved per character; strip headers show an
  orange **[TEST]** tag while it's on):
  - **Every option appears** in every cycle — grid buffs, totems, stings,
    curses, armor, poison types — even if not yet learned. Unlearned entries are
    marked with an orange `*`.
  - **Clicks simulate instead of cast:** timers start, buttons turn green, and
    chat prints `[test] would cast/drop/apply …` — but nothing is actually cast,
    so there are no failed-cast errors and no reagent use. Strip states run
    purely off the simulated timers (no target needed).
  - Turning it off returns everything to live casting and your real spellbook
    instantly.
- Exceptions that stay real (they read live data by nature): the **Soulstone**
  button (actual bag item + cooldown) and the **poison coating timers**
  (actual weapon enchants) — in test mode the poison *cycle* previews all
  types, but coating a weapon still requires the real item.

---

## [0.8.1] — 2026-07-07
**Strip dimensions now match the paladin template, Shaman moves onto the shared
engine, and lookups are cached.**

### Changed
- **All strip buttons are now the paladin-template size — 100×34 with a 26px
  icon and a 2px gap** (they were 138×30), with the buff-button text anatomy:
  label top-left, timer top-right, sub-label along the bottom. Applies to
  Shaman, Hunter, Warlock, and Rogue at once, since they share the engine.
- **`Class_Shaman.lua` refactored onto the shared strip engine**, deleting its
  bespoke duplicate strip code from 0.7.0. Behaviour is unchanged (wheel picks,
  click drops, right-click clears, cooldown-guarded cast-derived timers, saved
  selections) — your selected totems carry over; the strip's saved position
  resets once.

### Fixed
- **Performance:** spellbook lookups are cached (invalidated on
  `SPELLS_CHANGED`) and bag scans are cached (invalidated on `BAG_UPDATE`).
  Modules poll every 0.25s, so this removes constant full spellbook/bag rescans
  on the 1.12 client.

---

## [0.8.0] — 2026-07-05
**Three more classes — Hunter, Warlock, Rogue — on a new shared strip engine.**
Seven of nine classes now have a working module.

### Added
- **`Core\RallyPowerCP_Strip.lua`** — the reusable utility-strip engine extracted
  from the Shaman pattern: movable titled strip, skinned status buttons
  (icon / label / sub-label / timer, green–red–neutral), saved position per
  strip, tooltips, wheel plumbing, and shared helpers — spellbook lookup,
  bag search, "cast at target," and a **target-debuff tracker** that matches
  the debuff's icon against your own spellbook texture and **learns the real
  aura id under SuperWoW** (exact matching, no hard-coded ids or icons).
- **`Class_Hunter.lua`** — one **Sting** button: wheel picks Serpent / Scorpid /
  Viper (whichever you know), click applies it to your target; green with a
  cast-derived timer while your sting is up, red when the target lacks it.
- **`Class_Warlock.lua`** — three buttons:
  - **Armor** — Demon Armor/Skin (highest known), tracked on you, click to refresh.
  - **Soulstone** — the spec's glow button: green when a stone is in your bags and
    ready, red with a countdown while on cooldown, grey when you have none
    (clicking then *creates* one); click uses it on your friendly target or you.
  - **Curse** — wheel through every curse you know, click applies to the target,
    green while it's up.
- **`Class_Rogue.lua`** — three buttons:
  - **Expose Armor** duty — green/red on your target, click to apply.
  - **Main Hand / Off Hand poison** slots — wheel picks the poison type from
    what's actually in your bags (highest rank wins), click coats that weapon;
    shows the **real remaining time and charges** from `GetWeaponEnchantInfo`.

### Notes
- Sting/curse/expose timers are cast-derived per target (the client can't read
  debuff durations); presence detection is live and exact.
- Cross-player coordination (assigned duties, "who keeps what up") remains the
  sync milestone — these v1 modules are personal-accurate, per the design doc.
- Durations use vanilla defaults; any Turtle deltas are one-line edits.

---

## [0.7.0] — 2026-07-04
**First all-class module: Shaman totems** — and the reusable "cycle button"
pattern the other utility classes will inherit.

### Added
- **`Class_Shaman.lua`** — the Shaman gets its own compact strip of four element
  buttons (Earth / Fire / Water / Air) instead of the buff grid, since totems are
  party auras dropped at your feet, not buffs cast on players.
  - **Mouse-wheel** picks which totem to drop for that element (only totems you've
    learned); **left-click** drops it (self-cast, works in combat);
    **right-click** clears the tracked timer if you picked the totem back up.
  - Buttons show the totem's **real spellbook icon** (no icon guessing), green
    with a countdown while it's down, red when it isn't.
  - Your selected totem per element and the strip's position are **saved per
    character**. Toggle the strip from the minimap or `/rpc`.
  - Casting uses SuperWoW's `CastSpellByName` (falls back to a spellbook cast);
    timers are cast-derived, with a cooldown check so a totem on cooldown doesn't
    start a false timer.
- **Module hooks in the Core:** a class module can now provide `OnActivate` (build
  its own UI) and `Toggle` (own show/hide). The Core calls these for strip-based
  classes, so Shaman participates in the minimap/`/rpc` toggle like everyone else.

### Notes
- v1 tracks and drops **your own** totems. Cross-shaman coordination ("whose
  totem covers which party") uses SuperWoW's totem owner-suffix and arrives with
  the shared assignment/sync milestone.
- Totem durations use vanilla defaults; if Turtle differs (as blessings did),
  they're one edit each at the top of the module.

---

## [0.6.0] — 2026-07-03
**The 1.18.1-native pass — RallyPowerCP now uses SuperWoW where it removes a
1.12 limitation, with a graceful fallback when it's missing.** (Groundwork for
the all-class rollout: every class inherits this cleaner plumbing.)

### Added
- **SuperWoW detection** via `SUPERWOW_VERSION`. A one-time login notice tells
  players when it's missing (the addon then runs in 1.12 compatibility mode).
- **Spell-id buff detection.** SuperWoW makes `UnitBuff` also return each aura's
  spell id, so buffs are now matched by exact id instead of icon texture — no
  more "same icon" collisions. IDs are **learned at runtime** from the icon seed
  (captured the first time a buff is seen), so it needs no hard-coded ids and
  works on Turtle even where its ids differ from Vanilla.
- **Buff data gains an optional `ids = { ... }` field** for classes that want to
  pin exact aura ids; otherwise learning handles it.

### Changed
- **Casting now uses `CastSpellByName(spell, unit)`** under SuperWoW — a single
  call that targets the unit directly and can't disturb your current target.
  This replaces the `autoSelfCast`-CVar + `ClearTarget`/`SpellTargetUnit`/
  `TargetLastTarget` dance in both the Core caster and the pop-out row clicks.
  The old flow is kept as the no-SuperWoW fallback.
- Consolidated the three near-duplicate cast helpers into one primitive
  (`RawCastOnUnit`) used everywhere.

### Notes
- **VanillaFixes** remains a pure client-side performance/timing fix with no Lua
  API — a documented install requirement, nothing the addon calls.
- Detection/casting fall back to the exact 1.12 behaviour when SuperWoW is
  absent, so the addon still loads on a bare client.
- Not yet adopted (later steps): `UNIT_CASTEVENT` for cast-exact timers and
  shared timers (M1), and GUID-based identity for pets/totems (needed for the
  Shaman module).

---

## [0.5.1] — 2026-07-02
**The pop-out rows are now clickable for refreshes, with individual timers.**

### Added
- **Click a player in the pop-out to rebuff them**, official-flyout style:
  - **Left-click** casts the **Greater** blessing on that player (refreshing
    their class). Disabled in combat, per the project's combat rules.
  - **Right-click** casts the **Normal** single-target blessing — it honours
    that player's individual assignment if one is set, and **works in combat**
    (the one action permitted while fighting).
  - Casting goes through PallyPower's own spellbook tables and safety rails:
    auto-self-cast is suspended, your current target is preserved, the spell's
    cooldown is checked, and a 0.7s guard prevents double-click reagent burns.
    Out-of-range and dead targets get a feedback message instead of a wasted
    attempt.
- **Individual timers confirmed per player:** each row's countdown is that
  player's own (`m:ss`), ticked down by the engine, and a click-refresh
  restarts it — Normal casts reset that player's personal timer; Greater casts
  reset the class-wide one, exactly like the engine's own bookkeeping.

---

## [0.5.0] — 2026-07-01
**Phase 1 of the PallyPower 3.3.5 parity directive begins.** The pop-out is now
an exact replica of the WotLK player flyout.

### Changed
- **The player pop-out replicates `PallyPowerPopupTemplate`** from the official
  PallyPower Classic source (reference: `github.com/AznamirWoW/PallyPower`,
  `PallyPower_Wrath.xml`) — the WotLK-state design this project standardises on:
  - **100×34 buttons, stacked flush, floating bare** (no container panel).
  - **Skinned backdrop:** the official default "Smooth" statusbar texture (now
    shipped in `Skins\`) + Blizzard Tooltip border, coloured with the official
    defaults — green `0,0.7,0` Have · red `1,0,0` Need/Dead · blue `0,0,1`
    special/unknown — all at the official 0.5 alpha.
  - **Element-for-element layout:** 16×16 buff icon top-left (alpha 1 buffed /
    0.4 not), white personal timer beside it, player name bottom-right, green/red
    **"R"** range letter top-right, red **"D"** dead marker, and the main-tank
    icon for PallyPower-marked tanks.

### Notes
- 1.12 mappings: "Not Here" players get the blue preset + red R (a hidden
  player's buffs can't be read on this client); the official yellow
  "visible-but-far" R needs range data we don't track yet; the tank icon uses
  the official texture path, which may not exist in 1.12 art (harmlessly blank
  if so).
- Row clicks are display-only for now — porting the flyout's cast/assignment
  interactions is the next parity step, alongside the 84×80 class buttons and
  the main frame.

---

## [0.4.3] — 2026-07-01
**Pop-out reverted; design target changed to PallyPower 3.3.5.**

### Changed
- **Reverted the 0.4.2 pop-out** (the vanilla `PlayerButtonTemplate` rows and
  native assignment-click handlers). The pop-out is back to the 0.4.1
  colour-coded player bars (status-coloured bars with blessing icon, name, tank
  marker, and personal timer).
- **New project design target:** the pop-out — and, going forward, the whole
  Paladin experience — will be restyled to match **PallyPower 3.3.5** (the
  WotLK version in the project reference files) exactly, and that design will
  then be replicated for every other class. The 0.4.2 vanilla-template approach
  matched the wrong reference and is retired.
- The `Core\` / `Classes\` / `PallyPower\` folder structure from 0.4.2 is kept.

---

## [0.4.2] — 2026-06-30
**The pop-out becomes real PallyPower, and the addon gets an AutoRota-style
folder structure.**

### Changed
- **The player pop-out is now built from PallyPower's own `PlayerButtonTemplate`**
  — the exact rows the `/pp` grid uses: 13px-high flush-stacked rows, name on the
  left, the player's **individual assigned blessing** as a small icon on the
  right (just like the grid), and the main PallyPower frame's backdrop —
  following your PallyPower transparency setting.
- **Clicking a pop-out row runs PallyPower's real handlers** (not a copy):
  **Left-click** cycles that player's individual blessing (synced),
  **mouse-wheel** cycles it up/down, **right-click** clears it,
  **middle-click** toggles Main Tank, **CTRL+middle** toggles Healer — all with
  PallyPower's own sync messages and (as leader) raid-icon marking.
- **Name colours match PallyPower exactly**: Tank orange and Healer green
  override; otherwise the buff-tooltip status palette — Have (soft green), Need
  (soft red), Not Here (blue), Dead (bright red). A gold personal timer sits
  right of the name.
- **Restructured into an AutoRota-style folder layout**:
  - `Core\` — `RallyPowerCP_Core.lua` (engine) + `RallyPowerCP_Popout.lua`
  - `Classes\` — one module per class (unchanged)
  - `PallyPower\` — the untouched legacy engine (`PallyPower.lua/.xml`,
    `PallyPowerManaCost.lua`, `MinimapButton.lua/.xml`)
  - Root — `.toc`, `Bindings.xml` (must stay), `PallyPower-ResizeGrip.tga`
    (referenced by absolute path), docs, `Locale\`, `Icons\`, `HDIcons\`,
    `Sounds\`
  No code changes were needed for the move: the toc paths were updated, the
  legacy XML's relative `<Script>` references travel with their lua files, and
  every art path is absolute.

### Notes
- The pop-out rows use PlayerButton indices past `PALLYPOWER_MAXPERCLASS`, so
  the native grid's update loop never touches them, while the native click
  handlers parse them exactly like the grid's own rows. The PallyPower engine
  itself is still unmodified.
- Row clicks now do **assignment** (PallyPower semantics), not casting — casting
  stays on the buff button itself (left = class, right = single top-off), same
  as stock PallyPower.

---

## [0.4.1] — 2026-06-27
**Paladin pop-out, done right.** 0.4.0 added a *second* bar for Paladins; that was
the wrong call. This replaces it: the **original PallyPower buff bar** now gets
the hover player pop-out directly, and the duplicate bar is gone.

### Changed
- **Reverted the separate Paladin class bar** from 0.4.0. Paladins use the
  original PallyPower bar/grid again — no second bar on screen.
- **Hovering a blessing button** on the PallyPower buff bar now opens the
  colour-coded **player pop-out** to its left (green Have / red Need / blue Not
  Here / dark-red Dead), each bar showing the blessing icon, the player's name, a
  tank marker (MT), and that player's personal timer. This replaces the old text
  tooltip on those buttons.

### Added
- **`RallyPowerCP_Popout.lua`** — a self-contained pop-out that reads PallyPower's
  own per-button data (`need` / `have` / `range` / `dead` lists + `LastCastPlayer`
  timers) and tank flags. It does **not** modify the PallyPower engine — it wraps
  the existing buff-button hover handler — so the classic bar behaves exactly as
  before, just with the visual pop-out instead of the text tooltip.

### Removed
- `Classes/Class_Paladin.lua` (the 0.4.0 module) — no longer needed.

---

## [0.4.0] — 2026-06-26
**M0 begins — Paladin becomes a class-bar class.** First step of the Foundation
milestone from the roadmap: bring Paladin into the same system as everyone else.

### Added
- **`Class_Paladin.lua`** — Paladins now get the class rows + hover player
  pop-out, exactly like Priest/Mage/Druid. All six blessings are included with
  their normal (single-target) and greater (group) versions and Turtle durations
  (10 min / 30 min).
- **Per-class blessing assignment is built in** via the existing mouse-wheel:
  scroll a class row to set that class's blessing (e.g. Might on the Warrior row,
  Wisdom on the Mage row). Left-click casts the Greater (group) blessing on the
  class; right-click tops off the one member who needs the normal blessing. In
  the pop-out, left-click a player = Greater, right-click = normal single target.

### Changed
- Paladins are no longer walled off from the bar. The minimap **left-click** and
  **/rpc** now toggle the new bar for Paladins; the Smart Buff key works too.

### Notes
- **The original PallyPower blessing grid still runs**, independently and
  unchanged — open it with **/pp**. You'll have both UIs available; hide whichever
  you don't want. (Retiring or merging the legacy grid is later M0 work.)
- This bar is **local-only** for now — it tracks the blessings *you* cast.
  Cross-paladin sync (and interop with stock PallyPower) lands in M1.
- Auras / Seals / Righteous Fury (the paladin top-anchor controls) are M3; the
  classic self-bar still provides them today.
- Blessing **reagents aren't pre-checked** (same as the other group buffs) — a
  cast without reagents fails with the normal game error.

---

## [0.3.2] — 2026-06-15
Pop-out refinements to match PallyPower's player-list behaviour.

### Changed
- **The pop-out now expands to the *left*** of the class rows (was the right),
  matching PallyPower's layout.
- **Replaced the plain text tooltip with a stack of colour-coded player bars.**
  Each bar shows the buff icon, the player's name, a status colour (green Have /
  red Need / blue Not Here / dark-red Dead) and that player's personal timer —
  instead of the old dark text panel.
- **Mouse-wheel is now per-class.** Scrolling a class row cycles *that class's*
  buff only (e.g. the Druid row toggles Mark of the Wild -> Gift of the Wild ->
  Thorns), so each class can display and cast a different buff at the same time.

### Added
- **Role markers on the player bars.** Each bar shows a role slot (an "R" when
  unassigned); **CTRL+click** a player cycles their role — Main Tank (gold) ->
  Main Assist (cyan) -> none. Roles are saved per character.
  - *Local only for now:* roles aren't yet shared with other RallyPowerCP users
    and aren't yet wired into smart targeting (e.g. directing Priest shields to
    tanks). Those come with the upcoming role/sync milestone.

---

## [0.3.1] — 2026-06-12
The interactive pop-out (Option A, stage 2 of 2). Option A is now complete.

### Added
- **Hover pop-out side panel.** Hovering a class row opens a panel to its right
  listing every player in that class, each colour-coded by status — green
  (Have), red (Need), blue (Not Here), bright red (Dead) — with that player's
  personal countdown timer. It stays open while the cursor is over the row or
  the panel, and updates live.
- **Click an individual player** in the pop-out:
  - **Left-click** casts the group version covering that player's subgroup. It's
    skipped if they already have the buff (no wasted reagents) and is disabled in
    combat.
  - **Right-click** casts the single-target version on just that player — the
    "top off the one who missed it" action — and works in combat.

### Notes
- Deferred to later milestones (they need the assignment/role systems): the
  mouse-wheel-per-player custom assignment and CTRL+click tank/assist roles.
- Per-player timers are exact only for buffs you cast yourself; a player buffed
  by someone else shows as covered with no countdown (1.12 client limitation).

---

## [0.3.0] — 2026-06-12
The class-grouped grid (Option A, stage 1 of 2). The bar is now organized like
PallyPower's: one row per class in your group.

### Added
- **Class-grouped grid.** Instead of one row, the bar now shows **one row per
  class present** in your party/raid (in PallyPower's class order), each styled
  like the Paladin buff-bar button — your class icon, the buff icon, status
  colour, count, and the earliest timer for that class.
- **Per-class click actions**, scoped to just that class's members:
  - **Left-click** casts the group/raid version on that class (cycling through
    its members, renew-capable).
  - **Right-click** is a smart top-off on the one member of that class who needs
    it most (missing first, else lowest time left). Combat-locked, 4-min floor.
  - **Scroll** changes the globally-selected buff shown on every row.
  - **Hover** shows that class's members broken into Have / Need / Not Here /
    Dead.

### Fixed
- Completed the data layer the grid needs: the roster scan now buckets members
  by class and computes per-class coverage and timers (previously the grid had
  no data feeding it, so no rows appeared). Rows rebuild automatically when the
  set of classes in your group changes.

### Notes
- Stage 2 (next) is the interactive pop-out: a side panel off each class row
  listing every individual player with status + timer, click-to-buff individuals.
- The grid is players-only for now; pets aren't bucketed into a row yet.

---

## [0.2.3] — 2026-06-12
### Changed
- **The class row now matches PallyPower's buff-bar button exactly.** It was far
  too large; it's now the same 100×36 size with two 26×26 icons (your class icon
  on the left, the tracked buff on the right), the same Tooltip-textured backdrop
  coloured by status — red when someone needs it, yellow when it's expiring,
  green when everyone is covered — and the same `GameFontHighlightSmall` timer
  and count text. The values are taken straight from the Paladin frame so the
  look is identical.

---

## [0.2.2] — 2026-06-12
Hotfix: the class bar failed to appear for every non-Paladin class in 0.2.1.

### Fixed
- **The bar built nothing on non-Paladin classes.** The throttle's cooldown
  swirl used a Cooldown frame template that isn't reliable on the 1.12 client;
  creating it errored while building the bar, so the bar never appeared. Replaced
  it with a simple darkening overlay on the icon — same "you just cast, wait for
  the GCD" cue, no fragile frame template.
- **Combat detection** no longer calls `UnitAffectingCombat` (a later-expansion
  API); it now tracks combat with the vanilla `PLAYER_REGEN_DISABLED/ENABLED`
  events, so the right-click combat lockout works correctly on 1.12.
- The bar build is now wrapped so that, if anything unexpected errors on a custom
  client, the error is printed in chat instead of the bar silently failing.

---

## [0.2.1] — 2026-06-12
Reworked the class bar into a single scrollable row and adopted the spec's
main-button click model.

### Changed
- **One scrollable class row instead of one button per buff.** The bar now shows
  a single PallyPower-styled row — icon on the left, large countdown on the
  right, on a green (covered) / red (someone needs it) status bar. Scroll the
  mouse wheel to switch which buff it shows; the timer and the Have/Need/Not
  Here/Dead tooltip follow. Your selection is remembered.
- **New click model on the class row:**
  - **Left-click** casts the **group/raid version** (Prayer of…, Gift of the
    Wild, Arcane Brilliance), covering a whole subgroup at once; renew-capable.
  - **Right-click** is a **smart top-off**: it casts the single-target version on
    the one member who needs it most (missing first, otherwise the lowest time
    remaining). Disabled in combat, and it won't overwrite a buff with 4+ minutes
    left, to save reagents.
- The expiry **ding now fires for every tracked buff**, even one you aren't
  currently showing on the row, so nothing slips by while it's scrolled off.

### Added
- **Throttle guard.** After a cast the row shows a brief cooldown swirl and
  ignores clicks for the global-cooldown window, so a panicked double-click can't
  burn a second set of reagents.

### Notes
- Per-member timing still relies on your own casts — the 1.12 client can't read
  how long another player's buff has left — so the 4-minute no-overwrite guard
  and "lowest time remaining" only consider members you personally buffed; others
  showing the aura are treated as covered.

---

## [0.2.0] — 2026-06-12
Modular rebuild. The all-class bar is now a clean engine plus one file per class.

### Changed
- **Restructured into an AutoRota-style architecture.** The monolithic
  `RallyPowerCP_Classes.lua` is split into a class-independent engine
  (`RallyPowerCP_Core.lua`) and one module per class under `Classes\`
  (`Class_Priest.lua`, `Class_Mage.lua`, `Class_Druid.lua`,
  `Class_Warrior.lua`). Each module registers via `RallyPowerCP:NewClass(token)`
  and supplies only its data. Behaviour for existing classes is unchanged.
  Adding a class is now "copy a file, list it in the `.toc`."

### Added
- **Warrior support** — Battle Shout, tracked as a new **self-cast** buff type:
  one click refreshes party members in range (no per-member targeting), while
  coverage and the countdown timer work normally. The `selfcast` flag is
  reusable for other shout/aura buffs.
- **Scroll-to-switch-buff.** Roll the mouse wheel over any buff button to cycle
  it through your class's buffs; the icon, need count, timer, and the
  Have/Need/Not Here/Dead tooltip all follow. (PallyPower's scroll-to-assign,
  brought to the class bar.)

### Changed
- **Clicks can renew already-buffed members.** Clicks still prioritize members
  who are *missing* the buff, but once everyone in range is covered, further
  clicks renew the next member in the cycle instead of doing nothing — so you
  can top anyone off at any time. Targeting a friendly group member always
  (re)buffs that member. The Smart Buff key still stops once everyone is covered.

---

## [0.1.2] — 2026-06-12
### Added
- **PallyPower-style buff tooltips for every class.** Hovering a buff button
  lists group members by status — **Have** (green), **Need** (red),
  **Not Here** (blue, out of range), **Dead** (bright red) — using the same
  labels, colors, and categorization as the Paladin buff bar.
- **Priest utility row** (top of the bar, like the Paladin seal buttons):
  **Power Word: Shield** (your friendly target, else the lowest-health living
  member in range) and **Fear Ward** (your target, else yourself). Icons are
  read live from your spellbook; only learned spells appear.

### Fixed
- Clicking a buff now **cycles** through party/raid members instead of sticking
  on you — a per-buff round-robin cursor advances each click (and handles
  clicking faster than the buff visibly applies).
- A click when everyone is already covered no longer wastefully re-casts on you.

---

## [0.1.1] — 2026-06-12
### Added
- Class-bar casts announce in green like the Paladin module
  ("Casting <buff> on <Class> (<Name>)"), respecting your feedback setting.

### Fixed
- Removed the cosmetic `DoEmote("STAND")` that threw "You can't do that while
  moving!" on both the Paladin blessings and the class bar. Casting auto-stands
  you anyway.
- A buff click no longer hits your current target when it's an NPC, a stranger,
  or anyone outside your party/raid.

---

## [0.1.0 → 0.1.1 groundwork]
Smart casting, countdown timers, the expiry ding, the Smart Buff key binding,
and the five minimap icon skins all landed during early development and were
first stamped at 0.1.1. See git history for the blow-by-blow.

---

## [0.0.1] — 2026-06-12
Initial release, by **Subtilizer (Torchlite)**.

### Added
- New `RallyPowerCP.toc` identity (title, author, version, per-character saved
  variables) and the first all-class buff tracker for Priest, Mage, and Druid.
- Coverage scanning by buff icon texture; a movable, PallyPower-styled bar.

### Changed
- Rebranded PallyPowerTW → RallyPowerCP throughout (identity, paths, titles,
  slash commands, key-binding header, credits), keeping internal `PallyPower_*`
  Lua names to avoid destabilizing the proven Paladin engine. Minimap left-click
  routes by class (Paladin grid vs class bar).

### Fixed
- Turtle blessing durations now apply on every realm (10-min / 30-min), not just
  a hard-coded realm list.
- Suppressed the false "new version available" message triggered by other
  PallyPower users on the shared `PLPWR` sync channel.

### Compatibility
- Paladin blessing sync with original PallyPower / PallyPowerTW users is
  unchanged (shared `PLPWR` prefix and message format). The all-class bar is
  local-only and sends nothing over the network.
