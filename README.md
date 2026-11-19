# Warung Kopi Brainrot — roblox-brainrot-01

A 3D Roblox brainrot game for make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01), built
with Rojo from `src/` and `default.project.json`.

## The game

A warung street in 3D: absurd Indonesian meme characters walk a conveyor down the middle of the road while players
watch from their own warung plots. Click a brainrot on the conveyor to buy it; it moves to your plot and earns rupiah
per second at its own rate. Climb the rarity ladder — Common, Rare, Epic, Legendary, Mythic, Secret — and chase
mutations (Pedas, Es, Emas, Pelangi) that multiply income. Steal from other players' plots by carrying a brainrot home
— unless they lock their warung. Every three minutes the Banjir Bandang flood sweeps the street: the conveyor clears,
carried brainrots drop, and anyone caught in the street is pushed back to their warung. Earn enough lifetime rupiah to
rebirth and multiply all income.

The cast is original, invented for this game: Kopi Tubruk, Nasi Goreng Terbang, Kura-Kura Ojol, Ayam Geprek Sakti, Es
Teh Manis Raksasa, Becak Terbang, Kuntilanak Kopi, Komodo Disco, Garuda Emas, and the Secret Tukang Parkir Semesta.
Every character is built from plain parts in code — no uploaded assets.

## How it is built

- `src/shared/BrainrotConfig.luau` — the game's data: cast, rarities, mutations, economy, wave timing. One edit
  rebalances the game.
- `src/shared/FormatUtil.luau` — number formatting (K/M/B suffixes, rupiah) and save-data sanitizers.
- `src/server/WorldBuilder.luau` — builds the 3D world at server start: street, conveyor, six warung plots, spawn,
  buildings, trees, lamps, clouds.
- `src/server/BrainrotFactory.luau` — builds each brainrot character as a Model with its label and ClickDetector.
- `src/server/PlayerData.luau` — DataStore save/load: money, lifetime earnings, rebirths, owned brainrots.
- `src/server/GameServer.luau` — the server: sessions, plots, conveyor, money tick, buy/steal/lock/rebirth, the flood.
- `src/server/Tour.luau` — reviewer tour hooks (spawn a rare brainrot, start the flood).
- `src/client/Game.client.luau` — the HUD: money, income, flood timer, lock and rebirth buttons, collection, banners.
- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and
  `PLAY.json` to `/output`, leaving out every name that starts with a dot, and writes `/output/dossier.json` with
  `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is the place Rojo builds from `src/` and `default.project.json`; `PLAY.json` names the published place
  once the starter place is published from Roblox Studio.

## Build and check

    ~/workspace/dev-tools/rojo/rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

One of the screenshots must also be the game's first thumbnail on Roblox: the same picture, uploaded on the Creator
Dashboard with the game's icon. `TOUR.json` names, for each screenshot, the keys and the tour function that bring the
game to that screen.

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt.
