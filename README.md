# WeakAuras Simple Remastered (3.3.5a)

A simplified WeakAuras for the **Grimfall** private server (WoW 3.3.5a), made for the
**Conquest of Azeroth** realm (custom classes, backported races) and the **classless** realm.

WeakAuras can show almost anything, but its editor has hundreds of settings and most of
them depend on the ten original classes, their specs and talents. This version keeps the
WeakAuras engine and replaces the class based parts and the long editor with a short,
guided setup that works for every class, race and build.

> This is a **modified version** of [WeakAuras WotLK](https://github.com/NoM0Re/WeakAuras-WotLK)
> (5.22.0, 3.3.5a backport by NoM0Re). It is not the official release.
> Please report problems with this version here, not to the original authors.

## What is different

**Made for Grimfall**
- No class, spec or talent load conditions (they break on custom classes and on the classless realm).
- **Per-character auras:** all auras are stored for the whole account, but a new aura only loads on the
  character that created it. One tick in the *When* tab extends it to other characters.
- **Manual role:** choose Tank / DPS / Healer per character (default DPS, with a reminder until you choose).
  If [Threat Plates (Grimfall edition)](https://github.com/Lidless/TidyPlates_ThreatPlates-3.3.5a-Remastered_Grimfall)
  is installed, the role is **kept in sync** with it in both directions.
- Custom class and race tokens are accepted everywhere.
- Old auras that used the class condition are moved to the characters of that class the first time
  each of them logs in.

**Simpler to use**
- **Quick Setup**, one page from top to bottom: *what to track → details → how it looks → where → when*.
  A block only becomes active when the one above is answered; changing an answer resets the blocks below.
- Categories: **Buff / Debuff**, **Proc** (a buff pops up, or an ability lights up), **Cooldown**,
  **Resource** (health, power, combo points).
- **Simple editor** with five short tabs: *Look, Trigger, Effects, Rules, When*.
- **Rules** instead of the condition editor: e.g. "less than 3 seconds left → red",
  "while on cooldown → grey", "below 35% → fade out".
- **Choose instead of typing:** every character quietly learns its own buffs, debuffs and procs
  (also the ones from Grimfall runes) and its own DoTs on the target. Pick them from a list with icons,
  together with the spellbook and usable items. Anything missing can be added by hand.
- **Automatic proc bar:** one bar that shows every proc as it pops up; new procs are added by themselves.
- **Shields:** show how much a shield can still absorb (the number from its tooltip) and fill a bar by it,
  as % of the shield's starting value.
- 10 ready colors, fade in / fade out by default, glow on procs by default.
- The full original editor is still there: tick **Advanced options** above the tabs.

## Installation

1. Download this repository (**Code → Download ZIP**).
2. Copy these folders into `World of Warcraft\Interface\AddOns\`:
   - `WeakAuras`
   - `WeakAurasOptions`
   - `WeakAurasArchive`
   - `WeakAurasModelPaths`
3. **Restart the game completely** (not just `/reload`): WoW only finds new addon files after a full restart.
4. If you had WeakAuras before, replace the old folders. Your auras are kept
   (they live in `WTF\...\SavedVariables\WeakAuras.lua`).
5. Optional: `WeakAurasTemplates` is not used by this version and can be deleted.
   `WeakAurasStopMotion` (an extra texture pack) is not included; you can take it from the original release if you need it.

## How to use

### Make an aura
1. Type `/wa`.
2. Click **New Aura → Quick Setup**.
3. Fill the page from top to bottom:
   1. **What should be tracked?** Buff / Debuff, Proc, Cooldown or Resource.
   2. **Details**: which buff, spell or item (the name is checked while you type), or which resource.
   3. **How should it look?** Icon, bar, text or circle; size, color, sound, glow.
   4. **Where should it be?** A starting position.
   5. **When should it be active?** Combat, group, role, characters, name.
4. Click **Create**, then drag the aura to its place with the mouse.

### Shields (e.g. Hateforged Barrier)
Grimfall shows the amount a shield can still absorb in its buff tooltip ("Absorbing 241 damage").
In the Quick Setup (Buff / Debuff or Proc, step 3) or later on the **Look** tab:
- **Show the number from its tooltip** writes that number on the icon / bar.
- **Fill it by that number (% of its starting value)** makes the bar empty out as the shield is used up;
  the moment the shield is put up counts as 100%.

Example for a Felsworn Tyrant: Buff / Debuff → A buff on me → Choose... → Hateforged Barrier → Bar → tick both.

### Automatic proc bar
**New Aura → Automatic proc bar** makes one bar (above your character) that shows all your procs while they are up,
each with its own icon, glowing. Every proc the addon learns is added to the bar by itself.
To leave one out: open **Choose...**, right click the proc → **Hide from the automatic proc bar**.
Each character has its own bar.

### Choose... (the list of your buffs, procs, spells and items)
Next to every name field there is a **Choose...** button. It opens a list with icons and a search box:

| Category | Where it comes from |
|---|---|
| **Procs** | short buffs on you that you did not cast yourself (procs, rune effects) |
| **My buffs** | buffs you cast on yourself |
| **Buffs from others** | buffs someone else put on you |
| **Passive / permanent** | buffs without a duration (e.g. Born Hero) |
| **Debuffs on me** | debuffs on you |
| **My debuffs / DoTs on target** | only the debuffs **you** put on your current target |
| **Spells with cooldown / Other spells** | your spellbook and your pet's (read when you open the list) |
| **Usable items** | trinkets, potions and other items with a "Use:" effect, in your bags or equipped |

- The aura lists fill up while you play: **a new character starts empty**, fight a little and use your abilities.
  Each character has its own list.
- Picked auras are matched by their **exact spell ID**, so two custom auras with the same name don't get mixed up.
- **Right click** an entry to move it to another category (if a proc was sorted wrong) or to remove it.
- **Not in the list?** Add it by hand at the bottom of the window (name or spell ID + category).

### Change an aura
Click it in the list on the left. The editor has five tabs:

| Tab | What you set there |
|---|---|
| **Look** | name, size, color, text colors, visibility, clock swipe and time numbers, glow, shield number, position |
| **Trigger** | what it watches (buff name, on whom, mine only, present or missing, stacks; spell or item; power type, % limit) |
| **Effects** | animation when it appears / while shown / when it disappears, sounds, chat message |
| **Rules** | ready made "if this, then that" rules: change color, grey out, fade out, fade in, glow |
| **When** | combat, group, instance type, mounted, vehicle, roles, characters |

Tick **Advanced options** (above the tabs) to see every original WeakAuras setting.

### Commands
| Command | |
|---|---|
| `/wa` | open the editor |
| `/wa role tank`, `/wa role dps`, `/wa role healer` | choose your role on this character (also: role button in the editor's top bar) |
| `/wa role` | show your current role |
| `/wa role sync on`, `/wa role sync off` | keep the role in sync with Threat Plates (on by default when it is installed) |
| `/wa minimap` | show / hide the minimap icon |
| `/wa help` | list of commands |

### Good to know
- A buff aura without a name would show **any** buff; the editor warns you in red if the name is empty.
- If you edit an aura's conditions in *Advanced options*, the *Rules* tab tells you before it would replace them.
- Import strings from other players still work; imported auras are bound to the character that imports them.

## Bugs and feedback

Please open an [issue](https://github.com/Lidless/WeakAuras-3.3.5a-Simple-Remastered/issues).

## Credits

- **WeakAuras** – the WeakAuras Team and contributors ([WeakAuras2](https://github.com/WeakAuras/WeakAuras2))
- **3.3.5a backport (WeakAuras WotLK)** – NoM0Re and contributors ([WeakAuras-WotLK](https://github.com/NoM0Re/WeakAuras-WotLK))
- All authors of the bundled libraries (Ace3, LibCompress, LibCustomGlow, LibDeflate, LibSerialize, LibGroupTalents and others)
- **Grimfall & Classless compatible by Lidless**

## License

GNU General Public License v2, see [LICENSE](LICENSE) and [NOTICE](NOTICE).
This is a modified version of WeakAuras WotLK; the original copyright and license notices are kept.
