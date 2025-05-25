## OpenMW Lua mod — best-practice crib-sheet

*(Hand this to the junior so they don’t reinvent every wheel.)*

---

### 1. Repo & file layout

```
InteractableHighlight/
 ├─ omwscripts                # registers scripts + scope
 ├─ scripts/
 │   ├─ init.lua              # GLOBAL – hotkeys, storage
 │   ├─ player.lua            # PLAYER – scans + HUD
 │   ├─ settings.lua          # MENU  – config UI
 │   └─ util/ or lib/ …       # helpers, shared code
 ├─ README.md                 # feature list, install, FAQ
 ├─ LICENSE                   # MIT / GPL-3 (match engine)
 └─ CHANGELOG.md              # versioned, semver
```

*Mirror PCP-OpenMW and NCGDMW-Lua: clear scopes, one concern per script.*

**`.omwscripts`** example:

```
GLOBAL: scripts/InteractableHighlight/init.lua
PLAYER: scripts/InteractableHighlight/player.lua
MENU:   scripts/InteractableHighlight/settings.lua
```

OpenMW loads only what it needs; you avoid accidental heavy logic in menu context.

---

### 2. Core engine modules to know

| Module           | Why you care                                                                                                                     |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `openmw.world`   | get the player, send events globally                                                                                             |
| `openmw.nearby`  | C++-side lists: `items`, `actors`, `containers`, `doors` – already filtered to loaded cells; use these, **never** brute-scan.    |
| `openmw.types`   | class helpers (`types.Weapon`, `.NPC`, etc.) for subtype checks                                                                  |
| `openmw.storage` | persistent config: `globalSection` for mod-wide, `playerSection` if you ever need per-save. Use `:subscribe()` for live updates. |
| `openmw.ui`      | build HUD/menu widgets; `ui.registerSettingsPage` is the MCM equivalent.                                                         |
| `openmw.input`   | key events with modifier flags                                                                                                   |
| `openmw.async`   | throttle / debounce, storage subscriptions                                                                                       |

---

### 3. Event-driven architecture

*Steal Mercy CAO’s pattern:*

* **Global dispatcher** handles **input** → sends `ShowHighlights` / `HideHighlights` events.
* **Local player script** does the heavy work only when asked.
* Keep zero global mutable state; pass everything via events.
  This isolates performance-sensitive code and avoids race conditions when multiple players exist (multiplayer future-proofing).

---

### 4. Performance rules of thumb

1. **No polling when idle.** Scan only on hotkey press; remove labels on release/toggle.
2. **Stay inside loaded cells.** `nearby.*` already handles that – radius filter is just an extra prune.
3. **Throttle per-frame UI updates.** `onUpdate` every frame is fine **only** for a short list; if labels > 100, update every 0.05 s instead (`accumDT`).
4. **Destroy UI nodes.** Leak = stutter. Always `label:destroy()` when object invalid/out of range.
5. **Guard expensive math.** `worldToScreen` projection: early-out if object behind camera to skip trig.

Quick\_Action shows a clean HUD widget that obeys all of the above – copy its `onUpdate` logic.

---

### 5. Config UI (MCM replacement)

* Use `ui.registerSettingsPage` once in a **MENU** script.
* Build widgets declaratively (`TYPE.List`, `TYPE.Slider`, `TYPE.CheckBox`).
* On change → write to `storage.globalSection(...)`; the global script is **subscribed** and sees live updates.
* Provide sane defaults on first run: check `if not storage:get("profiles") then … end`.
* Keep UI code separate; no game logic inside menu script.

PCP’s `mcm.lua` is the gold standard: small, self-contained, stores defaults, shows tooltips.

---

### 6. Compatibility guarantees

*Why Tamriel Rebuilt “just works”:*

* You never hard-code form IDs; you rely on runtime `nearby.*` lists, which include any object from any plugin the engine loads.
* Filters key off `types.*`, which remain valid regardless of origin mod.
* Single namespace `InteractableHighlight` for storage/UI avoids key collisions with other Lua mods.
* Hotkeys: write a duplicate-check routine so two profiles can’t bind the same combo; reduce conflicts with other QoL mods.

---

### 7. Source-control hygiene

* Small commits, message > 50 chars, tag releases (`v1.0.0`).
* README: **engine version**, dependencies, keybindings, install path.
* MIT or GPL-3 (OpenMW engine is GPL-3; Lua mods can be MIT if you want easier reuse, PCP proves it).
* Provide sample `.cfg` snippet for enabling the mod.
* Add a tiny script in `/tools/format.lua` if you want auto-luacheck or stylua.

NCGDMW and PCP both keep immaculate CHANGELOGs—emulate.

---

### 8. Debug & telemetry

* Simple `logger.lua` wrapper (`if DEBUG then mwscript.log(...) end`).
* Toggle via `storage.globalSection('IH_Settings'):get('debug')`.
* Use `async.runAfter(0, fn)` for deferred prints so they don’t spam the main thread.

---

### 9. Testing checklist

* **Vanilla install** (no mods) → verify no errors in openmw\.log.
* **Heavy modlist** (TR + OAAB + big cities) → stress test radius = 4000, all filters on. FPS drop < 5 %.
* **Edge cases:** pick up an item with highlight active → label disappears; change resolution mid-game → labels reposition; save/load while toggle active → highlight resets gracefully.
* **Controller sanity:** even though we don’t bind gamepad, make sure the mod doesn’t crash if user has one.

---

### 10. Code style mini-guide

```lua
-- Always explicit
local types = require('openmw.types')

if obj.type == types.Weapon and filters.weapons then
    -- ...
end

-- Never rely on recordId strings for logic.
-- Use engine helpers: types.NPC:isInstance(obj)
```

* 4-space indent, no tabs.
* Top-file `local` requires.
* Return a table with `engineHandlers` / `eventHandlers` at bottom.

---

### 11. Libs worth vendoring

* **Lua Helper Utility** (Nexus ID 54629) – vec math, color, clamp; MIT.
* **btree.lua** (if you ever need behavior-trees) – Mercy CAO shows integration pattern.

---

### 12. When to break these rules

* Need cross-cell scans? Switch to coroutine + `util.vector3` chunking so you don’t block.
* Need massive UI overlays? Consider a dedicated `Interface` context rather than HUD layer to avoid scaling bugs.
* Multiplayer (tes3mp branch) will change scope logic—plan to gate global state behind `world.mwscript.isServer`.

---

### TL;DR for the junior

1. **Clone** the five reference repos and read their `init.lua` first.
2. Copy their structure; rip their helpers.
3. Keep heavy logic in player script; activate via events.
4. Persist everything in `storage.globalSection`.
5. Use OpenMW’s UI API, not MyGUI xml.
6. Ship a clean README and versioned releases.

Follow this and you’ll ship a modern, performant OpenMW Lua mod that plays nicely with any modlist.
