-- Desync (executor LocalScript)
-- Press the toggle key to freeze your character's replication. You keep moving
-- on your screen, but the server and every other client see you stuck at the
-- spot where you toggled it on. A blue ghost shows where others see you.
-- Press the key again to resync (your real position gets sent again).
--
-- Needs an executor with setfflag. Roblox has whitelisted/blocked many FFlags,
-- so if it does nothing, the flag is patched on your executor/client.

local TOGGLE_KEY = Enum.KeyCode.V
local DESYNC_RATE = "1"   -- physics packets per second while desynced
local NORMAL_RATE = "15"  -- Roblox default

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local desynced = false
local ghost

local function setRate(rate)
	local setf = setfflag or (getgenv and getgenv().setfflag)
	if not setf then
		warn("[desync] your executor has no setfflag")
		return false
	end
	-- the DFInt prefix is dropped when calling setfflag
	local ok = pcall(setf, "S2PhysicsSenderRate", rate)
	return ok
end

local function makeGhost(cf)
	if ghost then ghost:Destroy() end
	ghost = Instance.new("Part")
	ghost.Name = "DesyncGhost"
	ghost.Size = Vector3.new(2, 5, 1)
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Material = Enum.Material.ForceField
	ghost.Color = Color3.fromRGB(80, 160, 255)
	ghost.Transparency = 0.4
	ghost.CFrame = cf
	ghost.Parent = workspace
end

local function enable()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if not setRate(DESYNC_RATE) then return end
	desynced = true
	makeGhost(root.CFrame)
	print("[desync] ON")
end

local function disable()
	setRate(NORMAL_RATE)
	desynced = false
	if ghost then ghost:Destroy() ghost = nil end
	print("[desync] OFF")
end

UIS.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= TOGGLE_KEY then return end
	if desynced then disable() else enable() end
end)

-- never stay desynced after respawn
player.CharacterAdded:Connect(function()
	if desynced then disable() end
end)

-- keep the ghost at the frozen spot
RunService.Heartbeat:Connect(function()
	if not desynced and ghost then
		ghost:Destroy()
		ghost = nil
	end
end)
