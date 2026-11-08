# Changelog – WeakAuras Simple Remastered

Based on WeakAuras WotLK 5.22.0 (3.3.5a backport by NoM0Re, tag `5.22.0-39c2aca9`).
Grimfall & Classless compatible by Lidless.

## 0.6.6 – 2026-11-08

### Fixed
- **Auras follow new ranks.** A Grimfall buff gets a new spell ID when you learn a higher rank, and auras that
  match by exact spell ID stopped seeing it (a "missing" aura then showed although the buff was up).
  When the addon learns a new ID with the same name and icon, it is added to every aura that watches
  one of the old IDs. Different buffs that only share a name (different icon) are still kept apart.

## 0.6.5 – 2026-11-06

### Fixed
- **Grimfall charge spells** (e.g. Rylak's Bite): the game reports only the global cooldown for them;
  Grimfall draws the charge number and the recharge swipe directly on the action button.
  The addon now reads the button: its charge number becomes the aura's stacks, and the aura counts as
  "on cooldown" at 0 charges, with the time until the next charge. The spell must be on a visible action bar.
- `/wa cd` also shows the button's charge text and recharge swipe.

## 0.6.4 – 2026-11-06

### Fixed
- Cooldowns of **talent abilities and custom spells** did not show at all: `IsSpellKnown(id)` can say "no" when the
  spell you have is another rank / ID of the same name, and WeakAuras hides cooldowns of unknown spells.
  Now the spellbook is also searched by the spell's name.
- A cooldown or recharge of exactly 10 seconds was ignored (a workaround for retail Stealth/Prowl; Rylak's Bite has a 10 sec recharge).
- Spell cooldowns typed by name (older auras) also use the action button fallback from 0.6.3.

### Added
- `/wa cd <spell name or id>` prints what the game reports for a spell's cooldown, charges and action button.
  Please paste its output into bug reports about cooldowns.

## 0.6.3 – 2026-11-06

### Fixed
- **Spells with charges** (e.g. Rylak's Bite: 2 charges, 10 sec recharge). The 3.3.5 client has no charge API,
  so the spell's own cooldown can stay empty. If the spell is on an action bar, its cooldown and charge number
  are now read from the action button:
  - the charge number is shown as **stacks** (use it in the Rules tab or as text);
  - *Only while on cooldown* means **0 charges left**; while at least one charge is left, the spell counts as ready.
  The spell must be on one of your action bars for this to work.

## 0.6.2 – 2026-11-06

### Fixed
- Spell cooldowns made with the Quick Setup or the simple Trigger tab now watch the **exact spell ID**.
  Custom Grimfall spells often have several IDs (ranks) with the same name; matching by name could watch
  the wrong one, so no cooldown was shown (e.g. Rylak's Bite).

## 0.6.1 – 2026-11-06

### Changed
- Choose... window: a line above the list always explains where it comes from (learned since install /
  spellbook / bags); an empty learned list now tells clearly what to do.

## 0.6 – 2026-11-05

Checkpoint of the previous version: branch `checkpoint-0.5`.

### Added
- **My buff on group members** (Quick Setup → Buff / Debuff): one thin bar per player who has your buff,
  under the raid frames (HealBot, Blizzard, Grid... via LibGetFrame) or as a list with names.
  Stack number on the bar, drains with the time left, red in the last 5 seconds, optional color by stacks
  (grey / yellow / green) with a white frame at max stacks. Look tab: max stacks, color by stacks, bar height,
  "Match the raid frame width".
- Learning list: new category **My buffs on group members** (own buffs seen on party / raid members).

## 0.5 – 2026-10-29

### Added
- **Text colors on the Look tab** (icons and bars): main text (shield number / name / stacks) and second text
  (time left / stacks), with the same 10 preset colors.

## 0.4 – 2026-10-29

### Added
- **Shields / tooltip numbers:** show the first number of a buff's tooltip (e.g. "Absorbing 241 damage") on the aura,
  and fill a bar / circle by it as % of the value seen when the buff appeared (refresh = new 100%).
  Quick Setup step 3 and the Look tab. Available for advanced users as progress source
  "Tooltip 1 (% of starting value)" and as `%tooltip1Percent` / `%tooltip1Max` in texts.
- Bars with the shield number get a clean layout: number on the left, time left on the right, name hidden.

## 0.3 – 2026-10-27

### Added
- **Role sync with Threat Plates (Grimfall edition):** changing the role in either addon changes it in the other;
  at login a role chosen in Threat Plates wins. `/wa role sync on|off`. Only one "choose a role" reminder.
- **Automatic proc bar** (New Aura → Automatic proc bar): shows every learned proc, new procs are added by themselves;
  right click a proc in the Choose... list to hide it from the bar.

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
- Automatic cooldown bar and missing buff warning (if they turn out to be needed).
- "Combat & group" Quick Setup category (threat, cast bars, boss mod timers).
- Simple tabs for groups.
