-- Warung Kopi Brainrot: the server entry point.
-- One line starts the whole game: GameServer builds the world, the
-- remotes and every loop, then welcomes players as they join.

local GameServer = require(script:WaitForChild("GameServer"))

GameServer.start()
