-- Executed in Studio Play Mode to verify server listeners reject malformed exploit payloads
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MALFORMED_PAYLOADS: { any } = {
	nil,
	0 / 0, -- NaN
	math.huge,
	-math.huge,
	-9999999,
	"DROP TABLE Players;",
	true,
	{ WallIndex = 0 / 0, Amount = -500000, ItemUID = 12345, CatalogKey = {} },
	{ WallIndex = 999, Currency = "InvalidCurrency", SpellSlot = "INVALID" },
}

local fuzzedCount = 0
for _, desc in ReplicatedStorage:GetDescendants() do
	if desc:IsA("RemoteEvent") then
		for _, badPayload in MALFORMED_PAYLOADS do
			fuzzedCount += 1
			pcall(function()
				desc:FireServer(badPayload)
			end)
		end
	end
end

print(string.format("[EXPLOIT FUZZER COMPLETE] Fired %d malformed payloads across all RemoteEvents.", fuzzedCount))
