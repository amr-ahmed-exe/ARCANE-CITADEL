--!strict
-- Arcane Citadel: single client entry point.
-- EconomyClient + combat + wraith visuals + HUD.
--
-- Note: the old UIController `UIActionButton` tag binder was removed. Every
-- screen is built from code by UITheme, so no instance was ever tagged and
-- the handler only ever printed — it just looked load-bearing.

local Players = game:GetService("Players")

local EconomyClient = require(script.Parent.Controllers.EconomyClient)
local CombatInputController = require(script.Parent.Controllers.CombatInputController)
local WraithVisualController = require(script.Parent.Controllers.WraithVisualController)
local CameraController = require(script.Parent.Controllers.CameraController)
local SoundController = require(script.Parent.Controllers.SoundController)
local TopEconomyHUD = require(script.Parent.UI.TopEconomyHUD)
local CitadelWallDrawer = require(script.Parent.UI.CitadelWallDrawer)
local BreachDecisionModal = require(script.Parent.UI.BreachDecisionModal)
local PlaytimeGiftGrid = require(script.Parent.UI.PlaytimeGiftGridModal)
local GrimoireAndAnvilModal = require(script.Parent.UI.GrimoireAndAnvilModal)
local GlobalRaidBrowser = require(script.Parent.UI.GlobalRaidBrowser)
local AuctionBoardModal = require(script.Parent.UI.AuctionBoardModal)
local InvaderHUD = require(script.Parent.UI.InvaderHUD)
local FifthDeathModal = require(script.Parent.UI.FifthDeathModal)
local SpellBar = require(script.Parent.UI.SpellBar)
local ShopModal = require(script.Parent.UI.ShopModal)
local NoticeBanner = require(script.Parent.UI.NoticeBanner)
local HelpPanel = require(script.Parent.UI.HelpPanel)

EconomyClient.Init()
CombatInputController.Init()
WraithVisualController.Init()
CameraController.Init()
SoundController.Init()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
TopEconomyHUD.Build(playerGui)
CitadelWallDrawer.Build(playerGui)
BreachDecisionModal.Build(playerGui)
PlaytimeGiftGrid.Build(playerGui)
GrimoireAndAnvilModal.Build(playerGui)
GlobalRaidBrowser.Build(playerGui)
AuctionBoardModal.Build(playerGui)
InvaderHUD.Build(playerGui)
FifthDeathModal.Build(playerGui)
SpellBar.Build(playerGui)
ShopModal.Build(playerGui)
NoticeBanner.Build(playerGui)
HelpPanel.Build(playerGui)

print("[ArcaneCitadel] Client runtime online.")
