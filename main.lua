-- ==========================================
-- WAKEHUB KEY VERIFICATION (SIMPLIFIED)
-- ==========================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local API_URL = "https://outmatch-unranked-poncho.ngrok-free.dev/verify"

-- Get key
local key = script_key or ""

if key == "" then
    LocalPlayer:Kick("❌ No key provided!\n\nPlease use: script_key=\"WAKE-XXXX-XXXX\"")
    return
end

-- Check format (allows letters and numbers)
if not string.match(key, "^WAKE%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") then
    LocalPlayer:Kick("❌ Invalid key format!\n\nKey must be: WAKE-XXXX-XXXX")
    return
end

-- Send request to verify
local data = {
    key = key,
    hwid = tostring(LocalPlayer.UserId),
    username = LocalPlayer.Name,
    userid = LocalPlayer.UserId
}

local jsonData = HttpService:JSONEncode(data)

local function sendRequest()
    if syn and syn.request then
        local response = syn.request({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    if request then
        local response = request({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    if http_request then
        local response = http_request({
            Url = API_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    return nil
end

local response = sendRequest()
local success = false

if response then
    local parsed = HttpService:JSONDecode(response)
    if parsed and parsed.valid then
        success = true
    end
end

if not success then
    LocalPlayer:Kick("❌ Invalid key or HWID mismatch!\n\nPlease contact support.")
    return
end

print("✅ Key verified! Loading WakeHub...")

-- ==========================================
-- YOUR SCRIPT STARTS HERE
-- ==========================================

-- [[ PASTE YOUR WAKEHUB SCRIPT BELOW ]]
