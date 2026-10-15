--!strict
-- Arcane Citadel: Black Market Auction Board (Phase 2 escrow market).
-- Rank 3+ only. Buy: cheapest first, 15% tax burned. Sell: escrow one of
-- your tradable Grimoire items at a Blood Shard price. Mailbox: claim
-- offline sale cuts + expired-listing item returns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(230, 50, 90),
}

local AuctionBoard = {}

local modal: Frame? = nil
local listBox: ScrollingFrame? = nil
local sellBox: ScrollingFrame? = nil
local msgLabel: TextLabel? = nil

local function invoke(name: string, ...: any): any
	local folder = Shared:WaitForChild("Remotes")
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

local refreshSell: () -> ()

local function refreshMarket(): ()
	if not listBox then
		return
	end
	for _, child in listBox:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local listings = EconomyClient.GetAuctionListings()
	local myId = Players.LocalPlayer.UserId
	local y = 0
	for _, l in listings do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 56)
		row.Position = UDim2.new(0, 4, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
		row.BorderSizePixel = 0
		row.Parent = listBox
		local nameLabel = UITheme.MakeLabel(
			row,
			"Name",
			tostring(l.itemName or "?"),
			UDim2.new(1, -110, 0, 20),
			UDim2.new(0, 6, 0, 2),
			13
		)
		nameLabel.TextColor3 = RARITY_COLORS[l.rarity] or UITheme.Text
		UITheme.MakeLabel(
			row,
			"Info",
			`💎 {UITheme.FormatSouls(l.price or 0)} · {tostring(l.rarity)} +{tonumber(l.level) or 0} · ⏳ {UITheme.FormatTime(l.endsIn or 0)}`,
			UDim2.new(1, -110, 0, 18),
			UDim2.new(0, 6, 0, 24),
			11
		)
		local id = l.listingId
		-- Own listings get a CANCEL button. Escrow removes the item from the
		-- seller's inventory the moment it is listed, so with no way to
		-- cancel the only recovery was waiting out the 24h TTL sweep.
		if l.seller == myId then
			local cancel = UITheme.MakeButton(row, "Cancel", "CANCEL", UDim2.new(0, 96, 0, 30), UDim2.new(1, -102, 0, 13), Color3.fromRGB(90, 60, 80))
			cancel.TextSize = 11
			cancel.MouseButton1Click:Connect(function()
				local ok, msg = EconomyClient.AuctionCancel(id)
				if msgLabel then
					msgLabel.Text = if ok then "Listing cancelled — item returned." else tostring(msg)
				end
				EconomyClient.Refresh()
				refreshMarket()
			end)
		else
			local buy = UITheme.MakeButton(row, "Buy", "BUY", UDim2.new(0, 96, 0, 30), UDim2.new(1, -102, 0, 13), UITheme.Gold)
			buy.TextColor3 = Color3.fromRGB(30, 20, 10)
			buy.MouseButton1Click:Connect(function()
				local ok, msg = EconomyClient.AuctionBuy(id)
				if msgLabel then
					msgLabel.Text = if ok then "Purchased! Check your Grimoire." else tostring(msg)
				end
				EconomyClient.Refresh()
				refreshMarket()
				refreshSell()
			end)
		end
		y += 60
	end
	if y == 0 and msgLabel then
		msgLabel.Text = "No listings. Be the first to sell (Rank 3+)!"
	end
	listBox.CanvasSize = UDim2.new(0, 0, 0, y)
end

refreshSell = function(): ()
	if not sellBox then
		return
	end
	for _, child in sellBox:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local inv = invoke("GetInventory")
	if typeof(inv) ~= "table" or typeof(inv.items) ~= "table" then
		return
	end
	local y = 0
	for _, item in inv.items do
		if item.tradable and not item.fractured then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 52)
			row.Position = UDim2.new(0, 4, 0, y)
			row.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
			row.BorderSizePixel = 0
			row.Parent = sellBox
			local nameLabel = UITheme.MakeLabel(row, "Name", item.name, UDim2.new(1, -180, 0, 20), UDim2.new(0, 6, 0, 2), 12)
			nameLabel.TextColor3 = RARITY_COLORS[item.rarity] or UITheme.Text
			UITheme.MakeLabel(row, "Info", `{item.rarity} +{item.level}`, UDim2.new(0, 90, 0, 18), UDim2.new(0, 6, 0, 24), 11)
			local priceBox = Instance.new("TextBox")
			priceBox.Name = "Price"
			priceBox.Size = UDim2.new(0, 70, 0, 28)
			priceBox.Position = UDim2.new(1, -168, 0, 12)
			priceBox.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
			priceBox.TextColor3 = UITheme.Text
			priceBox.Font = Enum.Font.GothamBold
			priceBox.TextSize = 12
			priceBox.PlaceholderText = "💎?"
			priceBox.Text = ""
			priceBox.Parent = row
			local list = UITheme.MakeButton(row, "List", "LIST", UDim2.new(0, 86, 0, 28), UDim2.new(1, -92, 0, 12), UITheme.Accent)
			local uid = item.uid
			list.MouseButton1Click:Connect(function()
				local price = tonumber(priceBox.Text or "")
				if not price then
					if msgLabel then
						msgLabel.Text = "Enter a Blood Shard price first."
					end
					return
				end
				local ok, msg = EconomyClient.AuctionList(uid, price)
				if msgLabel then
					msgLabel.Text = if ok then "Listed! Item escrowed to the market." else tostring(msg)
				end
				EconomyClient.Refresh()
				refreshSell()
				refreshMarket()
			end)
			y += 56
		end
	end
	sellBox.CanvasSize = UDim2.new(0, 0, 0, y)
