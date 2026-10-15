--!strict
-- Arcane Citadel: cross-server raid browser backend (Milestone 4).
-- 30s MemoryStore advertisement, 15s cached reads, Phantom Citadel
-- AI fallbacks for off-peak matchmaking, TeleportService routing,
-- and the 90-second anti-combat-log hold.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")

local InvasionService = {}

local MAP_NAME = "ArcaneCitadel_Raids_v1"
local ADVERTISE_INTERVAL = 30
local ADVERTISE_TTL = 60
local READ_CACHE_TTL = 15

local readCache: { at: number, targets: { any } } = { at = 0, targets = {} }
local lastAdvertise = 0

local function map(): MemoryStoreSortedMap?
	local ok, result = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, MAP_NAME)
	if ok then
		return result
	end
	return nil
end

-- Called every heartbeat; publishes this server while its Blood Pact is open.
function InvasionService.Advertise(info: { pot: number, defenderRating: number, intactWalls: number, isPact: boolean }): ()
	if game.JobId == "" then
		return -- Studio has no JobId: nothing to advertise.
	end
	if not info.isPact then
		return
	end
	if os.clock() - lastAdvertise < ADVERTISE_INTERVAL then
		return
	end
	lastAdvertise = os.clock()
	local m = map()
	if not m then
		return
	end
	local payload = HttpService:JSONEncode({
		pot = math.floor(info.pot),
		dr = math.floor(info.defenderRating),
		walls = info.intactWalls,
	})
	-- Sort key = Session Pot (raiders hunt the fattest pots first).
	pcall(m.SetAsync, m, tostring(game.JobId), payload, ADVERTISE_TTL, info.pot)
end

function InvasionService.Unpublish(): ()
	if game.JobId == "" then
		return
	end
	local m = map()
	if m then
		pcall(m.RemoveAsync, m, tostring(game.JobId))
	end
end

local PHANTOMS = {
	{ name = "Cursed Lord Morghul", pot = 120000, dr = 9000, walls = 3 },
	{ name = "Cursed Lady Vexara", pot = 300000, dr = 22000, walls = 2 },
	{ name = "Cursed King Obsidian", pot = 750000, dr = 60000, walls = 3 },
}

-- Live targets + Phantom AI fallbacks (instant matchmaking at 3 AM).
function InvasionService.GetTargets(): { any }
	if os.clock() - readCache.at < READ_CACHE_TTL then
		return readCache.targets
	end
	local targets: { any } = {}
	local m = map()
	if m then
		local ok, pages = pcall(m.GetRangeAsync, m, Enum.SortDirection.Descending, 10)
		if ok and pages then
			for _, entry in pages do
				if tostring(entry.key) ~= tostring(game.JobId) then
					local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, entry.value)
					if decodeOk then
						table.insert(targets, {
							jobId = entry.key,
							name = `Citadel …{string.sub(tostring(entry.key), -4)}`,
							pot = data.pot or 0,
							dr = data.dr or 0,
							walls = data.walls or 0,
							phantom = false,
						})
					end
				end
			end
		end
	end
	-- Top up to 3 entries with Phantom Citadels.
	local pi = 1
	while #targets < 3 and pi <= #PHANTOMS do
		local p = PHANTOMS[pi]
		table.insert(targets, {
			jobId = `phantom-{pi}`,
			name = p.name .. " (AI)",
			pot = p.pot,
			dr = p.dr,
			walls = p.walls,
			phantom = true,
		})
		pi += 1
	end
	readCache = { at = os.clock(), targets = targets }
	return targets
end

-- Teleports a raider into a live target realm. Returns (ok, message).
function InvasionService.Invade(player: Player, jobId: string): (boolean, string)
	if typeof(jobId) ~= "string" or string.sub(jobId, 1, 8) == "phantom-" then
		return false, "Phantom Citadels are AI demos — invade a live realm."
	end
	if jobId == tostring(game.JobId) then
		return false, "That is your own Citadel."
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ role = "invader" })
	local ok, err = pcall(
		TeleportService.TeleportToPlaceInstance,
		TeleportService,
		game.PlaceId,
		jobId,
		{ player },
		nil,
		nil,
		options
	)
	if not ok then
		return false, `Teleport failed (publish the game first): {tostring(err)}`
	end
	return true, "Through the portal…"
end

-- Reads the invader flag stamped by TeleportOptions on arrival.
function InvasionService.JoinRole(player: Player): string
	local ok, joinData = pcall(player.GetJoinData, player)
	if ok and joinData and typeof(joinData.TeleportData) == "table" then
		local data: any = joinData.TeleportData
		if data.role == "invader" then
			return "invader"
		end
	end
	return "defender"
end

return InvasionService
