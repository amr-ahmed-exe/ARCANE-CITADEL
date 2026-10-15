--!strict
-- Arcane Citadel: code-built warlock look (art pass, zero assets).
-- Crooked witch-hat, back cloak, hand staff, and dark body colors.
-- Works on R6 + R15, re-applied on every respawn. Purely cosmetic:
-- every piece is unanchored, massless, non-colliding, and welded.

local CharacterDresser = {}

local GraphicsConfig = require(game:GetService("ReplicatedStorage").Shared.Configurations.GraphicsConfig)

local ROBE = Color3.fromRGB(45, 28, 80)
local TRIM = Color3.fromRGB(150, 60, 255)
local DARK = Color3.fromRGB(25, 16, 40)
local PALE = Color3.fromRGB(210, 190, 230)

local function weldTo(anchor: BasePart, child: BasePart): ()
	child.Parent = anchor
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = child
	w.Parent = anchor
end

local function piece(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Material = mat
	p.Color = color
	return p
end

local function flatDisc(): CFrame
	return CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y (lies flat)
end

function CharacterDresser.Dress(_player: Player, character: Model): ()
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head or character:FindFirstChild("WarlockHat") then
		return -- missing head, or already dressed
	end

	-- Pale face, dark robe body.
	local bodies = character:FindFirstChildOfClass("BodyColors")
	if bodies then
		local bc = bodies :: BodyColors
		bc.HeadColor3 = PALE
		bc.TorsoColor3 = ROBE
		bc.LeftArmColor3 = ROBE
		bc.RightArmColor3 = ROBE
		bc.LeftLegColor3 = DARK
		bc.RightLegColor3 = DARK
	end

	local headCF = head.CFrame
	local topY = head.Size.Y / 2

	-- Crooked witch-hat: wide brim, two leaning tiers, glowing tip.
	local brim = piece("HatBrim", Vector3.new(0.6, 6.5, 6.5), headCF * CFrame.new(0, topY + 0.1, 0) * flatDisc(), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	weldTo(head, brim)
	local tier1 = piece("HatTier1", Vector3.new(2.6, 3.2, 3.2), headCF * CFrame.new(0, topY + 1.5, 0) * flatDisc(), ROBE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	weldTo(head, tier1)
	local band = piece("HatBand", Vector3.new(0.5, 3.4, 3.4), headCF * CFrame.new(0, topY + 0.9, 0) * flatDisc(), TRIM, Enum.Material.Neon, Enum.PartType.Cylinder)
	weldTo(head, band)
	local tier2 = piece("HatTier2", Vector3.new(2.2, 2.0, 2.0), headCF * CFrame.new(0.5, topY + 3.4, 0) * flatDisc(), ROBE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	weldTo(head, tier2)
	local tip = piece("HatTip", Vector3.new(1.1, 1.1, 1.1), headCF * CFrame.new(1.0, topY + 4.8, 0), TRIM, Enum.Material.Neon, Enum.PartType.Ball)
	weldTo(head, tip)

	-- Back cloak on the torso.
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local cloak = piece("WarlockCloak", Vector3.new(3.4, 2.4, 0.6), torso.CFrame * CFrame.new(0, 0.2, -1.3), ROBE, Enum.Material.SmoothPlastic, nil)
		cloak.Transparency = 0.05
		weldTo(torso, cloak)
	end

	-- Hand staff: shaft + orb + halo + rising sparks.
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		local handCF = hand.CFrame
		local shaft = piece("StaffShaft", Vector3.new(4.2, 0.5, 0.5), handCF * CFrame.new(0.3, 1.0, 0.3) * flatDisc(), DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
		weldTo(hand, shaft)
		local orb = piece("StaffOrb", Vector3.new(1.2, 1.2, 1.2), handCF * CFrame.new(0.3, 3.4, 0.3), TRIM, Enum.Material.Neon, Enum.PartType.Ball)
		weldTo(hand, orb)
		local halo = piece("StaffHalo", Vector3.new(0.25, 2.2, 2.2), handCF * CFrame.new(0.3, 3.4, 0.3) * flatDisc(), TRIM, Enum.Material.Neon, Enum.PartType.Cylinder)
		halo.Transparency = 0.5
		weldTo(hand, halo)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "StaffSparks"
		sparks.Rate = GraphicsConfig.ScaledRate(4)
		sparks.Lifetime = NumberRange.new(0.5, 1)
		sparks.Speed = NumberRange.new(1, 3)
		sparks.Size = NumberSequence.new(0.5)
		sparks.Color = ColorSequence.new(TRIM)
		sparks.LightEmission = 1
		sparks.Parent = orb
	end

	-- Marker so double-spawns never stack a second hat.
	local tag = Instance.new("BoolValue")
	tag.Name = "WarlockHat"
	tag.Parent = character
end

return CharacterDresser
