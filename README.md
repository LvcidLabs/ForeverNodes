<p align="center"><img src="media/logo.png" alt="Forever Nodes" width="128"></p>

# Forever Nodes

A modern, simple gathering panel for WoW: Forever that's part of your world map, with node toggles only a click away. Comes preloaded with most known herbalism, mining and fishing locations. Made exclusively for WoW: Forever and heavily inspired by GatherMate2.

<p align="center">
  <img src="https://github.com/user-attachments/assets/e91a1133-fe5d-4147-aa03-50926119ffa8" alt="The Herbalism panel docked to the world map" width="100%">
</p>

<table align="center">
  <tr>
    <td align="center" valign="top" width="270">
      <img src="https://github.com/user-attachments/assets/85b2cdde-bf7d-4f43-836d-c24b1ef0a477" alt="The Forever Nodes button on the world map" width="252" height="210"><br>
      <sub>Adds a button to your world map, shares space with quest log.</sub>
    </td>
    <td align="center" valign="top" width="230">
      <img src="https://github.com/user-attachments/assets/158dfd14-cf13-4997-9f9c-9a69a5f03a3a" alt="Minimap with node icons and markers" width="213" height="210"><br>
      <sub>Nearby nodes become customizable dots/circles (dots by default), just like Gatherer or GatherMate2.</sub>
    </td>
    <td align="center" valign="top" width="235">
      <img src="https://github.com/user-attachments/assets/07bc9690-1aa8-4c3c-91c8-38134fa8b392" alt="The Settings tab" width="217" height="210"><br>
      <sub>Easy to access settings right in the panel.</sub>
    </td>
  </tr>
</table>

## How to Install

**CurseForge:** install it from the [Forever Nodes CurseForge page](https://www.curseforge.com/wow/addons/forever-nodes) or the CurseForge app.

**Manually:** download the zip from the [releases page](https://github.com/LvcidLabs/ForeverNodes/releases) and extract it into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with `AddOns\ForeverNodes\ForeverNodes.toc`.

## Getting started

1. Open your world map.
2. Click the **Forever Nodes** button in the bottom-right corner (or use the minimap button, or type `/fn`).
3. Tick whichever nodes you want to track.

Herbs and ore start hidden and fishing pools start on. Professions your character doesn't have are greyed out; you can unlock them in Settings → Professions.

## Features

- **Preloaded node locations** for herbalism, mining and fishing pools across Azeroth, ready the moment you install. No additional data imports necessary
- **Docked to your world map:** the panel swaps places with the quest log in one click, or use it as a floating window if you prefer
- **Pick exactly what shows:** tick the herbs, veins and pools you want, sorted by skill level or name, with your own skill shown in difficulty colors
- **Clean minimap icons** that switch to a small colored marker once you're close enough for the game's own tracking to take over
- **Fishing pools only appear while a fishing pole is equipped**
- **Square and round minimaps** are detected automatically, with an adjustable draw range
- **Records new spots** you discover, so your map keeps growing as you play
- **Minimap button:** left click opens the panel, right click toggles world map icons
- **Fits your UI:** currently supports a native theme and an auto-detected EllesmereUI theme

## Quality of life

- **No tooltips on minimap icons:** they intentionally ignore the mouse, so hovering the minimap shows what's actually there (the real herb, vein or pool) instead of a map icon getting in the way
- **One-click icon toggle:** right click the world map button (or the minimap button) to hide or show map icons instantly, without opening anything
- **Uncluttered list:** nodes for professions you don't have are greyed out, so the ones you can gather stand out
- **Smart recording:** herbs and veins are never mistaken for fishing pools, even if you pick one right after casting, and spots you've already found aren't saved twice
- **Separate scales** for the docked and floating panel, so each can be sized to fit
- **Lightweight:** icons are reused rather than recreated, and only nodes near you are checked as you move, so it stays smooth even with every node type enabled

## Feedback

Found a node that's missing or in the wrong place? Open an [issue](https://github.com/LvcidLabs/ForeverNodes/issues) or leave a comment on CurseForge with the zone and coordinates.

## Credits

Node data and icons are based on GatherLite by Wuild (MIT). Inspired by GatherMate2. Uses HereBeDragons, LibStub, CallbackHandler, LibDataBroker and LibDBIcon. See [CREDITS.txt](CREDITS.txt).

## License

[MIT](LICENSE) © Lvcid. The bundled libraries in `Libs` keep their own licenses, and the node data and icons based on GatherLite keep its MIT notice (see [CREDITS.txt](CREDITS.txt)).
