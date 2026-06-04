# Shop Favorites for Farming Simulator 25

Shop Favorites adds a Favorites tab to the in-game shop so players can save vehicles and tools with their selected configurations and buy them again quickly later.

## Features

- Add vehicles and tools to a favorites list directly from the shop configuration screen
- Save selected configurations with each favorite
- Open favorites from a dedicated shop tab
- Buy or lease favorites quickly
- Sort favorites by usage frequency
- Store favorites per player in multiplayer
- Support base-game and modded shop items

## Requirements

- Farming Simulator 25

## How It Works

### Add a favorite

1. Open the shop.
2. Select a vehicle or tool.
3. Open its configuration screen.
4. Use `Add to Favorites` or press `F`.

### Open a favorite

1. Open the shop.
2. Go to the Favorites tab.
3. Select a saved item.
4. Open it and buy or lease it with the saved configuration.

### Remove a favorite

1. Open the Favorites tab.
2. Select the item.
3. Use `Remove`.

## Multiplayer

- Favorites are stored per user.
- Clients can only buy from favorites if they have the correct farm permission.
- Favorite purchase and workshop reconfiguration are both supported in multiplayer.

## Saved Data

Favorites are saved in the `modSettings` folder and shared across saves for the same user.

If a favorite no longer exists in the current save because a source mod was removed, it is hidden instead of deleted.

## Controls

- Default key: `F`
- Action: add or remove the current shop item from favorites

## Important Notes

- Favorites are based on the shop item's XML file.
- Saved configurations can include options such as engine, wheels, colors, design choices, and similar shop configurations.
- The mod uses `ShopConfigScreen`, so multiplayer and workshop behavior should be regression-tested after code changes.

## Project Structure

- `src/FavoriteManager.lua`: favorite save/load logic and shop tab registration
- `src/gui/MenuFavoritesList.lua`: favorites tab UI
- `src/ShopConfigScreenExtension.lua`: shop screen hooks, favorite button, favorite purchase flow
- `src/ChangeVehicleConfigEventExtension.lua`: multiplayer/workshop safety and debug support
- `src/ShopFavoritesDebug.lua`: debug toggle and helper logs
- `AGENTS.md`: maintenance notes and test guidance for future work

## Debugging

Debug output can be enabled in:

- `src/ShopFavoritesDebug.lua`

Set:

```lua
ShopFavoritesDebug.enabled = true
```

Turn it back off for normal play:

```lua
ShopFavoritesDebug.enabled = false
```

## Installation

1. Download the mod ZIP.
2. Copy it to the Farming Simulator 25 `mods` folder.
3. Enable the mod in the game.
4. Load or start a save.

## Supported Languages

- English
- Italiano
- Deutsch
- Français
- Español
- Polski
- Русский

## Version

- Mod version: `1.0.0.0`
- `modDesc` version: `109`

## Author

Created by `NYKK3`.

## License

This mod is distributed under the MIT license. See [LICENSE](LICENSE) for details.
