# Plan to Finalize "TwentyTwentyObjects" Mod Functionality

## I. Overall Objective:
*   Ensure the "TwentyTwentyObjects" settings menu loads its full UI and is interactive.
*   Verify that data (profiles, settings) from `init.lua` correctly populates this menu via the event system.
*   Confirm that hotkeys trigger the highlighting functionality as intended.
*   Address any remaining bugs or visual/usability issues.

## II. Current Status & Key Understandings:

1.  **`init.lua` (GLOBAL Script):**
    *   Successfully refactored: Initialization now occurs at the top-level script execution.
    *   Correctly initializes `storage_module` and `logger_module`.
    *   Correctly loads profile data (or initializes defaults if storage is empty/cleared).
    *   Successfully sends a `PleaseRefreshSettingsEvent` using `types.Player.sendMenuEvent()` with the necessary data payload.
    *   `openmw.async` is confirmed to be available for use by `storage_module.subscribe`.

2.  **`settings_improved.lua` (MENU Script):**
    *   Its `onInit()` function correctly registers the settings page.
    *   A simplified test version successfully received the `PleaseRefreshSettingsEvent` and updated its UI, proving the event mechanism.
    *   The primary task is to restore the *full UI logic* and integrate it with this event mechanism.

3.  **Communication Breakdown & Solution:**
    *   The initial "interface not found" issue is resolved by using an event-based system instead of direct interface calls for initial menu population.

4.  **Remaining Modules:**
    *   `storage.lua`, `logger.lua`: Stable.
    *   `hotkeyListener.lua`: Awaiting successful profile setup by `init.lua`.
    *   `player_native.lua` & utils: Awaiting successful hotkey and event chain.

## III. Step-by-Step Action Plan:

1.  **Restore Full UI to `settings_improved.lua` & Integrate Event-Driven Refresh:**
    *   **Goal:** The settings menu should display its complete UI, populated by data from `init.lua`.
    *   **Action (Gemini):**
        1.  Start with the full, original code for `scripts/TwentyTwentyObjects/settings_improved.lua`.
        2.  **Add Diagnostic Prints:**
            *   Top: `print("[TTO DEBUG SETTINGS_IMPROVED] Script parsing started (Full UI).")`
            *   `onInit()` start: `print("[TTO DEBUG SETTINGS_IMPROVED] onInit() (Full UI) called.")`
            *   `onInit()` after `ui.registerSettingsPage`: `print("[TTO DEBUG SETTINGS_IMPROVED] Settings page registered (Full UI).")`
            *   Main `refresh(data)` start: `print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh(data) called (Full UI).")`
            *   Main `refresh(data)` end: `print("[TTO DEBUG SETTINGS_IMPROVED] ACTUAL refresh(data) completed (Full UI).")`
        3.  **Define `handlePleaseRefreshSettingsEvent`:**
            ```lua
            local function handlePleaseRefreshSettingsEvent(eventData)
                print("[TTO DEBUG SETTINGS_IMPROVED] Received PleaseRefreshSettingsEvent (Full UI target).")
                if eventData and eventData.dataToRefreshWith then
                    refresh(eventData.dataToRefreshWith) 
                else
                    print("[TTO DEBUG SETTINGS_IMPROVED] PleaseRefreshSettingsEvent (Full UI target) received no dataToRefreshWith.")
                    refresh(nil) 
                end
            end
            ```
        4.  **Modify Final `return` Statement:** Include `eventHandlers`:
            ```lua
            print("[TTO DEBUG SETTINGS_IMPROVED] Defining TTO_Menu interface and event handlers (Full UI)...")
            return {
                interfaceName = 'TTO_Menu', 
                interface = { refresh = refresh, refreshUI = exposed_refreshUI },
                engineHandlers = { onInit = onInit },
                eventHandlers = { PleaseRefreshSettingsEvent = handlePleaseRefreshSettingsEvent }
            }
            ```
        5.  **Ensure `refresh(data)` function:** Populates module-level variables (`profiles`, etc.) from `eventData.dataToRefreshWith`, initializes logger for the MENU context (`logger_module.init(generalSettings.debug)`), and calls `exposed_refreshUI()`.
    *   **User Verification:** Clear `global_storage.bin`. Run game, load save, open menu. Expect full UI. Provide `openmw.log`.

2.  **Implement Text Color/Visibility Improvements in Settings Menu:**
    *   **Goal:** Make settings menu text readable.
    *   **Action (Gemini):** Define and apply `DEFAULT_TEXT_COLOR` (Morrowind gold/yellow) and other color constants to text elements in `settings_improved.lua`.
    *   **User Verification:** Visually confirm readability.

3.  **Test Settings Menu Interactivity & Persistence:**
    *   **Goal:** Confirm settings changes work and persist.
    *   **Action (User):** Change settings, check persistence in UI, across menu close/reopen, and across game restart.
    *   **Action (Gemini):** Review save/load logic in scripts; analyze logs for errors.

4.  **Clean Up Storage Warnings (If Persistent):**
    *   **Goal:** Resolve `Profiles data in storage was not a table (type: userdata)` warning if it reappears.
    *   **Action (Gemini & User):** Analyze storage saving/loading if necessary. User ensures `global_storage.bin` was cleared.

5.  **Verify Hotkey Functionality:**
    *   **Goal:** Ensure hotkeys trigger highlighting.
    *   **Action (User):** Test hotkeys.
    *   **Action (Gemini):** Check logs for the full event chain from `hotkeyListener.lua` to `player_native.lua`.
    *   **User Verification:** Visual confirmation of highlights.

6.  **Comprehensive Feature Test & Iterative Debugging:**
    *   **Goal:** Test all mod features.
    *   **Action (User & Gemini):** Systematically test; debug issues in relevant modules.

## IV. Important Notes:
*   **`global_storage.bin`:** User should clear this before tests involving default profile creation or to ensure clean storage state.
*   **Persistence of `activeProfileName`:** Not currently implemented for persistence across game loads in `init.lua`. Can be a future enhancement (save to `globalSection`). 