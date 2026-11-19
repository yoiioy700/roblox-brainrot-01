-- Warung Kopi Brainrot: the game's single source of truth for data.
-- Every number the server and the client both need lives here, frozen,
-- so a balance change is one edit and both sides always agree.

local BrainrotConfig = {}

-- The map, in studs. The conveyor runs along X at Z = 0; six player plots
-- (three per side) face it from Z = +28 and Z = -28.
BrainrotConfig.MAP = {
	ConveyorStartX = -70,
	ConveyorEndX = 70,
	ConveyorZ = 0,
	ConveyorTopY = 2,
	ConveyorSpeed = 4, -- studs per second the brainrots walk
	SpawnInterval = 6, -- seconds between conveyor spawns
	MaxOnConveyor = 12,
	PlotCenters = {
		{ x = -44, z = 28 },
		{ x = 0, z = 28 },
		{ x = 44, z = 28 },
		{ x = -44, z = -28 },
		{ x = 0, z = -28 },
		{ x = 44, z = -28 },
	},
	PadsPerPlot = 8,
	SpawnPoint = { x = -88, y = 3, z = 0 },
}

-- Rarity ladder, cheapest first. Weight is the share of conveyor spawns.
BrainrotConfig.RARITIES = table.freeze({
	{ id = "Common", display = "Common", color = Color3.fromRGB(200, 200, 200), weight = 0.52 },
	{ id = "Rare", display = "Rare", color = Color3.fromRGB(80, 160, 255), weight = 0.26 },
	{ id = "Epic", display = "Epic", color = Color3.fromRGB(180, 90, 255), weight = 0.13 },
	{ id = "Legendary", display = "Legendary", color = Color3.fromRGB(255, 170, 40), weight = 0.06 },
	{ id = "Mythic", display = "Mythic", color = Color3.fromRGB(255, 70, 110), weight = 0.02 },
	{ id = "Secret", display = "Secret", color = Color3.fromRGB(60, 230, 220), weight = 0.01 },
})

-- Mutations roll on every conveyor spawn. Multiplier applies to income.
BrainrotConfig.MUTATIONS = table.freeze({
	{ id = "None", display = "", multiplier = 1, weight = 0.85, tint = nil },
	{ id = "Pedas", display = "Pedas", multiplier = 2, weight = 0.08, tint = Color3.fromRGB(255, 70, 40) },
	{ id = "Es", display = "Es", multiplier = 3, weight = 0.04, tint = Color3.fromRGB(140, 210, 255) },
	{ id = "Emas", display = "Emas", multiplier = 5, weight = 0.02, tint = Color3.fromRGB(255, 215, 60) },
	{ id = "Pelangi", display = "Pelangi", multiplier = 10, weight = 0.01, tint = Color3.fromRGB(255, 120, 220) },
})

