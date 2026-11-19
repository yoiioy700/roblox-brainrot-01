-- Warung Kopi Brainrot: builds the 3D world when the server starts.
-- The world is a warung street: a grass field, a road, a conveyor running
-- down the middle, six player plots (warung stalls) facing it, a spawn pad,
-- and buildings, trees and lamps around the edge. Everything is built from
-- the data tables below, so the layout is one edit, not a hundred clicks.
-- All parts are anchored; brainrots move by CFrame, never by physics.

local BrainrotConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotConfig"))

local WorldBuilder = {}

local PLOT_COLORS = {
	Color3.fromRGB(220, 120, 60),
	Color3.fromRGB(60, 170, 200),
	Color3.fromRGB(120, 190, 90),
	Color3.fromRGB(200, 90, 120),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(150, 110, 220),
}

-- makePart sets every property first, then parents last, so the part
-- replicates once in its final state.
local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeLabel(parent: Instance, text: string, size: UDim2, textSize: number, textColor: Color3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = textColor
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0.6
	label.Parent = billboard
	return billboard
end

local function buildGround(world: Folder)
	makePart(world, "Grass", Vector3.new(220, 1, 170), Vector3.new(0, -0.5, 0), Color3.fromRGB(110, 190, 90), Enum.Material.Grass)
	makePart(world, "Road", Vector3.new(200, 0.4, 24), Vector3.new(0, 0.2, 0), Color3.fromRGB(70, 70, 78), Enum.Material.SmoothPlastic)
	for _, z in { -15, 15 } do
		makePart(world, "Sidewalk", Vector3.new(200, 0.6, 6), Vector3.new(0, 0.3, z), Color3.fromRGB(180, 175, 160), Enum.Material.Concrete)
	end
	-- Road dashes down the middle of the street.
	for x = -90, 90, 12 do
		makePart(world, "RoadDash", Vector3.new(6, 0.1, 1), Vector3.new(x, 0.45, 0), Color3.fromRGB(240, 220, 90), Enum.Material.SmoothPlastic)
	end
end

local function buildConveyor(world: Folder)
	local map = BrainrotConfig.MAP
	-- Six belt segments, with a rail on each side.
	for i = 0, 5 do
		local x = map.ConveyorStartX + 12 + i * 24
		makePart(world, "ConveyorBelt", Vector3.new(24, 0.5, 8), Vector3.new(x, 1.75, map.ConveyorZ), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	end
	for _, z in { -4.6, 4.6 } do
		makePart(world, "ConveyorRail", Vector3.new(144, 1, 0.8), Vector3.new(0, 2.5, map.ConveyorZ + z), Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	end
	-- Start arch with the game's name over the belt.
	local arch = makePart(world, "ConveyorArch", Vector3.new(2, 12, 12), Vector3.new(map.ConveyorStartX - 2, 6, map.ConveyorZ), Color3.fromRGB(200, 90, 40), Enum.Material.Wood)
	makeLabel(arch, "KONVEYOR BRAINROT", UDim2.fromOffset(220, 40), 24, Color3.fromRGB(255, 240, 200))
	-- End arch: where brainrots that nobody buys walk off.
	local endArch = makePart(world, "ConveyorEnd", Vector3.new(2, 10, 12), Vector3.new(map.ConveyorEndX + 2, 5, map.ConveyorZ), Color3.fromRGB(200, 90, 40), Enum.Material.Wood)
	makeLabel(endArch, "UJUNG KONVEYOR", UDim2.fromOffset(200, 36), 22, Color3.fromRGB(255, 240, 200))
end

-- buildPlots returns one entry per plot: its center, its color, the world
-- positions of its 8 pads, and its sign part (for the owner's name).
local function buildPlots(world: Folder): { [number]: { center: Vector3, color: Color3, pads: { Vector3 }, sign: Part } }
	local plots = {}
	for index, center in BrainrotConfig.MAP.PlotCenters do
		local color = PLOT_COLORS[index]
		local cx, cz = center.x, center.z
		makePart(world, "PlotPlatform" .. index, Vector3.new(26, 1, 22), Vector3.new(cx, 0.5, cz), color, Enum.Material.WoodPlanks)
		makePart(world, "PlotTrim" .. index, Vector3.new(26, 0.4, 22), Vector3.new(cx, 1.1, cz), Color3.fromRGB(255, 250, 230), Enum.Material.SmoothPlastic).CanCollide = false
		-- Four posts and a roof: every warung gets a stall.
		for _, dx in { -11, 11 } do
			for _, dz in { -9, 9 } do
				makePart(world, "StallPost", Vector3.new(1, 7, 1), Vector3.new(cx + dx, 4.5, cz + dz), Color3.fromRGB(120, 70, 30), Enum.Material.Wood)
			end
		end
		makePart(world, "StallRoof" .. index, Vector3.new(28, 0.8, 24), Vector3.new(cx, 8.4, cz), Color3.fromRGB(190, 60, 50), Enum.Material.SmoothPlastic)
		-- A sign post at the plot's conveyor-facing edge, named by its plot.
		local signZ = cz + (if cz > 0 then -12 else 12)
		local sign = makePart(world, "PlotSign" .. index, Vector3.new(10, 5, 0.6), Vector3.new(cx, 4, signZ), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
		makeLabel(sign, "WARUNG " .. index, UDim2.fromOffset(200, 40), 26, Color3.fromRGB(255, 255, 255))
		-- Eight pads: two rows of four. A brainrot owned on this plot stands
		-- on one pad; the pad's world position is what the server places it at.
		local pads = {}
		for row = 0, 1 do
			for col = 0, 3 do
				local px = cx - 9.75 + col * 6.5
				local pz = cz - 5.5 + row * 11
				local pad = makePart(world, "PlotPad", Vector3.new(4, 0.3, 4), Vector3.new(px, 1.45, pz), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
				pad.CanCollide = false
				table.insert(pads, Vector3.new(px, 1.6, pz))
			end
		end
		plots[index] = { center = Vector3.new(cx, 1, cz), color = color, pads = pads, sign = sign }
	end
	return plots
end

local function buildSpawn(world: Folder)
	local spawn = BrainrotConfig.MAP.SpawnPoint
	makePart(world, "SpawnPad", Vector3.new(12, 0.5, 12), Vector3.new(spawn.x, 0.25, spawn.z), Color3.fromRGB(90, 200, 110), Enum.Material.SmoothPlastic)
	local post = makePart(world, "SpawnSign", Vector3.new(1, 6, 1), Vector3.new(spawn.x, 3, spawn.z + 5), Color3.fromRGB(120, 70, 30), Enum.Material.Wood)
	makeLabel(post, "SPAWN", UDim2.fromOffset(140, 36), 24, Color3.fromRGB(255, 255, 255))
end

local function buildDecorations(world: Folder)
	-- Perimeter buildings: simple boxes with roofs, in warung colors.
	local buildings = {
		{ x = -80, z = 55, w = 24, h = 16, d = 14, color = Color3.fromRGB(210, 140, 80) },
		{ x = -30, z = 58, w = 20, h = 22, d = 14, color = Color3.fromRGB(90, 140, 200) },
		{ x = 20, z = 58, w = 26, h = 14, d = 14, color = Color3.fromRGB(200, 90, 90) },
		{ x = 70, z = 55, w = 22, h = 20, d = 14, color = Color3.fromRGB(140, 110, 180) },
		{ x = -80, z = -55, w = 22, h = 18, d = 14, color = Color3.fromRGB(100, 180, 120) },
		{ x = 30, z = -58, w = 26, h = 15, d = 14, color = Color3.fromRGB(230, 170, 60) },
		{ x = 80, z = -55, w = 20, h = 24, d = 14, color = Color3.fromRGB(180, 120, 90) },
	}
	for i, b in buildings do
		makePart(world, "Building" .. i, Vector3.new(b.w, b.h, b.d), Vector3.new(b.x, b.h / 2, b.z), b.color, Enum.Material.Concrete)
		makePart(world, "BuildingRoof" .. i, Vector3.new(b.w + 2, 1.5, b.d + 2), Vector3.new(b.x, b.h + 0.75, b.z), Color3.fromRGB(160, 50, 50), Enum.Material.SmoothPlastic)
	end
	-- Trees: trunk and a round crown.
	local trees = { { -60, 40 }, { -15, 42 }, { 55, 42 }, { 90, 35 }, { -60, -42 }, { -10, -44 }, { 60, -42 }, { 92, -30 } }
	for i, t in trees do
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk" .. i
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Size = Vector3.new(1.5, 6, 1.5)
		trunk.CFrame = CFrame.new(t[1], 3, t[2]) * CFrame.Angles(0, 0, math.rad(90))
		trunk.Color = Color3.fromRGB(120, 80, 40)
		trunk.Material = Enum.Material.Wood
		trunk.Anchored = true
		trunk.Parent = world
		local crown = Instance.new("Part")
		crown.Name = "TreeCrown" .. i
		crown.Shape = Enum.PartType.Ball
		crown.Size = Vector3.new(7, 7, 7)
		crown.Position = Vector3.new(t[1], 8, t[2])
		crown.Color = Color3.fromRGB(60, 160, 70)
		crown.Material = Enum.Material.SmoothPlastic
		crown.Anchored = true
		crown.Parent = world
	end
	-- Lamps along the street.
	for _, x in { -60, -20, 20, 60 } do
		for _, z in { -12, 12 } do
			local pole = Instance.new("Part")
			pole.Name = "LampPole"
			pole.Shape = Enum.PartType.Cylinder
			pole.Size = Vector3.new(0.6, 8, 0.6)
			pole.CFrame = CFrame.new(x, 4, z) * CFrame.Angles(0, 0, math.rad(90))
			pole.Color = Color3.fromRGB(50, 50, 55)
			pole.Material = Enum.Material.Metal
			pole.Anchored = true
			pole.Parent = world
			local bulb = Instance.new("Part")
			bulb.Name = "LampBulb"
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.new(2, 2, 2)
			bulb.Position = Vector3.new(x, 8.4, z)
			bulb.Color = Color3.fromRGB(255, 240, 160)
			bulb.Material = Enum.Material.Neon
			bulb.Anchored = true
			bulb.Parent = world
		end
	end
	-- Clouds drifting high above the warung.
	for i, c in { { -50, 45, -30 }, { 0, 55, 20 }, { 50, 48, -20 }, { -20, 60, 40 }, { 70, 52, 30 } } do
		local cloud = Instance.new("Part")
		cloud.Name = "Cloud" .. i
		cloud.Shape = Enum.PartType.Ball
		cloud.Size = Vector3.new(18, 7, 10)
		cloud.Position = Vector3.new(c[1], c[2], c[3])
		cloud.Color = Color3.fromRGB(255, 255, 255)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Parent = world
	end
end

-- buildWorld builds the whole map and returns the handles the server needs:
-- the plot table (pads and signs) and the conveyor's span.
function WorldBuilder.buildWorld(): { plots: { [number]: { center: Vector3, color: Color3, pads: { Vector3 }, sign: Part } } }
	local world = Instance.new("Folder")
	world.Name = "WarungWorld"
	world.Parent = game:GetService("Workspace")
	buildGround(world)
	buildConveyor(world)
	local plots = buildPlots(world)
	buildSpawn(world)
	buildDecorations(world)
	return { plots = plots }
end

return WorldBuilder
