-- Executor desync - layered methods
-- Freezes LocalPlayer for everyone else. You stay movable locally.
-- Toggle: V key, or the on-screen button.
-- Tested target: Synapse Z. Needs setfflag, sethiddenproperty, getgenv.

if not game:IsLoaded() then game.Loaded:Wait() end

local env = (getgenv and getgenv()) or _G
if env.__DESYNC_LOADED then pcall(env.__DESYNC_CLEANUP) end

-- capability probe
do
	local names = { "setfflag", "getgenv", "gethui", "sethiddenproperty", "gethiddenproperty", "setsimulationradius", "firesignal", "hookmetamethod" }
	local have, missing = {}, {}
	for _, n in ipairs(names) do
		local ok, v = pcall(function() return getfenv()[n] end)
		if ok and v ~= nil then have[#have + 1] = n else missing[#missing + 1] = n end
	end
	print("[desync] executor has: " .. table.concat(have, ", "))
	print("[desync] executor missing: " .. table.concat(missing, ", "))
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local NetworkClient = game:GetService("NetworkClient")

local KEY = Enum.KeyCode.V
local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end

local FLAGS = {
	{ "S2PhysicsSenderRate", "1", "15" },
	{ "WorldStepMax", "-9999999999", "30" },
	{ "MaxMissedWorldStepsRemembered", "-2147483648", "16" },
	{ "ChatOutgoingThrottleBuffer", "9999999", "100" },
}

local on = false
local ghost, gui, button
local conns, physConn, cleanupExtras = {}, nil, {}
local frozenCF, savedBandwidth, savedSimRadius, savedMaxSimRadius

-- ============ METHODS ============

local function tryFFlags(enable)
	local setf = setfflag or env.setfflag
	local used = {}
	if not setf then return used end
	for _, f in ipairs(FLAGS) do
		local ok = pcall(setf, f[1], enable and f[2] or f[3])
		if ok then used[#used + 1] = f[1] end
	end
	return used
end

local function tryBandwidth(enable)
	if enable then
		local ok, cur = pcall(function() return NetworkClient:GetOutgoingKBPSLimit() end)
		savedBandwidth = (ok and type(cur) == "number") and cur or 100000
		local ok2 = pcall(function() NetworkClient:SetOutgoingKBPSLimit(1) end)
		return ok2 and "OutgoingKBPSLimit(1)" or nil
	else
		pcall(function() NetworkClient:SetOutgoingKBPSLimit(savedBandwidth or 100000) end)
		return "OutgoingKBPSLimit(restored)"
	end
end

local function trySimulationRadius(enable)
	local shp = sethiddenproperty or env.sethiddenproperty
	local ghp = gethiddenproperty or env.gethiddenproperty
	if not shp then return nil end
	if enable then
		if ghp then
			local ok1, r = pcall(ghp, player, "SimulationRadius")
			local ok2, mr = pcall(ghp, player, "MaximumSimulationRadius")
			if ok1 then savedSimRadius = r end
			if ok2 then savedMaxSimRadius = mr end
		end
		local a = pcall(shp, player, "SimulationRadius", 0)
		local b = pcall(shp, player, "MaximumSimulationRadius", 0)
		if a or b then return "SimulationRadius=0" end
	else
		pcall(shp, player, "SimulationRadius", savedSimRadius or 139)
		pcall(shp, player, "MaximumSimulationRadius", savedMaxSimRadius or math.huge)
		return "SimulationRadius(restored)"
	end
	return nil
end

local function trySetSimRadiusFn(enable)
	local ssr = setsimulationradius or env.setsimulationradius
	if not ssr then return nil end
	local ok = pcall(ssr, enable and 0 or 139)
	return ok and "setsimulationradius" or nil
end

-- Physics-step position lock: before every physics step, snap HRP to the
-- frozen CFrame so the replicator sends the frozen position. After the step,
-- snap it back to where you are locally so you can keep moving on screen.
local function startPhysicsLock()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	frozenCF = root.CFrame
	local localCF = root.CFrame

	-- order matters: let physics advance from your real position, THEN snap to
	-- frozen so the replicator picks up frozen. Next frame, restore before
	-- physics so your input keeps moving the character locally.
	local steppedConn = RunService.Stepped:Connect(function()
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then return end
		pcall(function() r.CFrame = localCF end)
	end)

	local heartConn = RunService.Heartbeat:Connect(function()
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then return end
		localCF = r.CFrame
		pcall(function() r.CFrame = frozenCF end)
	end)

	cleanupExtras[#cleanupExtras + 1] = function()
		steppedConn:Disconnect()
		heartConn:Disconnect()
	end
	return "PhysicsStepLock"
end

local function stopPhysicsLock()
	for _, fn in ipairs(cleanupExtras) do pcall(fn) end
	cleanupExtras = {}
end

local function makeGhost(cf)
	if ghost then ghost:Destroy() ghost = nil end
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

local function removeGhost()
	if ghost then ghost:Destroy() ghost = nil end
end

local function refreshButton()
	if not button then return end
	button.Text = on and "Desync: ON" or "Desync: OFF"
	button.BackgroundColor3 = on and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(150, 50, 50)
end

local function toggle()
	if not on then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then warn("[desync] no character") return end
		local used = {}
		for _, m in ipairs(tryFFlags(true)) do used[#used + 1] = m end
		local b = tryBandwidth(true); if b then used[#used + 1] = b end
		local s = trySimulationRadius(true); if s then used[#used + 1] = s end
		local ss = trySetSimRadiusFn(true); if ss then used[#used + 1] = ss end
		local p = startPhysicsLock(); if p then used[#used + 1] = p end
		if #used == 0 then warn("[desync] no method worked") return end
		on = true
		makeGhost(root.CFrame)
		print("[desync] ON via: " .. table.concat(used, ", "))
	else
		stopPhysicsLock()
		tryFFlags(false)
		tryBandwidth(false)
		trySimulationRadius(false)
		trySetSimRadiusFn(false)
		on = false
		removeGhost()
		print("[desync] OFF")
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
conns[#conns + 1] = player.CharacterAdded:Connect(function()
	if on then toggle() end
end)

env.__DESYNC_LOADED = true
env.__DESYNC_CLEANUP = function()
	if on then
		stopPhysicsLock()
		tryFFlags(false); tryBandwidth(false); trySimulationRadius(false); trySetSimRadiusFn(false)
	end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if ghost then ghost:Destroy() end
	if gui then gui:Destroy() end
	env.__DESYNC_LOADED = nil
end
