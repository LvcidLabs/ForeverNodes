Forever Nodes - other players' recorded nodes
=============================================

Put recorded node files from other players in this folder, and the merge tool
will add their spots to the addon's bundled list along with yours.

Getting a file from someone
---------------------------
1. They type /reload in game, or log out. The game only saves their recorded
   spots to the file at those moments.
2. They send you this file from their game folder:

     World of Warcraft\_forever_\WTF\Account\<ACCOUNT NAME>\SavedVariables\ForeverNodes.lua

   It only holds Forever Nodes data (recorded spots and addon settings),
   no login details.

Merging it
----------
1. Put the file in this folder. Rename it to anything ending in .lua so several
   can sit side by side, for example bob.lua or guildmate.lua.
2. Double-click "Merge Recorded Nodes.bat" in the Tools folder.
3. /reload in game to see the new nodes.

The merge reads your own recorded spots plus every .lua file in this folder.
Spots that are already in the list are skipped, so merging the same file twice
does no harm. You can delete the files here once they're merged, or keep them.

The game ignores this folder; nothing in it is loaded in game.
