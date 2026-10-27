# Changelog – WeakAuras Simple Remastered

Based on WeakAuras WotLK 5.22.0 (3.3.5a backport by NoM0Re, tag `5.22.0-39c2aca9`).
Grimfall & Classless compatible by Lidless.

## 0.2 – 2026-10-27

### Added
- **Learning list (per character):** buffs, debuffs and procs seen on the player (rune procs included)
  and the player's own debuffs / DoTs on the current target are noted automatically and sorted into
  Procs, My buffs, Buffs from others, Passive / permanent, Debuffs on me, My debuffs / DoTs on target.
- **Choose... window:** icons, search, categories; also the spellbook (with / without cooldown, pet spells)
  and items with a "Use:" effect. Right click: move to another category or remove. Manual add by name or spell ID.
- **Choose... buttons** in the Quick Setup and in the simple Trigger tab.
- Auras picked from the list are matched by **exact spell ID** (custom Grimfall auras can share names).

### Fixed
- The editor falls back to the original tabs if a new file was not loaded (new addon files only load after
  a full client restart); before this, deleting an aura could get stuck at "Deleting auras: 0/1".

## 0.1 – 2026-10-27

### Grimfall / classless
- Removed class, specialization, talent and spec position load conditions, spec filters,
  the "Talent Known" and "Class/Spec" triggers (old auras using them still work) and the class based templates.
- **Per-character auras:** account wide storage, new auras load only on the character that created them;
  imported auras are bound to the importing character. Old class based auras are moved to the matching characters.
- **Manual role** Tank / DPS / Healer per character (`/wa role`, toolbar button), default DPS with a reminder.
- Custom class and race tokens are accepted.

### Simpler use
- **Quick Setup:** one page, five blocks (what, details, how, where, when), each block opens after the one above;
  categories Buff / Debuff, Proc, Cooldown, Resource. Procs glow by default, every new aura fades in and out.
- The "Advanced" list of blank auras on the New Aura panel was removed (a blank buff aura shows any buff).
- **Simple editor** with five tabs: Look, Trigger, Effects, Rules, When. "Advanced options" brings back every original tab.
- **Rules** (ready made conditions): change color, grey out, fade out, fade in, glow.
- 10 preset colors.
- Footer reduced to **Credits** and **Found a Bug?** (this repository's issues).

## Planned
- Automatic auras: auto-proc bar, auto-cooldown bar, missing buff warning.
- "Combat & group" Quick Setup category (threat, cast bars, boss mod timers).
- Simple tabs for groups.
