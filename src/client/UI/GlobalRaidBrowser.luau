--!strict
-- Arcane Citadel: Global Raid Browser (blueprint package 4).
-- Live Blood Pact targets + Phantom Citadel AI fallbacks. [INVADE] routes
-- through TeleportService (needs a published place; errors gracefully).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyClient = require(script.Parent.Parent.Controllers.EconomyClient)
local UITheme = require(script.Parent.UITheme)

local GlobalRaidBrowser = {}

local modal: Frame? = nil
local listBox: ScrollingFrame? = nil
local msgLabel: TextLabel? = nil

local function invoke(name: string, ...: any): any
	local folder = Shared:WaitForChild("Remotes")
	local remote = folder:WaitForChild(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

local function refresh(): ()
	if not listBox then
		return
	end
	for _, child in listBox:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local targets = invoke("GetRaidTargets")
	if typeof(targets) ~= "table" then
		return
	end
	local y = 0
	for _, t in targets do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 56)
		row.Position = UDim2.new(0, 4, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
		row.BorderSizePixel = 0
		row.Parent = listBox
		UITheme.MakeLabel(row, "Name", tostring(t.name or "?"), UDim2.new(1, -110, 0, 20), UDim2.new(0, 6, 0, 2), 13)
		UITheme.MakeLabel(
			row,
			"Info",
			`🏆 {UITheme.FormatSouls(t.pot or 0)} · 🛡 {UITheme.FormatSouls(t.dr or 0)} · 🧱 {tonumber(t.walls) or 0}/3`,
			UDim2.new(1, -110, 0, 18),
			UDim2.new(0, 6, 0, 24),
			11
		)
		local invade = UITheme.MakeButton(row, "Invade", "INVADE", UDim2.new(0, 96, 0, 30), UDim2.new(1, -102, 0, 13), UITheme.Crimson)
		local jobId = t.jobId
		invade.MouseButton1Click:Connect(function()
			local ok, msg = invoke("InvadeRealm", jobId)
			if msgLabel then
				msgLabel.Text = if ok then "Through the portal…" else tostring(msg)
			end
		end)
		y += 60
	end
	listBox.CanvasSize = UDim2.new(0, 0, 0, y)
end

function GlobalRaidBrowser.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("GlobalRaidBrowser")

	local toggle = UITheme.MakeButton(gui, "Toggle", "⚔ RAID", UDim2.new(0, 120, 0, 34), UDim2.new(1, -420, 0, 50), UITheme.Panel)
	toggle.MouseButton1Click:Connect(function()
		if modal then
			modal.Visible = not modal.Visible
			if modal.Visible then
				refresh()
			end
		end
	end)

	modal = UITheme.MakePanel(gui, "Browser", UDim2.new(0, 420, 0, 340), UDim2.new(1, -430, 0, 50))
	modal.Visible = false
	UITheme.MakeLabel(modal, "Title", "🌐 RAID BROWSER", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 6), 15)
	msgLabel = UITheme.MakeLabel(modal, "Msg", "Live Blood Pact realms. Phantoms are AI demos.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 30), 11)

	listBox = Instance.new("ScrollingFrame")
	listBox.Name = "Targets"
	listBox.Size = UDim2.new(1, -20, 1, -58)
	listBox.Position = UDim2.new(0, 10, 0, 50)
	listBox.BackgroundTransparency = 1
	listBox.ScrollBarThickness = 6
	listBox.Parent = modal

	gui.Parent = parent

	-- Throttled live refresh. Targets used to be fetched exactly once on
	-- open, so the "Live Blood Pact realms" list never changed while the
	-- player was actually looking at it.
	local lastFetch = 0
	EconomyClient.OnChanged(function()
		if not modal or not modal.Visible then
			return
		end
		local now = os.clock()
		if now - lastFetch < 2 then
			return
		end
		lastFetch = now
		task.spawn(refresh)
	end)
end

return GlobalRaidBrowser
