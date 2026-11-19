## Unreleased

- Added Russian UI localization with an automatic/client-language default and an
  independent English/Russian interface selector in Settings > Advanced.
- Resource names and tooltip matching follow the client locale. Recorded points
  and selections retain their canonical keys; recognized client names are remembered.

## 1.4.1

**Changes**

- You can drag the world map button whenever you like now, anywhere left of the quest log, including up in the zone menu row.
  - "Lock the world map button" in Settings > Advanced is now off by default, and just stops it from being dragged.
- Turning the panel off now brings the quest log back if your map normally opens with it, so you can tell which map mode you're in.
- With OpenMap installed, the world map button starts in the map's top right corner instead of hiding behind OpenMap's buttons.
- With OpenMap installed, the tutorial popup now waits until you've picked your OpenMap map style, so the two don't cover each other.

**Fixes**

- Fixed "Interface action failed because of an AddOn" when opening or closing the world map in combat with the panel in use.
- Fixed the same error showing up in combat after closing and reopening the panel, pinning a trainer, or opening the map with `/fn`.
  - A couple of small map setup steps (right-click on map icons, controller navigation in the quest log) now wait until combat ends instead.
- `/fn` in combat opens the floating window, since addons can't open the map mid-fight.
- Fixed the world map button's tooltip disappearing after clicking it.

## 1.4.0

**New**

- Added a quick tutorial that walks you through the panel. It shows once when you open your world map after updating, and `/fn help` brings it back anytime.
- Added a theme switcher. Forever Nodes still matches your UI automatically, but you can pick between the different colorways manually now (Native Brown or EUI Dark) in Settings > Advanced.
- You can now move the world map button anywhere on the map.
  - Untick "Lock the world map button" in Settings > Advanced, drag it where you like, and it locks again when you close the map.
  - Added a Reset position button, and an option to hide the button altogether.

**Changes**

- The panel now remembers whether it was open for each character, instead of across your whole account.
- New characters start with the panel closed and nothing ticked.
- Professions you haven't learned can always be opened, and now have a dimmed look with the same gold highlights as the others.
  - "Allow access to unlearned professions" is now "Allow tracking unlearned professions". It controls whether you can tick their nodes.
- Reorganized the Window settings into a new Advanced section.
  - The docked panel and floating window scales are now shown together, with a Reset scaling button.
- The skill bar no longer hides the level text after you click it, so you can watch big number get bigger. Move the mouse off the bar and back to see "View trainers" or "Hide trainers" again.
- Trainer sections for other continents now start unfolded, so a trainer or book that's far away is never hidden by accident.
- The fishing pole note is clickable now, and links straight to the setting that controls it.
- The login message now tells you more accurately how to open the panel.

**Fixes**

- Fixed "Hide trainers" looking dim when hovered.
- Fixed the "(doesn't affect tooltips)" note being cut off in the docked panel.
