-- Warung Kopi Brainrot: small number helpers both sides share.
-- Written from scratch for this game: suffix formatting, sanitizers for
-- loaded save data, and weighted picking for spawns and mutations.

local FormatUtil = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- formatNumber(1234) -> "1.2K". Rounds first, then picks the suffix, so
-- 999950 never prints as "1000.0K" but as "1.0M".
function FormatUtil.formatNumber(value: number, decimals: number?): string
	decimals = decimals or 1
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return "0"
	end
	if value < 0 then
		return "-" .. FormatUtil.formatNumber(-value, decimals)
	end
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log(value) / math.log(1000))
	if tier > #SUFFIXES then
		return string.format("%." .. tostring(decimals) .. "e", value)
	end
	local scaled = value / (1000 ^ tier)
	local factor = 10 ^ decimals
	scaled = math.floor(scaled * factor + 0.5) / factor
	if scaled >= 1000 then
		-- Rollover: the rounding pushed us into the next suffix.
		scaled = scaled / 1000
		tier += 1
		if tier > #SUFFIXES then
			return string.format("%." .. tostring(decimals) .. "e", value)
		end
	end
	return string.format("%." .. tostring(decimals) .. "f%s", scaled, SUFFIXES[tier])
end

-- formatRupiah(1234567) -> "Rp 1.2M". The HUD's money display.
function FormatUtil.formatRupiah(value: number): string
	return "Rp " .. FormatUtil.formatNumber(value, 1)
end

-- sanitizeAmount turns anything a save file might hold into a safe
-- non-negative whole number: bad types, NaN, infinity and negatives are 0.
function FormatUtil.sanitizeAmount(value: unknown): number
	if type(value) ~= "number" then
		return 0
	end
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return math.floor(value)
end

-- sanitizeCount clamps a whole-number count into 0..max.
function FormatUtil.sanitizeCount(value: unknown, max: number): number
	local amount = FormatUtil.sanitizeAmount(value)
	if amount > max then
		return max
	end
	return amount
end

-- pickWeighted(entries, rng) -> one entry. Each entry carries a `weight`
-- field; the weights need not sum to 1. Pure, so it is easy to test.
function FormatUtil.pickWeighted(entries: { [number]: { weight: number } }, rng: Random): { weight: number }
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

return FormatUtil
