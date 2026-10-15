--!strict
-- Arcane Citadel Studio SDK: rate-limited client<->server remote bus.
-- Token-bucket: 15 requests/sec per player (blueprint Milestone 1).

local NetworkRouter = {}

export type RouteHandler = (player: Player, ...any) -> ...any

local routes: { [string]: RemoteEvent | RemoteFunction } = {}
local buckets: { [number]: { tokens: number, lastRefill: number } } = {}

local MAX_TOKENS = 15
local REFILL_PER_SECOND = 15

local function getBucket(userId: number)
	local now = os.clock()
	local bucket = buckets[userId]
	if not bucket then
		bucket = { tokens = MAX_TOKENS, lastRefill = now }
		buckets[userId] = bucket
	end
	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(MAX_TOKENS, bucket.tokens + elapsed * REFILL_PER_SECOND)
	bucket.lastRefill = now
	return bucket
end

-- Server side: register a RemoteEvent route with server handler.
function NetworkRouter.RegisterEvent(name: string, handler: (player: Player, ...any) -> ()): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	routes[name] = remote
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local bucket = getBucket(player.UserId)
		if bucket.tokens < 1 then
			warn(`[NetworkRouter] Rate limited {player.Name} on {name}`)
			return
		end
		bucket.tokens -= 1
		handler(player, ...)
	end)
	return remote
end

-- Server side: register a RemoteFunction route with server callback.
function NetworkRouter.RegisterFunction(name: string, callback: (player: Player, ...any) -> ...any): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	routes[name] = remote
	remote.OnServerInvoke = function(player: Player, ...: any)
		local bucket = getBucket(player.UserId)
		if bucket.tokens < 1 then
			warn(`[NetworkRouter] Rate limited {player.Name} on {name}`)
			return nil
		end
		bucket.tokens -= 1
		return callback(player, ...)
	end
	return remote
end

-- Client side: fetch a shared remote (waits for replication).
function NetworkRouter.WaitForRemote(name: string, timeout: number?): Instance
	local folder = script.Parent.Parent:WaitForChild("Remotes", timeout or 10)
	return folder:WaitForChild(name, timeout or 10)
end

return NetworkRouter
