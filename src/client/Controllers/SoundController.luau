--!strict
-- Arcane Citadel: client sound cues (blueprint 2.2).
-- Tiny synth-free kit built on Roblox built-in audio: breach drums,
-- bounty chimes, gift pops. Cosmetic only; silent if assets fail.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local SoundController = {}

-- Built-in Roblox audio (no uploads required).
local SOUNDS = {
	Breach = "rbxasset://sounds/electronicpingshort.wav",
	Bounty = "rbxasset://sounds/bfsl-minifigfoots1.mp3",
	Gift = "rbxasset://sounds/bfsl-minifigfoots1.mp3",
	Hex = "rbxasset://sounds/electronicpingshort.wav",
	Alarm = "rbxasset://sounds/electronicpingshort.wav", -- wall-critical alert
	Streak = "rbxasset://sounds/bfsl-minifigfoots1.mp3", -- kill-streak milestone
}

local function play(name: string, volume: number?): ()
	local id = SOUNDS[name]
	if not id then
		return
	end
	local ok, sound = pcall(function()
		local s = Instance.new("Sound")
		s.Name = `Arcane_{name}`
		s.SoundId = id
		s.Volume = volume or 0.6
		s.Parent = SoundService
		return s
	end)
	if not ok or not sound then
		return
	end
	pcall(function()
		(sound :: Sound):Play()
	end);
	(sound :: Sound).Ended:Connect(function()
		(sound :: Sound):Destroy()
	end)
	task.delay(5, function()
		if (sound :: Sound).Parent then
			(sound :: Sound):Destroy()
		end
	end)
end

function SoundController.Cue(name: string): ()
	play(name)
end

function SoundController.Init(): ()
	local remotes = Shared:WaitForChild("Remotes")
	local event = remotes:WaitForChild("Notice") :: RemoteEvent
	(event :: RemoteEvent).OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" or typeof(data.text) ~= "string" then
			return
		end
		local text: string = data.text
		if string.find(text, "WALL", 1, true) or string.find(text, "FALLEN", 1, true) or string.find(text, "💥", 1, true) then
			play("Breach", 0.8)
		elseif string.find(text, "Bounty", 1, true) or string.find(text, "VENGEANCE", 1, true) or string.find(text, "COLOSSUS", 1, true) then
			play("Bounty", 0.7)
		elseif string.find(text, "Gift", 1, true) or string.find(text, "🎁", 1, true) then
			play("Gift", 0.5)
		elseif string.find(text, "Hex", 1, true) then
			play("Hex", 0.6)
		end
	end)
end

return SoundController
