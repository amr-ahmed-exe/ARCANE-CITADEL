--!strict
-- Arcane Citadel: "?" How-to-Play panel (tutorial catch-all).

local UITheme = require(script.Parent.UITheme)

local HelpPanel = {}

local modal: Frame? = nil

local TEXT = [[HOW TO PLAY

🏰 Your Citadel has 3 walls. Intact walls print Souls every second.

👻 Glowing balls are Wraiths marching on your outer wall.
   LEFT-CLICK them to blast them. Q / E / R cast spells.

🧪 Outer walls are weak (0.8x / 0.6x). Brew a 15-min Elixir
   from the left panel so automated wards hold them alone.

🔧 Walls BLEEDING? Hit REPAIR (+20% HP for Souls) — greed
   vs survival! The longer a Blood Pact runs, the hotter
   it gets (+threat every minute). Repair, hold, or cash out!

🔥 Chained wraith kills pay BONUS souls (up to +40%).
   Standing on the ramparts beats pure AFK.

⚔ ENTER BLOOD PACT for 2x+ Souls — but your Vault seals and
   raiders can steal 33% per fallen wall. Fallen wall?
   BANK the rest or HOLD the tighter inner line for bonus!

⚔ GRIMOIRE: roll gear, reforge traits, swap Warden/Raider.
🌐 RAID: invade other players' Blood Pacts for loot.
🎁 GIFTS: free Blood Shards for staying in game.

Defend. Raid. Ascend.]]

function HelpPanel.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("HelpPanel")

	local helpBtn = UITheme.MakeButton(gui, "Help", "?", UDim2.new(0, 40, 0, 34), UDim2.new(1, -600, 0, 50), UITheme.Panel)
	helpBtn.MouseButton1Click:Connect(function()
		if modal then
			modal.Visible = not modal.Visible
		end
	end)

	modal = UITheme.MakePanel(gui, "Help", UDim2.new(0, 440, 0, 420), UDim2.new(0.5, -220, 0.5, -210))
	modal.Visible = false
	local body = UITheme.MakeLabel(modal, "Body", TEXT, UDim2.new(1, -20, 1, -60), UDim2.new(0, 10, 0, 8), 13)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	local close = UITheme.MakeButton(modal, "Close", "CLOSE", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 1, -40), UITheme.Accent)
	close.MouseButton1Click:Connect(function()
		if modal then
			modal.Visible = false
		end
	end)

	gui.Parent = parent
end

return HelpPanel
