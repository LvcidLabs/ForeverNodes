"""Compare the nodes recorded in game with the addon's bundled list, and optionally
merge them in permanently.

Reads every account's saved Forever Nodes settings (WTF\\Account\\*\\SavedVariables\\
ForeverNodes.lua), takes the spots recorded there (fishing pools, herbs and ore),
and checks each against Data.lua, the list the addon ships with:

  python merge_recorded.py           report only: what is new, nothing is changed
  python merge_recorded.py --apply   also write the new spots and node types into
                                     Data.lua (the old file is kept as Data.lua.bak)

Run it from anywhere; it finds the game folder from its own location
(Interface\\AddOns\\ForeverNodes\\Tools). Files other players send you (their
ForeverNodes.lua, renamed to anything ending in .lua) go in Tools\\Records and are read
too. The game must be closed or reloaded first,
since it only writes saved settings on /reload or logout.

Recorded spots stay in the saved settings after a merge; the addon skips any that
are already in the list, so nothing shows twice.
"""
import glob
import os
import re
import shutil
import sys

MERGE = 0.004  # map fraction: closer than this to a listed spot is the same node (as in game)
ICONS = {"fish": "Fish\\\\Fishhook", "herb": "Herb\\\\peacebloom", "ore": "Ore\\\\copper"}

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
GAME = os.path.abspath(os.path.join(ADDON, "..", "..", ".."))
DATA = os.path.join(ADDON, "Data.lua")
RECORDS = os.path.join(HERE, "Records")


# --- A small reader for the Lua tables the game saves --------------------------------

class LuaReader:
    TOKEN = re.compile(r'\s*(?:(--[^\n]*)|("(?:\\.|[^"\\])*")|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)'
                       r'|(\{|\}|\[|\]|=|,|;)|([A-Za-z_]\w*))')

    def __init__(self, text):
        self.tokens = []
        pos = 0
        while pos < len(text):
            m = self.TOKEN.match(text, pos)
            if not m or m.end() == pos:
                if text[pos:].strip() == "":
                    break
                raise ValueError("cannot read saved settings near: " + text[pos:pos + 40])
            pos = m.end()
            if m.group(1):
                continue
            if m.group(2):
                self.tokens.append(("str", bytes(m.group(2)[1:-1], "utf-8").decode("unicode_escape")))
            elif m.group(3):
                self.tokens.append(("num", float(m.group(3))))
            elif m.group(4):
                self.tokens.append(("sym", m.group(4)))
            else:
                self.tokens.append(("name", m.group(5)))
        self.i = 0

    def peek(self):
        return self.tokens[self.i] if self.i < len(self.tokens) else (None, None)

    def take(self):
        tok = self.tokens[self.i]
        self.i += 1
        return tok

    def value(self):
        kind, val = self.take()
        if kind in ("str", "num"):
            return val
        if kind == "name":
            return {"true": True, "false": False, "nil": None}.get(val, val)
        if val == "{":
            return self.table()
        raise ValueError("unexpected " + str(val))

    def table(self):
        result, n = {}, 1
        while self.peek() != ("sym", "}"):
            if self.peek() == ("sym", "["):
                self.take()
                key = self.value()
                self.take()  # ]
                self.take()  # =
                result[key] = self.value()
            elif self.peek()[0] == "name" and self.tokens[self.i + 1] == ("sym", "="):
                key = self.take()[1]
                self.take()
                result[key] = self.value()
            else:
                result[n] = self.value()
                n += 1
            if self.peek() in (("sym", ","), ("sym", ";")):
                self.take()
        self.take()  # }
        return result


def read_saved(path):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"ForeverNodesDB\s*=\s*", text)
    if not m:
        return {}
    reader = LuaReader(text[m.end():])
    return reader.value()


def flat_list(table):
    """A Lua array table ({[1]=..., [2]=...}) as a Python list."""
    return [table[k] for k in sorted(k for k in table if isinstance(k, float) or isinstance(k, int))]


# --- The bundled list (Data.lua) -----------------------------------------------------

def read_data():
    lines = open(DATA, encoding="utf-8").read().split("\n")
    nodes, points = {}, {}
    current = None
    for line in lines:
        m = re.match(r'\s*\{ key = "(\w+)", kind = "(\w+)", name = "((?:\\.|[^"\\])*)"', line)
        if m:
            nodes[m.group(1)] = {"kind": m.group(2), "name": m.group(3)}
            continue
        m = re.match(r"^    (\w+) = \{$", line)
        if m:
            current = m.group(1)
            points[current] = {}
            continue
        m = re.match(r"^        \[(\d+)\]=\{([^}]*)\},$", line)
        if m and current:
            nums = [float(v) for v in m.group(2).split(",") if v.strip()]
            points[current][int(m.group(1))] = list(zip(nums[0::2], nums[1::2]))
    return lines, nodes, points


