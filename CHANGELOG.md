## Unreleased

- Added Russian UI localization with an automatic/client-language default and an
  independent English/Russian interface selector in Settings > Advanced.
- Resource names and tooltip matching follow the client locale. Recorded points
  and selections retain their canonical keys; recognized client names are remembered.

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
