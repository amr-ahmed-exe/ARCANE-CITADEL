--!strict
-- Arcane Citadel: single server entry point.
-- DataService -> WorldBuilder -> GameService (remotes + heartbeat)
-- -> MonetizationService (receipts + passes).

local WorldBuilder = require(script.Parent.Services.WorldBuilder)
local DataService = require(script.Parent.Services.DataService)
local GameService = require(script.Parent.Services.GameService)
local MonetizationService = require(script.Parent.Services.MonetizationService)

DataService.Init()
WorldBuilder.Build()
GameService.Init()
MonetizationService.Init()

print("[ArcaneCitadel] Server runtime online.")