def near(spots, x, y):
    return any(abs(sx - x) < MERGE and abs(sy - y) < MERGE for sx, sy in spots)


def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".")


def main():
    apply = "--apply" in sys.argv
    lines, nodes, points = read_data()

    saved_files = glob.glob(os.path.join(GAME, "WTF", "Account", "*", "SavedVariables", "ForeverNodes.lua"))
    # Other players' files: drop their ForeverNodes.lua (any name ending in .lua) into Tools\Records
    saved_files += sorted(glob.glob(os.path.join(RECORDS, "*.lua")))
    if not saved_files:
        print("No saved Forever Nodes settings found under", os.path.join(GAME, "WTF"), "or", RECORDS)
        return

    new_types = {}   # key -> {kind, name}
    new_spots = {}   # key -> {mapID: [(x, y)]}
    recorded_total = 0
    for path in saved_files:
        db = read_saved(path)
        for key, info in (db.get("recordedNodes") or {}).items():
            if key not in nodes and isinstance(info, dict):
                new_types[key] = {"kind": info.get("kind") or "fish", "name": info.get("name") or key}
        for key, maps in (db.get("recordedPoints") or {}).items():
            for map_id, flat in maps.items():
                nums = flat_list(flat)
                for x, y in zip(nums[0::2], nums[1::2]):
                    recorded_total += 1
                    listed = points.get(key, {}).get(int(map_id), [])
                    added = new_spots.setdefault(key, {}).setdefault(int(map_id), [])
                    if not near(listed, x, y) and not near(added, x, y):
                        added.append((x, y))

    names = {k: v["name"] for k, v in nodes.items()}
    names.update({k: v["name"] for k, v in new_types.items()})
    count = sum(len(s) for maps in new_spots.values() for s in maps.values())
    print("Saved settings read: %d file(s), %d recorded spot(s)." % (len(saved_files), recorded_total))
    print("Not yet in the bundled list: %d spot(s), %d new node type(s)." % (count, len(new_types)))
    for key, maps in sorted(new_spots.items()):
        spots = [(m, s) for m, ss in maps.items() for s in ss]
        if spots:
            where = ", ".join("map %d at %s, %s" % (m, fmt(x * 100), fmt(y * 100)) for m, (x, y) in spots)
            print("  %s: %d new - %s" % (names.get(key, key), len(spots), where))
    for key, info in sorted(new_types.items()):
        print("  new type: %s (%s)" % (info["name"], info["kind"]))

    if not apply:
        if count or new_types:
            print("\nNothing was changed. Run with --apply to add these to Data.lua.")
        return
    if not (count or new_types):
        print("\nNothing to add.")
        return

    # New node types go at the end of FN.nodes; new spots join their node's map lines.
    out = []
    in_nodes, current, maps_done = False, None, set()
    for line in lines:
        if line.startswith("FN.nodes = {"):
            in_nodes = True
        elif in_nodes and line == "}":
            for key, info in sorted(new_types.items()):
                out.append('    { key = "%s", kind = "%s", name = "%s", icon = "%s", skill = 0 },'
                           % (key, info["kind"], info["name"].replace('"', '\\"'), ICONS.get(info["kind"], ICONS["fish"])))
            in_nodes = False
        m = re.match(r"^    (\w+) = \{$", line)
        if m:
            current = m.group(1)
        m = re.match(r"^        \[(\d+)\]=\{([^}]*)\},$", line)
        if m and current in new_spots and int(m.group(1)) in new_spots[current]:
            extra = new_spots[current][int(m.group(1))]
            maps_done.add((current, int(m.group(1))))
            if extra:
                body = m.group(2) + "," + ",".join("%s,%s" % (fmt(x), fmt(y)) for x, y in extra)
                line = "        [%s]={%s}," % (m.group(1), body)
        if line == "    }," and current in new_spots:
            for map_id, extra in sorted(new_spots[current].items()):
                if (current, map_id) not in maps_done and extra:
                    out.append("        [%d]={%s}," % (map_id, ",".join("%s,%s" % (fmt(x), fmt(y)) for x, y in extra)))
                    maps_done.add((current, map_id))
        if line == "}" and not in_nodes and current is not None:
            # end of FN.points: whole blocks for nodes the list had no spots for at all
            for key, maps in sorted(new_spots.items()):
                if key not in points:
                    rows = ["        [%d]={%s}," % (m, ",".join("%s,%s" % (fmt(x), fmt(y)) for x, y in s))
                            for m, s in sorted(maps.items()) if s]
                    if rows:
                        out.append("    %s = {" % key)
                        out.extend(rows)
                        out.append("    },")
            current = None
        out.append(line)

    shutil.copyfile(DATA, DATA + ".bak")
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("\nData.lua updated (previous version saved as Data.lua.bak). /reload in game to use it.")


if __name__ == "__main__":
    main()
