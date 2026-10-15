--!strict
-- Arcane Citadel: transient event banners (breaches, bounties, hires).
-- Server fires "Notice"; we queue gold/red banners under the goal line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UITheme = require(script.Parent.UITheme)

local NoticeBanner = {}

local stack: Frame? = nil
local queue: { any } = {}
local showing = false

local function showNext(): ()
	if showing then
		return
	end
	-- Peek BEFORE dequeuing. The old order removed the notice first and then
	-- bailed if `stack` did not exist yet, so any server Notice (or local
	-- ShowLocal from an earlier Build) that arrived before Build() was
	-- silently thrown away.
	local next = queue[1]
	if not next or not stack then
		return
	end
	table.remove(queue, 1)
	showing = true
	for _, child in stack:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local label = UITheme.MakeTitle(stack, "Notice", next.text, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, -16, 0), 14)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextColor3 = Color3.fromRGB(next.color[1], next.color[2], next.color[3])
	label.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
	label.BackgroundTransparency = 0.3
	label.TextTransparency = 1
	-- Slide down + fade in, hold, then fade out.
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
		TextTransparency = 0,
	}):Play()
	task.delay(3.2, function()
		if label.Parent then
			local fade = TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
		end
		label:Destroy()
		showing = false
		showNext()
	end)
end

-- Client-side banner (no server round-trip): wall alarms, streak milestones.
function NoticeBanner.ShowLocal(text: string, color: { number }?): ()
	table.insert(queue, { text = text, color = color or { 255, 190, 60 } })
	if #queue > 3 then
		table.remove(queue, 1)
	end
	showNext()
end

function NoticeBanner.Build(parent: Instance): ()
	local gui = UITheme.MakeScreenGui("NoticeBanner")
	stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.Size = UDim2.new(0, 500, 0, 30)
	stack.Position = UDim2.new(0.5, -250, 0, 128)
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	gui.Parent = parent

	-- Drain anything that queued up before the banner existed.
	showNext()

	local event = Shared:WaitForChild("Remotes"):WaitForChild("Notice") :: RemoteEvent
	event.OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and typeof(data.text) == "string" then
			table.insert(queue, data)
			if #queue > 3 then
				table.remove(queue, 1)
			end
			showNext()
		end
	end)
end

return NoticeBanner