end

function AuctionBoard.Refresh(): ()
	refreshMarket()
	refreshSell()
end

function AuctionBoard.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("AuctionBoard")

	local toggle = UITheme.MakeButton(gui, "Toggle", "🛒 MARKET", UDim2.new(0, 120, 0, 34), UDim2.new(1, -550, 0, 50), UITheme.Panel)
	toggle.MouseButton1Click:Connect(function()
		if modal then
			if not modal.Visible then
				AuctionBoard.Refresh()
			end
			modal.Visible = not modal.Visible
		end
	end)

	modal = UITheme.MakePanel(gui, "Board", UDim2.new(0, 460, 0, 430), UDim2.new(0.5, -230, 0.5, -215))
	modal.Visible = false
	UITheme.MakeLabel(modal, "Title", "🛒 BLACK MARKET (Rank 3+)", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 6), 15)
	msgLabel = UITheme.MakeLabel(modal, "Msg", "15% market tax burned. Escrowed items are traceable.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 30), 11)

	UITheme.MakeLabel(modal, "BuyTitle", "— BUY (cheapest first) —", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 50), 12)
	listBox = Instance.new("ScrollingFrame")
	listBox.Name = "Listings"
	listBox.Size = UDim2.new(1, -20, 0, 150)
	listBox.Position = UDim2.new(0, 10, 0, 70)
	listBox.BackgroundTransparency = 1
	listBox.ScrollBarThickness = 6
	listBox.Parent = modal

	UITheme.MakeLabel(modal, "SellTitle", "— SELL (your tradable gear) —", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 226), 12)
	sellBox = Instance.new("ScrollingFrame")
	sellBox.Name = "Sell"
	sellBox.Size = UDim2.new(1, -20, 0, 120)
	sellBox.Position = UDim2.new(0, 10, 0, 246)
	sellBox.BackgroundTransparency = 1
	sellBox.ScrollBarThickness = 6
	sellBox.Parent = modal

	local claim = UITheme.MakeButton(modal, "Mailbox", "📬 CLAIM MAILBOX", UDim2.new(0, 200, 0, 30), UDim2.new(0, 10, 0, 372), UITheme.SafeGreen)
	claim.MouseButton1Click:Connect(function()
		local result = EconomyClient.ClaimAuctionMailbox()
		if msgLabel then
			if typeof(result) == "table" then
				msgLabel.Text = `Mailbox: +{result.shards or 0} Shards, {result.items or 0} items returned.`
			else
				msgLabel.Text = "Mailbox empty."
			end
		end
		EconomyClient.Refresh()
		refreshSell()
	end)
	local refresh = UITheme.MakeButton(modal, "Refresh", "↻ REFRESH", UDim2.new(0, 200, 0, 30), UDim2.new(1, -210, 0, 372), Color3.fromRGB(70, 60, 95))
	refresh.MouseButton1Click:Connect(function()
		AuctionBoard.Refresh()
	end)

	gui.Parent = parent

	-- Keep the board live while it is open. It previously only refreshed on
	-- open / manual button / own buy+list, so another player listing (or
	-- selling) was never reflected unless the player noticed the ↻ button.
	EconomyClient.OnChanged(function()
		if modal and modal.Visible then
			task.spawn(AuctionBoard.Refresh)
		end
	end)
end

return AuctionBoard
