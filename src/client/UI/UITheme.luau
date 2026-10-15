--!strict
-- Arcane Citadel: dark-witchery UI tokens + builders (Milestone 2).

local TweenService = game:GetService("TweenService")

local UITheme = {}

-- Per-button base colors (hover/press FX tween relative to these).
local buttonBase: { [TextButton]: Color3 } = {}
-- Active glow loops (SetGlow), guarded so re-enabling never stacks.
local glowActive: { [GuiObject]: boolean } = {}

UITheme.Background = Color3.fromRGB(15, 10, 25)
UITheme.Panel = Color3.fromRGB(25, 18, 42)
UITheme.Accent = Color3.fromRGB(150, 60, 255)
UITheme.Gold = Color3.fromRGB(255, 190, 60)
UITheme.Crimson = Color3.fromRGB(210, 40, 60)
UITheme.SafeGreen = Color3.fromRGB(50, 200, 120)
UITheme.Text = Color3.fromRGB(235, 225, 255)
UITheme.Dim = Color3.fromRGB(150, 140, 180)

-- Every UIScale we hand out, so a window resize can re-scale the whole UI
-- instead of leaving it stuck at the scale sampled at build time.
local scales: { UIScale } = {}

local function baseScale(): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1366, 768)
	return math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.65, 1)
end

local function applyScale(scale: UIScale): ()
	scale.Scale = baseScale()
end

task.spawn(function()
	local camera = workspace.CurrentCamera
	while not camera do
		camera = workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
		camera = workspace.CurrentCamera
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, scale in scales do
			applyScale(scale)
		end
	end)
end)

function UITheme.MakeScreenGui(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- UX: scale fixed-pixel layouts down on small screens (mobile).
	local scale = Instance.new("UIScale")
	applyScale(scale)
	scale.Parent = gui
	table.insert(scales, scale)
	return gui
end

function UITheme.MakePanel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = UITheme.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	-- Absorb clicks on the panel body. Without this a plain Frame does not set
	-- gameProcessed, so clicking empty modal background leaked through to the
	-- staff-fire handler and shot a bolt through the player's own UI.
	frame.Active = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Accent
	stroke.Transparency = 0.4
	stroke.Thickness = 1
	stroke.Parent = frame
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 180, 220))
	sheen.Transparency = NumberSequence.new(0.88, 1)
	sheen.Parent = frame
	frame.Parent = parent
	return frame
end

function UITheme.MakeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = UITheme.Text
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Heavy display title: black weight + dark outline for headers and banners.
function UITheme.MakeTitle(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number?): TextLabel
	local label = UITheme.MakeLabel(parent, name, text, size, position, textSize or 16)
	label.Font = Enum.Font.GothamBlack
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(10, 6, 18)
	outline.Transparency = 0.25
	outline.Thickness = 2
	outline.Parent = label
	return label
end

function UITheme.MakeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color or UITheme.Accent
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.AutoButtonColor = false
	button.ClipsDescendants = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = button
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 200, 235))
	sheen.Transparency = NumberSequence.new(0.72, 0.95)
	sheen.Parent = button
	buttonBase[button] = button.BackgroundColor3
	UITheme.AddButtonFX(button)
	return button
end

-- Hover lighten + press darken, always relative to the live base color.
function UITheme.AddButtonFX(button: TextButton): ()
	local function base(): Color3
		return buttonBase[button] or button.BackgroundColor3
	end
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base():Lerp(Color3.fromRGB(255, 255, 255), 0.15) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = base() }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.07), { BackgroundColor3 = base():Lerp(Color3.fromRGB(0, 0, 0), 0.25) }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base() }):Play()
	end)
end

-- The only sanctioned way to recolor a themed button (keeps hover FX in sync).
function UITheme.SetButtonColor(button: TextButton, color: Color3): ()
	buttonBase[button] = color
	button.BackgroundColor3 = color
end

-- Pulsing outline glow for attract loops (pact button, breach modal).
function UITheme.SetGlow(obj: GuiObject, on: boolean, color: Color3?): ()
	if on then
		if glowActive[obj] then
			return
		end
		local found = obj:FindFirstChildOfClass("UIStroke")
		local stroke: UIStroke
		if found then
			stroke = found
		else
			local created = Instance.new("UIStroke")
			created.Thickness = 2
			created.Parent = obj
			stroke = created
		end
		stroke.Color = color or UITheme.Gold
		glowActive[obj] = true
		task.spawn(function()
			while glowActive[obj] and obj.Parent do
				local fade = TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.05 })
				fade:Play()
				fade.Completed:Wait()
				if not glowActive[obj] then
					break
				end
				local back = TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.8 })
				back:Play()
				back.Completed:Wait()
			end
			if stroke.Parent then
				stroke.Transparency = 0.5
			end
		end)
	else
		glowActive[obj] = nil
	end
end

function UITheme.FormatSouls(n: number): string
	n = math.floor(n)
	if n >= 1_000_000 then
		return string.format("%.2fM", n / 1_000_000)
	elseif n >= 10_000 then
		return string.format("%.1fK", n / 1000)
	end
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, #s - 3)
	end
	return s .. out
end

function UITheme.FormatTime(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local m = math.floor(totalSeconds / 60)
	local s = totalSeconds % 60
	return string.format("%d:%02d", m, s)
end

return UITheme
