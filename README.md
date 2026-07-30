# Aegis: RallyPower

**All-class raid buff coordination for Turtle WoW 1.18.1** (1.12 client)

[![Discord](https://img.shields.io/badge/Discord-join%20us-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/hsgPTNkSX)
[![Octo WoW](https://img.shields.io/badge/Octo%20WoW-1.18.1-4c1?style=flat-square&labelColor=555)](https://octowow.st/)
[![Capy WoW](https://img.shields.io/badge/Capy%20WoW-1.18.1-4c1?style=flat-square&labelColor=555)](https://capycraft.io/)

[![SuperWoW](https://img.shields.io/badge/SuperWoW-Recommended-fe7d37?style=flat-square&labelColor=555)](https://github.com/balakethelock/SuperWoW)
[![Nampower](https://img.shields.io/badge/Nampower-Recommended-fe7d37?style=flat-square&labelColor=555)](https://github.com/brues-code/nampower)
[![UnitXP_SP3](https://img.shields.io/badge/UnitXP__SP3-Recommended-fe7d37?style=flat-square&labelColor=555)](https://codeberg.org/konaka/UnitXP_SP3)
[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Recommended-fe7d37?style=flat-square&labelColor=555)](https://github.com/brues-code/ClassicAPI)

A comprehensive buff management addon for Turtle WoW that extends PallyPower's Paladin-focused toolkit to all nine classes. Coordinate raid buffs, totems, debuffs, and interrupts across your entire group with shared assignment tracking, test-mode previews, and zero network traffic (unless you're coordinating).

**By Subtilizer (Torchlite) · Built on PallyPowerTW (ivanovlk) & original PallyPower**

---
## 📸 Screenshots

<!-- 
TEMPLATE INSTRUCTIONS: 
Replace the placeholder image links (e.g., 'path/to/your/image1.png') inside the parentheses with the actual URLs or relative file paths to your screenshots once you have them uploaded to your repository. 
-->


<img width="1539" height="688" alt="class buff" src="https://github.com/user-attachments/assets/921b44d4-564b-4a77-8323-59f40af7478e" />

<img width="1556" height="688" alt="raid roles" src="https://github.com/user-attachments/assets/51575c1f-b2f1-4f81-be10-b1c241e9ca0d" />




---

## ✨ Key Features

### 📊 Per-Class Buff Management
Every class gets a dedicated buff bar with its own tracking, UI, and controls:

| Class | Features |
|-------|----------|
| **Paladin** | The original PallyPower blessing/seal/aura grid + a **hover player pop-out** for each buff (see who has it, who needs it, click to refresh) |
| **Priest** | Power Word: Fortitude, Divine Spirit, Shadow Protection + Fear Ward utility |
| **Mage** | Arcane Intellect buff + Scorch debuff-tracking on targets |
| **Druid** | Mark of the Wild, Thorns |
| **Warrior** | Battle Shout (party-wide) + Sunder Armor tracking/application |
| **Shaman** | **All Totems** button (drops 4 totems in order via GCD), element toggles |
| **Hunter** | Sting selection and application on targets |
| **Warlock** | Armor (tracked), Soulstone (status tracked), Curse cycle |
| **Rogue** | Expose Armor tracking + Main/Off-hand poison selection |

### 🎯 Assignment Panel ("Who Covers What")
Coordinate assignments across the raid with real-time sync:

- **Blessings tab** — PallyPower's assignment grid with exact ranks/Symbol counts (byte-compatible with stock PallyPower)
- **Raid Buffs** — Caster × class matrix for Priest/Mage/Druid buffs
- **Totems** — Shaman totem assignments (auto-grouped, icon labels)
- **Debuffs** — Warrior Sunder, Mage Scorch duty tracking
- **Kick tab** — The interrupt **rotation**: click a name to add them, mouse-wheel to reorder. Whoever sits highest and is off cooldown is up next
- **Roles** — Mark Main Tank/Off-Tanks, set per-tank blessings, mark healers

Test mode seats a full 40-player preview raid so you can test on low-level characters.

### 🦶 Kick Rotation
Set a priority order of interrupters; the whole raid gets it. Your strip then answers the one question that matters mid-pull:

**🔴 KICK NOW** · **🟡 On deck** · **🟢 Holding** · **⚫ Cooldown**

Whose turn it is isn't a counter anyone advances — it's *whoever sits highest in the order and is actually off cooldown*. Kicking puts you on cooldown, which hands the top spot to the next person automatically, and anyone dead, absent or on cooldown gets skipped instead of stalling the rotation. Nothing to drift out of sync, because there's no turn pointer to drift.

A sound fires when you reach the top — you're watching the boss, not the strip.

### 📡 Shared Assignment Sync (RPCX Protocol)
- Broadcast your assignments + receive others' over a dedicated addon channel
- Leader-gated edits; Free Assignment mode lets members edit freely
- Automatic message chunking for large assignment blocks
- Shares the tank plan and the kick rotation; members broadcast their own interrupt cooldowns, so the Kick tab is right even for people you can't see
- No impact on blessings — they stay on PLPWR (stock PallyPower compatible)

### ⏱️ Cast-Exact Timers
The 1.12 client can't *read* how long is left on someone else's buff. With **SuperWoW**, Aegis watches casts as they happen and times them itself — so a buff *another* priest applies gets a real countdown, not a guess.

One hook feeds everything: the class bar, the player pop-out, coverage counts, smart-targeting and the expiry ding all read the same shared store. Toggle it off with **"Time other players' buffs"** in Options.

### 🧪 Test Mode
```macro
/rpc test
```

Preview every buff on a fake 40-man raid of lore characters, simulate casts with real timers, and test UI changes without affecting live assignments.

### 🔧 Minimap Icon
Left-click opens the right thing for your class. Right-click opens Options. Shift-click cycles skins (5 included: Blue, Gold, Ivory, White, Pearl).

---

## 🚀 Quick Start

### Installation
1. Download and extract to `Interface/AddOns/Aegis_RallyPower/`
   - Upgrading from pre-rebrand? Delete old `RallyPowerCP/` folder first (SavedVariables aren't carried over)
2. Launch WoW, log in
3. Left-click the minimap icon or use `/rpc` to toggle the buff bar

### Commands

| Command | What It Does |
|---------|-------------|
| `/rpc` (or `/aegis`) | Toggle the class buff bar |
| `/rpc options` | Open settings (or right-click minimap icon) |
| `/rpc assign` | Open the assignment panel (or right-click a strip title) |
| `/rpc kick` | Show/hide the kick-rotation strip (interrupt classes) |
| `/rpc test` | Test mode — preview buffs on all specs |
| `/rpc sync` | Force a full assignment resync |
| `/rpc slots` | Tank plan, plus whether sync is actually reaching you |
| `/rpc castdbg` | Log raw cast events (SuperWoW only; for debugging) |
| `/rpc reset` | Put the bar back if it ends up off-screen |
| `/rpc icon` | Cycle the minimap icon skin (or shift-click the icon) |
| `/pp`, `/pallypower`, `/rp`, `/rallypower` | PallyPower grid / buff bar (Paladins) |
| `/rpc legacy` | The classic PallyPower options frame (escape hatch) |

**Key Binding:** Bind "Smart buff: next member missing any buff" to top off the group hands-free.

---

## 🛠️ Development Status

### ✅ Completed
- All nine class modules (bars, buttons, targeting)
- Shared assignment data model (blessings, totems, debuffs, utilities, interrupts)
- RPCX sync protocol (broadcast & receive, leader permissions, Free Assignment) — **validated on two clients**
- Assignment panel with all six tabs
- Mage Scorch debuff-tracking button + debuff-button infrastructure
- Message chunking for large assignment blocks
- **Cast-exact shared timers** — buffs *other* people cast are timed, not guessed
- **Raid-wide interrupt timers** — members broadcast their own kick cooldowns, so distance doesn't matter
- **Kick rotation** — shared priority order, personal strip, cooldown/dead auto-skip
- Test mode with 40-player preview raid, including a live kick-rotation simulation
- Full Options UI with per-class toggles and settings

### ⏳ Next
- **Live cast trigger** — the cast watcher already sees *hostile* casts, so the kick strip could fire the moment the mob starts casting, not just when your turn comes round
- **Raid-marker binding** — pin a rotation to Skull/Cross when two mobs need interrupting
- **ClassicAPI aura tier** *(evaluated, deferred)* — its `C_UnitAuras` exposes true `expirationTime` and server-authoritative, caster-modified durations, which would retire the catalog-duration limitation. If adopted it goes in as an *optional third tier* behind SuperWoW, never a dependency

### 🔮 Future Possibilities
- Per-caster Free Assignment (allowing members to edit specific rows)
- Optional chat announce when the rotation hands off
- Raid buff grid view (if assignment panel grows)

---

## 📋 Requirements

### Client
* :crystal_ball: **SuperWoW** - Strongly Recommended
  Enables exact spell-ID-based buff detection and clean one-call casting. Without it, the addon falls back to icon-matching and target-juggling (less reliable, but works).
  ↳ [SuperWoW Release](https://github.com/balakethelock/SuperWoW/releases/tag/Release) | [Features Wiki](https://github.com/balakethelock/SuperWoW/wiki/Features) | [SuperAPI Addon](https://github.com/balakethelock/SuperAPI)

- 🔨 **VanillaFixes** — Recommended  
  Eliminates client stutter. Not required, but makes timers and UI smoother.
  ↳ [VanillaFixes Release](https://github.com/hannesmann/vanillafixes.git)

- 🎯 **UnitXP_SP3** — Recommended
  Adds a real line-of-sight check. Aegis uses it when loaded to skip targets it can't actually see — turn it on with **UnitXP SP3 line-of-sight** in Options.
  ↳ [UnitXP_SP3](https://codeberg.org/konaka/UnitXP_SP3)

- ⚡ **Nampower** — Recommended
  Removes the client's cast-queue delay. Aegis doesn't call it, but every click you make lands faster with it loaded.
  ↳ [Nampower](https://github.com/brues-code/nampower)

- 🧩 **ClassicAPI** — Recommended
  Backports modern API namespaces to 1.12. Aegis doesn't use it *yet* — its `C_UnitAuras` would give true expiration times for other players' buffs, which is on the roadmap as an optional extra tier.
  ↳ [ClassicAPI](https://github.com/brues-code/ClassicAPI)

### Is anything actually required?

**No — Aegis runs on a stock 1.12 client with none of them.** Every SuperWoW call
site has a working fallback: icon-texture matching instead of spell IDs, and the
classic CVar/target-juggling cast instead of one-call casting. You get a one-time
notice at login telling you it's in compatibility mode.

What you lose without SuperWoW is **one** thing: cast observation. That means
other players' *buff* timers fall back to counting from your own casts, the way
PallyPower has always done it. Their *interrupt* cooldowns are unaffected —
those are broadcast by each member, so they work on a bare client.

UnitXP_SP3 is opt-in and off by default; Nampower and ClassicAPI aren't called
at all. Load them because they make the whole game better, not because Aegis
needs them.

### Compatibility
- **Paladin sync works!** Aegis: RallyPower keeps PallyPower's `PLPWR` sync channel and message format, so Aegis Paladins coordinate blessings with stock PallyPower / PallyPowerTW users bidirectionally.
- **Other classes are local-only by default** — no network traffic. Turn on the assignment panel to enable `RPCX` sync with other Aegis users.

---

## 🐛 Known Limitations

- **1.12 client limitation:** Can't *read* another player's remaining buff time. With SuperWoW, Aegis works around it by watching casts as they happen, so buffs others apply are timed too; without it, non-self timers count down from your own casts (PallyPower's approach)
- **Cast observation needs one sighting:** `UNIT_CASTEVENT` only reaches units the client can see, so a caster must come into range **once** before their casts register. After that the timer runs locally at any distance. Interrupt cooldowns sidestep this entirely — members broadcast their own
- **Durations come from the spell catalog,** not the wire. Every tracked raid buff is single-duration across ranks in vanilla, so this only bites if Turtle changes one
- **Interrupt cooldowns are vanilla defaults** and Turtle-unverified — a one-line edit in the `INTERRUPTS` table if any are wrong
- **Range detection:** Uses visibility checks, which are wider than buff range; out-of-range casts cancel cleanly

---

## 📚 References

- **CHANGELOG.md** — Version history, features per release, roadmap
- **docs/DESIGN_SYNC.md** — RPCX protocol specification (grammar, flows, permissions)
- **docs/DESIGN_ALLCLASSES.md** — Class module architecture and pattern
- **docs/OPTIONS_UI_SPEC.md** — Settings frame layout and options contract
- **CLAUDE.md** — Development brief (milestones, design decisions, verification workflow)

---

## 🙏 Credits

- **Aegis: RallyPower** by Subtilizer (Torchlite)
- **PallyPowerTW** by ivanovlk
- **Original PallyPower** by Hjorim, Sneakyfoot, Rake, Xerron, Azgaardian, Aznamir
- Spanish localization by Nuevemasnueve

---

## 📄 License

Inherits from PallyPower's original license terms. See in-game addon list for details.

---

**Questions? Bugs? Feature ideas?**  
Check the [CHANGELOG.md](CHANGELOG.md) for what's planned. File an issue or visit the Turtle WoW forums.
