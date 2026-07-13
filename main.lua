-- ==========================================
-- 🔑 WAKEHUB KEY VERIFICATION (FIXED - Allows Numbers)
-- ==========================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- YOUR NGROK URL
local API_URL = "https://outmatch-unranked-poncho.ngrok-free.dev/verify"

-- ==========================================
-- HTTP REQUEST FUNCTION
-- ==========================================

local function httpRequest(url, data)
    local jsonData = HttpService:JSONEncode(data)
    
    if syn and syn.request then
        local response = syn.request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    if request then
        local response = request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    if http_request then
        local response = http_request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        return response.Body
    end
    
    local success, result = pcall(function()
        return HttpService:PostAsync(url, jsonData, Enum.HttpContentType.ApplicationJson)
    end)
    
    if success then
        return result
    end
    
    return nil
end

-- ==========================================
-- HWID GENERATION
-- ==========================================

local function getHWID()
    local success, result = pcall(function()
        local userId = LocalPlayer.UserId
        local gameId = game.GameId
        local placeId = game.PlaceId
        local hwidString = tostring(userId) .. "_" .. tostring(gameId) .. "_" .. tostring(placeId)
        
        local success2, result2 = pcall(function()
            return HttpService:GenerateGUID(false)
        end)
        
        if success2 then
            hwidString = hwidString .. "_" .. result2
        end
        
        return hwidString
    end)
    
    if success then
        return result
    else
        return "UNKNOWN_" .. tostring(LocalPlayer.UserId)
    end
end

-- ==========================================
-- KICK FUNCTION
-- ==========================================

local function kickUser(reason)
    LocalPlayer:Kick("❌ " .. reason .. "\n\nPlease contact support for assistance.\n(Error Code: 267)")
    task.wait(5)
    game:Shutdown()
end

-- ==========================================
-- VERIFY KEY
-- ==========================================

local function verifyKey(key, hwid)
    local success = false
    local responseData = nil
    
    pcall(function()
        local data = {
            key = key,
            hwid = hwid,
            username = LocalPlayer.Name,
            userid = LocalPlayer.UserId
        }
        
        local response = httpRequest(API_URL, data)
        
        if response then
            responseData = HttpService:JSONDecode(response)
            if responseData and responseData.valid then
                success = true
            end
        end
    end)
    
    return success, responseData
end

-- ==========================================
-- GET KEY FROM MULTIPLE SOURCES
-- ==========================================

local function getKey()
    if script_key ~= nil and script_key ~= "" then
        return script_key
    end
    
    if arg and arg[1] and arg[1] ~= "" then
        return arg[1]
    end
    
    if _G.script_key and _G.script_key ~= "" then
        return _G.script_key
    end
    
    local args = {...}
    if args[1] and args[1] ~= "" then
        return args[1]
    end
    
    return nil
end

-- ==========================================
-- CHECK KEY FORMAT (UPDATED - Allows Numbers)
-- ==========================================

local function isValidKey(key)
    if not key or key == "" then
        return false
    end
    
    -- Key must be: WAKE-XXXX-XXXX where X is letter OR number
    -- [A-Z0-9] means: A-Z OR 0-9
    local pattern = "^WAKE%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$"
    return string.match(key, pattern) ~= nil
end

-- ==========================================
-- MAIN VERIFICATION
-- ==========================================

print("🔑 WakeHub Key Verification Starting...")

-- Get the key
local key = getKey()

if not key then
    kickUser("No key provided!\n\nPlease use: script_key=\"WAKE-XXXX-XXXX\"")
    return
end

print("📝 Key found: " .. key)

-- Check key format (NOW ALLOWS NUMBERS)
if not isValidKey(key) then
    print("❌ Invalid key format: " .. key)
    print("✅ Expected format: WAKE-XXXX-XXXX where X is letter OR number")
    kickUser("Invalid key format!\n\nKey must be: WAKE-XXXX-XXXX\nExample: WAKE-MYJT-JH18 or WAKE-ABCD-1234")
    return
end

print("✅ Key format is valid: " .. key)

-- Get HWID
local hwid = getHWID()
print("🖥️ HWID: " .. hwid)

-- Verify with bot
print("⏳ Verifying with bot...")
local verified, response = verifyKey(key, hwid)

if not verified then
    local errorMsg = "Invalid key or HWID mismatch."
    if response and response.message then
        errorMsg = response.message
    end
    print("❌ Verification failed: " .. errorMsg)
    kickUser(errorMsg)
    return
end

print("✅ Key verified successfully! Loading WakeHub...")

-- ==========================================
-- YOUR WAKEHUB SCRIPT STARTS HERE
-- ==========================================

-- [[ PASTE YOUR WAKEHUB AUTO REDEEMER SCRIPT BELOW ]]
