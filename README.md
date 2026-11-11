# Potent scripts

Scripts for the Potassium executor. One file per game.

## Anime Adventures

Run it in the lobby or in a match:

```lua
loadstring(request({ Url = "https://raw.githubusercontent.com/InvisibleVIM/scripts/main/Anime%20Adventures", Method = "GET" }).Body, "=AnimeAdventures")()
```

Right Ctrl shows and hides the menu. The script reloads itself after every teleport.
Settings, logs and measured unit data are kept in the executor's `workspace/AnimeAdventures` folder.
The classic theme song (Music tab) is downloaded from `assets/classic_theme.mp3` the first time it is switched on.

## Branches

- `main`: the released scripts. The line above loads from here.
- `dev`: work in progress. Changes land here first and are merged into `main` when they are ready.
