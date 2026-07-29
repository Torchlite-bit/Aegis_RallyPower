# Aegis: RallyPower

**Raid buff coordination for every class, not just paladins.**

[![Discord](https://img.shields.io/badge/Discord-join%20us-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/3wTfRU8V9Z)
[![Client](https://img.shields.io/badge/client-WoW%201.12%20(vanilla)-c79c6e?style=flat-square)](https://turtle-wow.org)
[![SuperWoW](https://img.shields.io/badge/SuperWoW-recommended-33ffcc?style=flat-square)](#client-mods)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

PallyPower solved buffs — for paladins. Everyone else got a macro, a spreadsheet,
and someone yelling "who has fort?" in raid chat. Aegis: RallyPower gives all
nine classes the same treatment: a bar that knows who's missing what, a panel
that says who covers what, and timers that count down from **everyone's** casts,
not just yours.

> Built for **Turtle WoW 1.18.1**, which runs the original **WoW 1.12 (vanilla)**
> client on **Lua 5.0**. Not Classic. Not retail. Real vanilla.

**[💬 Join the Discord](https://discord.gg/3wTfRU8V9Z)** for help, bug reports,
and feature ideas.

---

## Contents

- [What it does](#what-it-does) — per class, and the panel that ties them together
- [Install](#install)
- [Using it](#using-it) — commands and the minimap button
- [Client mods](#client-mods) — SuperWoW & VanillaFixes
- [A few honest notes](#a-few-honest-notes)
- [Under the hood](#under-the-hood)
- [Contributing](#contributing)

---

## What it does

### ⚔️ Your class bar — one row per class, and it knows who's missing what

Log in on any class and you get a bar tailored to it. For the buffing classes
it's **one row per class in your raid**, styled exactly like PallyPower's:
red when someone needs it, green with a timer when they're covered, and a count
of how many are still missing.

- **Scroll a row** to change *that class's* buff — the Druid row can show Thorns
  while the Mage row shows Brilliance.
- **Left-click** casts the group version down that class; **right-click** tops
  off the one person who needs it most (works in combat).
- **Hover a row** for a pop-out of every player in it — green Have, red Need,
  blue Not Here, dark-red Dead — each with their own timer. Click a name to buff
  just them.
- A **ding at 60 seconds** on anything about to drop, even a buff scrolled off
  the visible rows.

| Class | What you get |
|---|---|
| **Paladin** | The original PallyPower blessing/aura/seal grid, untouched — plus a hover **player pop-out** on every buff button |
| **Priest** | Fortitude · Divine Spirit · Shadow Protection, plus Fear Ward |
| **Mage** | Arcane Intellect, plus a **Scorch** debuff tracker on your target |
| **Druid** | Mark of the Wild · Thorns |
| **Warrior** | Battle Shout, plus a **Sunder Armor** tracker |
| **Shaman** | **All Totems** — one click drops all four, paced through the GCD — plus per-element pickers |
| **Hunter** | Sting picker, applied to your target |
| **Warlock** | Armor · Soulstone (knows if one's in your bags) · Curse cycle |
| **Rogue** | Expose Armor, plus main/off-hand poison slots with real charges left |

### 📋 The assignment panel — "who covers what"

`/rpc assign` opens the raid-leader view. Six tabs, and **everything syncs to
other Aegis users automatically.**

| Tab | What it's for |
|---|---|
| **Blessings** | PallyPower's assignment grid, with Aura and Seal columns first and each paladin's ranks, talents and Symbol count under their name |
| **Totems** | Shaman × element grid, auto-grouped |
| **Raid Buffs** | Caster × class grid for priests, mages and druids |
| **Debuffs** | Who's on Sunder, who's on Scorch |
| **Kick** | Who has an interrupt, and whose is off cooldown — **yours exact, everyone else's observed from their actual casts** |
| **Roles** | Main Tank + two off-tanks from dropdowns, healer marking, and a per-tank blessing override ("gets Kings instead of Salv") |

The Blessings tab drives PallyPower's own tables and sends its own byte-identical
messages, so **paladins running stock PallyPower or PallyPowerTW interoperate
with you in both directions.** Everything else rides a separate `RPCX` channel
that stock PallyPower simply ignores.

### ⏱️ Timers that count everyone's casts, not just yours

The 1.12 client can't *read* how long is left on someone else's buff. So with
**SuperWoW** loaded, Aegis watches casts as they happen and times them itself —
when another priest throws Fortitude, you see the countdown.

This feeds everything at once: the class bar, the pop-out, the coverage counts,
smart-targeting, and the expiry ding. Turn it off with **"Time other players'
buffs"** in Options if you'd rather not.

### 🧪 Test mode — try it all solo

`/rpc test` seats a **full 40-man preview raid** of lore characters, one of every
class and spec. Every option shows up (unlearned ones marked `*`), clicks
simulate casts and start real timers, and every tab of the panel becomes
explorable on a level 5 alt.

It's a sealed sandbox: preview edits live in their own store and **nothing is
ever sent over the wire**, so you can't pollute a real raid by experimenting.

---

## Install

1. Download this repo (**Code → Download ZIP**, or clone it).
2. Drop the folder into:
   ```
   World of Warcraft/Interface/AddOns/Aegis_RallyPower
   ```
3. **The folder must be named exactly `Aegis_RallyPower`** — GitHub's ZIP unpacks
   as `Aegis_RallyPower-main`, so rename it or the addon won't load.
4. Restart the client.

> **Upgrading from the old `RallyPowerCP` build?** Delete that folder first.
> The rename went all the way down, and old saved settings aren't carried over.

Everything is bundled — art, sounds, textures — with every path verified against
a real file.

---

## Using it

| Do this | Get that |
|---|---|
| **Left-click** the minimap icon | The paladin grid, or your class bar |
| **Right-click** the minimap icon | Options |
| **Shift-click** the minimap icon | Cycle the icon skin (five ship) |
| `/rpc` *(or `/aegis`)* | Toggle your class bar |
| `/rpc assign` | The assignment panel |
| `/rpc options` | Settings |
| `/rpc test` | Test mode on/off |
| `/rpc sync` | Force a full assignment re-sync |
| `/rpc slots` | Tank plan + whether sync is actually flowing |
| `/rpc castdbg` | Log raw cast events (verbose — for debugging) |
| `/rpc reset` | Put the bar back if it's off-screen |
| `/pp` | The classic PallyPower grid (paladins) |

Bind **"Smart buff: next member missing any buff"** in the Key Bindings menu to
work down the raid hands-free — each press buffs the next person missing
anything.

---

## Client mods

**[SuperWoW](https://github.com/balakethelock/SuperWoW) — strongly recommended.**
Buff detection becomes exact (spell IDs instead of icon matching), casting stops
needing the target dance, and — the big one — Aegis can see *other people's*
casts, which is what makes raid-wide timers and the Kick tab work. Without it the
addon still runs, it just falls back to icons and your own casts. You'll get a
one-time notice at login.

**[VanillaFixes](https://github.com/hannesmann/vanillafixes) — recommended.**
Kills client stutter and animation lag. Aegis doesn't depend on it, but every
timer in the game feels better with it.

---

## A few honest notes

- **Other players' timers come from watching casts, not reading buffs** — the
  1.12 API simply can't read them. A caster has to come into range **once**
  before their casts register; after that the timer runs locally and keeps
  counting no matter how far apart you drift.
- **Durations come from the spell catalog, not the wire.** Every tracked raid
  buff is single-duration across ranks in vanilla, so this only matters if
  Turtle changes one. Blessings are pinned to Turtle's forced values
  (10 min / 30 min greater).
- **Interrupt cooldowns are vanilla defaults** and Turtle-unverified. If one is
  wrong it's a one-line edit in the `INTERRUPTS` table — tell us on Discord and
  we'll fix it upstream.
- **Two channels, on purpose.** Blessings ride PallyPower's `PLPWR` messages
  byte-for-byte so stock-PallyPower paladins stay compatible forever; everything
  else rides `RPCX`, which they ignore harmlessly.
- **Assignments are last-writer-wins,** exactly like PallyPower. Human-paced
  clicking makes races a non-issue, and a leader who wants to override just
  clicks — their message lands last.

---

## Under the hood

```
Aegis_RallyPower/
├── Aegis_RallyPower.toc
├── Bindings.xml              key bindings (must stay at the root)
├── Core/
│   ├── Aegis_Core.lua        the class-independent engine
│   ├── Aegis_CastWatch.lua   the addon's single UNIT_CASTEVENT handler
│   ├── Aegis_Strip.lua       reusable strip engine behind every class bar
│   ├── Aegis_Assign.lua      shared assignment data model
│   ├── Aegis_Sync.lua        the RPCX protocol (broadcast, receive, chunking)
│   ├── Aegis_AssignPanel.lua the "who covers what" panel
│   ├── Aegis_Options.lua     the tabbed options frame
│   └── Aegis_Popout.lua      the PallyPower buff-bar player pop-out
├── Classes/                  one module per class — pure data, no UI
├── PallyPower/               the original engine, deliberately untouched
└── Locale/  Icons/  HDIcons/  Sounds/
```

The core knows **nothing** about specific classes. Each `Classes/Class_*.lua`
registers with `AegisRP:NewClass("TOKEN")` and supplies only its data; the engine
does the scanning, casting, timing and drawing. Adding a buff is usually a single
table entry.

`Aegis_CastWatch.lua` owns the addon's **only** `UNIT_CASTEVENT` registration.
Consumers subscribe:

```lua
AegisRP.CastWatch.Subscribe(function(caster, target, spell, id, evt)
    -- caster/target are player names; spell is resolved; evt is "CAST"/"START"
end)
```

Watchers are pcall-isolated, so one broken consumer can't blind the others.

The PallyPower engine runs **unmodified**. The pop-out grafts onto it by reading
its own per-button data rather than patching it — which is why blessing sync
stays byte-compatible with stock.

Everything is **Lua 5.0 and 1.12 API only** — no `#`, no `string.gmatch`, no
`select`, no `%` operator, no secure templates. [`CLAUDE.md`](CLAUDE.md) has the
full rules and the reasons behind them, most learned the hard way.

---

## Something broken?

1. Check the **version** (`## Version:` in the `.toc`, currently **0.15.0**) and
   quote it.
2. `/rpc castdbg` logs raw cast events if timers look wrong — it's verbose, so
   flip it back off after a few seconds.
3. `/rpc slots` shows whether sync is actually reaching you and from whom.
4. Tell us on **[Discord](https://discord.gg/3wTfRU8V9Z)** or open an
   [issue](https://github.com/Torchlite-bit/Aegis_RallyPower/issues). Screenshots
   help enormously, especially for anything layout-related.

Recent changes are in [CHANGELOG.md](CHANGELOG.md).

---

## Contributing

PRs welcome — come say hi on **[Discord](https://discord.gg/3wTfRU8V9Z)** first
if you're planning something big.

Three requests:

1. Keep inside the 1.12 / Lua 5.0 rules in [`CLAUDE.md`](CLAUDE.md) — they're
   there because breaking them fails at *runtime*, not at load.
2. Run `python3 scripts/verify.py` before you push; it catches the Lua 5.1-isms
   that a 1.12 client won't.
3. Bump the version in **both** `Aegis_RallyPower.toc` and this README, and add
   a line to [`CHANGELOG.md`](CHANGELOG.md).

## Credits

Aegis: RallyPower is a fork of **PallyPowerTW** by ivanovlk, itself built on the
original **PallyPower** by Hjorim, Sneakyfoot, Rake, Xerron, Azgaardian and
Aznamir. Spanish localization by Nuevemasnueve. Maintained by
**Subtilizer (Torchlite)**.

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**[💬 Discord](https://discord.gg/3wTfRU8V9Z)** · **[📜 Changelog](CHANGELOG.md)** · **[🐛 Issues](https://github.com/Torchlite-bit/Aegis_RallyPower/issues)**

*Aegis: RallyPower is part of the Aegis addon series. Now go buff someone.* ⚔️

</div>
