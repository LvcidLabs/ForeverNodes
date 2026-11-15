<p align="center"><img src="media/logo.png" alt="Forever Nodes" width="128"></p>

# Forever Nodes

Tired of alt-tabbing to Wowhead? Forever Nodes puts WoW: Forever's gathering nodes right on your map, and keeps an eye on your skill so you never farm 20 minutes past a rank cap.

<p align="center">
  <img src="https://github.com/user-attachments/assets/6e34b0ad-d207-44dc-8f59-da4199fc485a" alt="The Herbalism panel docked to the world map" width="100%">
</p>

<table align="center">
  <tr>
    <td align="center" valign="top" width="175">
      <img src="https://github.com/user-attachments/assets/858ad784-4bea-4696-a80f-8f6a979c541f" alt="The trainer list" width="155" height="240"><br>
      <sub>Closest and cheapest trainers, a click from a map pin.</sub>
    </td>
    <td align="center" valign="top" width="305">
      <img src="https://github.com/user-attachments/assets/85b2cdde-bf7d-4f43-836d-c24b1ef0a477" alt="The Forever Nodes button on the world map" width="288" height="240"><br>
      <sub>Right on your world map, next to the quest log.</sub>
    </td>
    <td align="center" valign="top" width="260">
      <img src="https://github.com/user-attachments/assets/158dfd14-cf13-4997-9f9c-9a69a5f03a3a" alt="Minimap with node icons and nearby dots" width="243" height="240"><br>
      <sub>Nearby nodes turn into a marker you design.</sub>
    </td>
  </tr>
</table>

<br>

## How to Install

- **CurseForge:** [Forever Nodes](https://www.curseforge.com/wow/addons/forever-nodes) or the CurseForge app.
- **Manually:** extract the [latest release](https://github.com/LvcidLabs/ForeverNodes/releases) into `World of Warcraft\_forever_\Interface\AddOns\`.

<br>

## Starting Out

There's nothing to set up. Most known herb, ore and fishing pool locations come preloaded, your professions are detected automatically, and the addon adapts to your setup on its own - stock UI or EllesmereUI, your minimap's shape & size, and map addons that rescale the world map.

**First launch:**

1. Open your world map and click the **Forever Nodes** button, just above the quest log button.
2. Pick a profession tab and tick the nodes you want to see.
3. That's it - they appear on your minimap and world map.

You can also type `/fn` to open it from anywhere.

<br>

## Features

- **Built into your world map** - the panel sits right where the quest log does, so everything is in one place: your node toggles, your skill and trainers, and all settings (gear tab, top-right). It can also be used as a floating window instead.
  - *Left-click* the map button - open the panel
  - *Right-click* the map button - show or hide the map icons
- **Know where you stand** - the panel keeps track of your profession, so you always know what to gather and when to train.
  - *Skill bar* - your current rank at a glance. It glows when you're ready to train.
  - *Rank lines* - the node list marks where your current rank tops out, so you can see what's worth gathering right now.
  - *Trainer finder* - click the skill bar for the closest & cheapest trainers for your next rank (reputation discounts included). Click a trainer to drop a map pin on them.
  - *Reminders* - a quick "Gz!" in chat when you cap a rank, and a gentle nudge if you forget to train.
- **Required skill on tooltips** - hover a node to see the skill it needs, colored by difficulty from grey (easy) to red (too high).
  - *Overworld* - herbs & veins in the world
  - *Minimap* - the game's own tracking dots (experimental)
  - *World map* - the addon's map icons (off by default)
- **A clearer minimap up close** - once a node is within 190 yds (the game's own tracking range), its icon steps aside for a small marker, so the game's tracking dot stays easy to read.
- **Grows as you play** - new spots you gather from are saved to your own copy. Recording is local only - nothing is ever sent anywhere.

<br>

## Quality of Life

- **Smart visibility** - herbs & ore only show while you're tracking them, and fishing pools only while you're holding a pole (both optional).
- **Per-character lists** - each character keeps its own ticked nodes, since alts are usually at different skill levels.
- **Never in the way** - minimap icons don't block the game's own tooltips.
- **Sorting** - by level or A-Z, with the nodes you can gather right now highlighted.
- **Capped professions** - at 300, difficulty colors step aside since everything is easy by then (optional).
- **Plan ahead** - browse professions you haven't learned yet (optional).
- **Game options** - settings are also available under Options > AddOns > Forever Nodes.

<br>

## Customization

- **Colors** - choose a color for each profession, used on the maps, the marker and the panel.
- **Icons** - size, and round or square, set separately for the minimap and world map.
- **Nearby marker** - build it from a dot, a circle and a border for each, all with their own color & size. A live preview shows exactly how it will look.
- **Tooltips** - the overworld, minimap and world map tooltips each have their own settings, with a live preview:
  - *Attach to* - the node's name, or the skill line (e.g. "[150] Herbalism")
  - *Placement* - before or after
  - *Style* - 150, (150), [150], or a separator (Name | 150)
  - *Color* - the level, the level & brackets, the name, the whole line, or none
  - *Text size* - for the world map tooltip
- **Panel** - docked to the map or floating, each with its own scale.
- **Minimap** - shape & icon edge can be fine-tuned in Advanced Minimap Settings, if auto-detection ever needs a hand.

<br>

## Feedback

Missing or misplaced node? [Open an issue](https://github.com/LvcidLabs/ForeverNodes/issues) with the zone and coordinates.

<br>

## Credits

- Inspired by **GatherMate2**.
- Node data and icons are based on **GatherLite** by Wuild (MIT).
- Uses HereBeDragons, LibStub, CallbackHandler, LibDataBroker and LibDBIcon. See [CREDITS.txt](CREDITS.txt).

<br>

## License

[MIT](LICENSE) © Lvcid. The bundled libraries in `Libs` keep their own licenses, and the node data and icons based on GatherLite keep its MIT notice (see [CREDITS.txt](CREDITS.txt)).
