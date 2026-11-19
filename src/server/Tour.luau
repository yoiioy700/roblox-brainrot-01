-- Warung Kopi Brainrot: the tour hooks for make.fun's reviewers.
-- TOUR.json calls these to bring the game to a screenshot: spawn a rare
-- brainrot on the conveyor, and start the flood now. They only exist so a
-- reviewer can see the game's best screens; the game never calls them.

local GameServer = require(script.Parent:WaitForChild("GameServer"))

local Tour = {}

-- spawnRare puts a golden Legendary on the belt for the camera.
function Tour.spawnRare()
	GameServer.debugSpawn("komodo_disco")
end

-- startWaveNow begins the flood warning at once.
function Tour.startWaveNow()
	GameServer.debugStartWave()
end

return Tour
