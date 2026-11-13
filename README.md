# pob-atlas by R3DB3AT

A fork of [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding) (Path of Exile 1) that adds the 3.30 passive tree and an **atlas tree planner**.

Made by R3DB3AT. Twitch: [twitch.tv/R3DB3AT](https://www.twitch.tv/R3DB3AT)

### What it adds
* **Atlas tab**: the 3.30 atlas passive tree. Allocate and remove nodes (150 points), with the combined atlas modifiers listed in the side bar.
* **Search** with a golden ring around matching nodes.
* **Fill**: a panel that lists every node a search finds. Tick what you want, untick what you do not want, then press Fill Tree. Ticked nodes are added along the shortest paths, nearest first, and unticked nodes already in the tree are removed. "Trim paths when removing" also removes the travel nodes that only led to a removed node.
* **Named atlas trees** saved with the build, and official atlas tree link import and export.
* The **3.30 passive tree** (normal and ruthless), from GGG's preview export.

### How to run
Download the zip from Releases (or clone this repository), unzip it and run `runtime\Path{space}of{space}Building.exe`. It runs in Developer Mode and does not update itself, so it never turns back into the official Path of Building. Atlas trees inside build codes are only read by this version.

Licence: MIT, as the original (see [LICENSE.md](LICENSE.md)). All credit for Path of Building goes to its authors.

---

# Path of Building Community
## Welcome to Path of Building, an offline build planner for Path of Exile!

<p float="middle">
  <img alt="Tree tab" src="https://github.com/user-attachments/assets/0826b7ab-84ba-440f-be52-2f216f13e75c" width="48%" />
  <img alt="Items tab" src="https://github.com/user-attachments/assets/e5af1326-7e22-43d8-ab12-aa5500da611a" width="48%" />
</p>

### Features
* Comprehensive offence + defence calculations:
  * Calculate your skill DPS, damage over time, life/mana/ES totals and much more!
  * Can factor in auras, buffs, charges, curses, monster resistances and more, to estimate your effective DPS
  * Also calculates life/mana reservations
  * Shows a summary of character stats in the side bar, as well as a detailed calculations breakdown tab which can show you how the stats were derived
  * Supports all skills and support gems, and most passives and item modifiers
    * Throughout the program, supported modifiers will show in blue and unsupported ones in red
  * Full support for minions
  * Support for party play and support builds
* Passive skill tree planner:
  * Support for jewels including most radius/conversion and timeless jewels
  * Features alternate path tracing (mouse over a sequence of nodes while holding shift, then click to allocate them all)
  * Fully integrated with the offence/defence calculations; see exactly how each node will affect your character!
  * Can import PathOfExile.com and PoEPlanner.com passive tree links; links shortened with PoEURL.com also work
* Skill planner:
  * Add any number of main or supporting skills to your build
  * Supporting skills (auras, curses, buffs) can be toggled on and off
  * Automatically applies Socketed Gem modifiers from the item a skill is socketed into
  * Automatically applies support gems granted by items
* Item planner:
  * Add items from in game by copying and pasting them straight into the program!
  * Automatically adds quality to non-corrupted items
  * Search the trade site for the most impactful items
  * Fully integrated with the offence/defence calculations; see exactly how much of an upgrade a given item is!
  * Contains a searchable database of all uniques that are currently in game (and some that aren't yet!)
    * You can choose the modifier rolls when you add a unique to your build
    * Includes all league-specific items and legacy variants
  * Features an item crafting system:
    * You can select from any of the game's base item types
    * You can select prefix/suffix modifiers from lists
    * Custom modifiers can be added, with Master and Essence modifiers available
  * Also contains a database of rare item templates:
    * Allows you to create rare items for your build to approximate the gear you will be using
    * Choose which modifiers appear on each item, and the rolls for each modifier, to suit your needs
    * Has templates that should cover the majority of builds
* Other features:
  * You can import passive tree, items, and skills from existing characters
  * Share builds with other users by generating a share code
  * Automatic updating; most updates will only take a couple of seconds to apply

## Download
Head over to the [Releases](https://github.com/PathOfBuildingCommunity/PathOfBuilding/releases) page to download the install wizard or portable zip.

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Contribute
You can find instructions on how to contribute code and bug reports [here](CONTRIBUTING.md).

## Licence
[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md).
The licencing information is considered to be part of the documentation.