-- The cast. Original characters, invented for this game: absurd Indonesian
-- street-food and street-life memes. Body is one of "Cup", "Plate",
-- "Turtle", "Chicken", "Glass", "Pedicab", "Ghost", "Lizard", "Bird",
-- "Guard"; the factory in BrainrotFactory knows how to build each body.
-- price is what a player pays on the conveyor; income is rupiah per second.
BrainrotConfig.CAST = table.freeze({
	{
		id = "kopi_tubruk",
		name = "Kopi Tubruk",
		rarity = "Common",
		price = 75,
		income = 6,
		body = "Cup",
		bodyColor = Color3.fromRGB(120, 72, 32),
		accentColor = Color3.fromRGB(60, 38, 18),
		scale = 1.0,
		blurb = "Kopi hitam pekat yang jalan sendiri.",
	},
	{
		id = "nasi_goreng",
		name = "Nasi Goreng Terbang",
		rarity = "Common",
		price = 120,
		income = 9,
		body = "Plate",
		bodyColor = Color3.fromRGB(230, 150, 50),
		accentColor = Color3.fromRGB(200, 90, 30),
		scale = 1.0,
		blurb = "Sepiring nasi goreng yang ogah dimakan.",
	},
	{
		id = "kura_ojol",
		name = "Kura-Kura Ojol",
		rarity = "Rare",
		price = 350,
		income = 28,
		body = "Turtle",
		bodyColor = Color3.fromRGB(70, 160, 80),
		accentColor = Color3.fromRGB(30, 120, 60),
		scale = 1.1,
		blurb = "Antar pesanan, pelan tapi pasti sampai.",
	},
	{
		id = "ayam_geprek",
		name = "Ayam Geprek Sakti",
		rarity = "Rare",
		price = 600,
		income = 45,
		body = "Chicken",
		bodyColor = Color3.fromRGB(240, 200, 90),
		accentColor = Color3.fromRGB(220, 60, 40),
		scale = 1.1,
		blurb = "Ayam geprek level dewa, sambalnya meledak.",
	},
	{
		id = "es_teh",
		name = "Es Teh Manis Raksasa",
		rarity = "Epic",
		price = 1800,
		income = 130,
		body = "Glass",
		bodyColor = Color3.fromRGB(200, 120, 40),
		accentColor = Color3.fromRGB(255, 240, 200),
		scale = 1.25,
		blurb = "Segelas es teh sebesar warungnya.",
	},
	{
		id = "becak_terbang",
		name = "Becak Terbang",
		rarity = "Epic",
		price = 3200,
		income = 220,
		body = "Pedicab",
		bodyColor = Color3.fromRGB(40, 180, 170),
		accentColor = Color3.fromRGB(255, 220, 80),
		scale = 1.3,
		blurb = "Becak tanpa pengemudi, terbang cari penumpang.",
	},
	{
		id = "kuntilanak_kopi",
		name = "Kuntilanak Kopi",
		rarity = "Legendary",
		price = 9000,
		income = 650,
		body = "Ghost",
		bodyColor = Color3.fromRGB(245, 245, 245),
		accentColor = Color3.fromRGB(90, 40, 90),
		scale = 1.4,
		blurb = "Hantu warung yang cuma muncul pas kopi habis.",
	},
	{
		id = "komodo_disco",
		name = "Komodo Disco",
		rarity = "Legendary",
		price = 16000,
		income = 1100,
		body = "Lizard",
		bodyColor = Color3.fromRGB(150, 80, 200),
		accentColor = Color3.fromRGB(255, 80, 180),
		scale = 1.5,
		blurb = "Komodo berdisko, ekornya lampu kelap-kelip.",
	},
	{
		id = "garuda_emas",
		name = "Garuda Emas",
		rarity = "Mythic",
		price = 55000,
		income = 4000,
		body = "Bird",
		bodyColor = Color3.fromRGB(255, 200, 40),
		accentColor = Color3.fromRGB(180, 120, 20),
		scale = 1.7,
		blurb = "Burung garuda berlapis emas, terbang di atas warung.",
	},
	{
		id = "tukang_parkir",
		name = "Tukang Parkir Semesta",
		rarity = "Secret",
		price = 160000,
		income = 15000,
		body = "Guard",
		bodyColor = Color3.fromRGB(255, 130, 30),
		accentColor = Color3.fromRGB(40, 40, 40),
		scale = 1.8,
		blurb = "Yang mengatur parkir seluruh alam semesta.",
	},
})

-- Economy: what a new player starts with, how rebirth scales, base defence.
BrainrotConfig.ECONOMY = table.freeze({
	StartMoney = 100,
	RebirthBaseRequirement = 25000, -- lifetime rupiah earned, before growth
	RebirthRequirementGrowth = 2.5, -- requirement x this per rebirth already done
	RebirthMultiplierPerCount = 1, -- income multiplier is 1 + rebirths
	LockDuration = 30, -- seconds a base lock lasts
	LockCooldown = 90, -- seconds before the lock can be used again
	StealCooldown = 5, -- seconds between one player's steal attempts
})

-- The threat: Banjir Bandang, the flash flood. It sweeps the street on a
-- timer, clears the conveyor, and drops anything a thief is carrying.
BrainrotConfig.WAVE = table.freeze({
	Period = 180, -- seconds between waves
	WarningSeconds = 15, -- countdown shown before the wave arrives
	SweepSeconds = 8, -- how long the wall takes to cross the map
	StreetHalfWidth = 12, -- |Z| inside this is the street the wave hits
})

-- How often the server saves, and the DataStore this game uses.
BrainrotConfig.SAVE = table.freeze({
	StoreName = "WarungKopiBrainrot_v1",
	AutosaveSeconds = 120,
})

return BrainrotConfig
