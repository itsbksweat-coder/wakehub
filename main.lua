-- Executor desync
-- Toggle with the on-screen button or the V key.
-- While ON, your character stops replicating: you move normally on your screen,
-- but the server and all other clients see you frozen at the toggle spot.
-- A blue ghost shows where everyone else sees you. Toggle off to resync.
-- Needs setfflag. If your executor/client has the flags blocked, it will tell you.

if not game:IsLoaded() then game.Loaded:Wait() end

local env = (getgenv and getgenv()) or _G
if env.__DESYNC_LOADED then
	pcall(env.__DESYNC_CLEANUP)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local KEY = Enum.KeyCode.V
local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end

-- flags set while desynced, and the value restored on resync
local FLAGS = {
	{ "S2PhysicsSenderRate", "1", "15" },
	{ "NextGenReplicatorEnabledWrite", "True", "False" },
}

local on = false
local ghost, gui, button
local conns = {}

-- Method 2: throttle outgoing bandwidth. Position updates ride on this channel,
-- so squeezing it stops your character from replicating.
local NetworkClient = game:GetService("NetworkClient")
local savedLimit

local function setBandwidth(enable)
	if enable then
		local ok, cur = pcall(function() return NetworkClient:GetOutgoingKBPSLimit() end)
		savedLimit = (ok and type(cur) == "number") and cur or 100000
		return pcall(function() NetworkClient:SetOutgoingKBPSLimit(1) end)
	end
	return pcall(function() NetworkClient:SetOutgoingKBPSLimit(savedLimit or 100000) end)
end

local function setFlags(enable)
	local setf = setfflag or env.setfflag
	local used = {}
	if setf then
		for _, f in ipairs(FLAGS) do
			if pcall(setf, f[1], enable and f[2] or f[3]) then
				used[#used + 1] = f[1]
			end
		end
	end
	if setBandwidth(enable) then
		used[#used + 1] = "OutgoingKBPSLimit"
	end
	if #used == 0 then
		warn("[desync] no desync method worked on this executor")
		return false
	end
	print("[desync] " .. (enable and "ON" or "OFF") .. " via: " .. table.concat(used, ", "))
	return true
end

local function setGhost(cf)
	if ghost then ghost:Destroy() ghost = nil end
	if not cf then return end
	ghost = Instance.new("Part")
	ghost.Name = "DesyncGhost"
	ghost.Size = Vector3.new(2, 5, 1)
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Material = Enum.Material.ForceField
	ghost.Color = Color3.fromRGB(80, 160, 255)
	ghost.CFrame = cf
	ghost.Parent = workspace
end

local function refreshButton()
	if button then
		button.Text = on and "Desync: ON" or "Desync: OFF"
		button.BackgroundColor3 = on and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(150, 50, 50)
	end
end

local function toggle()
	if not on then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		if not setFlags(true) then return end
		on = true
		setGhost(root.CFrame)
	else
		setFlags(false)
		on = false
		setGhost(nil)
	end
	refreshButton()
end

-- GUI
gui = Instance.new("ScreenGui")
gui.Name = "DesyncGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

button = Instance.new("TextButton")
button.Size = UDim2.new(0, 140, 0, 40)
button.Position = UDim2.new(0, 20, 0.5, 0)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.BorderSizePixel = 0
button.Active = true
button.Draggable = true
button.ZIndex = 10
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

-- try every parent an executor might allow, in order
local function tryParent(getParent)
	local ok, parent = pcall(getParent)
	if ok and parent then
		local ok2 = pcall(function() gui.Parent = parent end)
		return ok2 and gui.Parent == parent
	end
	return false
end

pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
local parented = tryParent(function() return gethui and gethui() end)
	or tryParent(function() return game:GetService("CoreGui") end)
	or tryParent(function() return player:WaitForChild("PlayerGui", 5) end)
print("[desync] GUI parented:", parented, gui.Parent and gui.Parent:GetFullName())
refreshButton()

conns[#conns + 1] = button.MouseButton1Click:Connect(toggle)
conns[#conns + 1] = UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == KEY then toggle() end
end)
-- resync on respawn so you don't spawn frozen
conns[#conns + 1] = player.CharacterAdded:Connect(function()
	if on then toggle() end
end)

env.__DESYNC_LOADED = true
env.__DESYNC_CLEANUP = function()
	if on then setFlags(false) end
	for _, c in ipairs(conns) do c:Disconnect() end
	if ghost then ghost:Destroy() end
	if gui then gui:Destroy() end
	env.__DESYNC_LOADED = nil
end
