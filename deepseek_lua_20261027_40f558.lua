-- ============================================================
--  YBA Multi-Tool v8 — fix UI + logging + pcall
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

print("[YBA] v8 init")

local ALL_STANDS = {
    "Aerosmith", "Anubis", "Beach Boy", "C-Moon", "Chariot Requiem",
    "Cream", "Crazy Diamond", "Crazy Diamond Requiem", "D4C", "D4C Love Train",
    "Diver Down", "Gold Experience", "Gold Experience Requiem", "Hermit Purple",
    "Hierophant Green", "Killer Queen", "Killer Queen Bites the Dust",
    "King Crimson", "King Crimson Requiem", "Made in Heaven", "Magician's Red",
    "Mr. President", "Purple Haze", "Red Hot Chili Pepper", "Scary Monsters",
    "Sex Pistols", "Silver Chariot", "Soft & Wet", "Soft & Wet: Go Beyond",
    "Star Platinum", "Star Platinum: The World", "Sticky Fingers", "Stone Free",
    "The Hand", "The World", "The World: Alternate Universe",
    "The World: Over Heaven", "Tusk Act 1", "Tusk Act 2", "Tusk Act 3",
    "Tusk Act 4", "White Album", "Whitesnake",
}

local CONFIG = {
    LoopDelay = 0.5,
    MaxItemDistance = 5000,
    ItemNames = {
        "Mysterious Arrow", "Rokakaka", "Pure Rokakaka", "Lucky Arrow",
        "Diamond", "Gold Coin", "Stone Mask", "Dio's Diary", "Steel Ball",
        "Rib Cage of The Saint's Corpse", "Ancient Scroll",
        "Quinton's Glove", "Zepellin's Headband", "Zeppelin's Headband",
        "Lucky Stone Mask", "Clackers", "Christmas Present",
        "Yellow Candy", "Green Candy", "Red Candy", "Blue Candy",
        "Caesar's Headband",
    },
    SellNPCNames = { "ShiftPlox", "Merchant", "Shop" },
    BuyNPCNames  = { "Isabelle", "Arrow Smith", "Shop" },
    NPCCooldown = 10,
    InventorySellThreshold = 20,
    DesiredStands = {},
    KeepOnlyShiny = false,
    SafeSpot = Vector3.new(-113.0, -33.5, 160.1),
    FarmZoneRadius = 0,
    TeleportPoints = {
        Spawn        = Vector3.new(0, 5, 0),
        Arcade       = Vector3.new(120, 5, 80),
        Sewers       = Vector3.new(200, -15, 200),
        Mansion      = Vector3.new(-150, 5, -120),
        Merchant     = Vector3.new(80, 5, 120),
        ArrowSmith   = Vector3.new(90, 5, 90),
        TrainStation = Vector3.new(-50, 5, 200),
        Park         = Vector3.new(-80, 5, 50),
        SafeSpot     = Vector3.new(-113.0, -33.5, 160.1),
    },
}
local TPOrder = {
    "Spawn", "Arcade", "Sewers", "Mansion",
    "Merchant", "ArrowSmith", "TrainStation", "Park", "SafeSpot",
}

local SETTINGS_FILE = "YBA_MultiTool_settings.json"

local function serializeConfig()
    local tp = {}
    for k, v in pairs(CONFIG.TeleportPoints) do tp[k] = { v.X, v.Y, v.Z } end
    local ss = CONFIG.SafeSpot
    local data = {
        ItemNames = CONFIG.ItemNames,
        DesiredStands = CONFIG.DesiredStands,
        KeepOnlyShiny = CONFIG.KeepOnlyShiny,
        SellNPCNames = CONFIG.SellNPCNames,
        BuyNPCNames = CONFIG.BuyNPCNames,
        InventorySellThreshold = CONFIG.InventorySellThreshold,
        NPCCooldown = CONFIG.NPCCooldown,
        LoopDelay = CONFIG.LoopDelay,
        MaxItemDistance = CONFIG.MaxItemDistance,
        SafeSpot = ss and { ss.X, ss.Y, ss.Z } or nil,
        FarmZoneRadius = CONFIG.FarmZoneRadius,
        TeleportPoints = tp,
        TPOrder = TPOrder,
    }
    local ok, str = pcall(function() return HttpService:JSONEncode(data) end)
    return ok and str or nil
end

local function loadConfig()
    if not (writefile and readfile and isfile) then return end
    local okE, exists = pcall(isfile, SETTINGS_FILE)
    if not okE or not exists then return end
    local okR, raw = pcall(readfile, SETTINGS_FILE)
    if not okR or not raw or raw == "" then return end
    local okD, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okD or type(data) ~= "table" then return end
    if type(data.ItemNames) == "table" and #data.ItemNames > 0 then CONFIG.ItemNames = data.ItemNames end
    if type(data.DesiredStands) == "table" then CONFIG.DesiredStands = data.DesiredStands end
    if type(data.KeepOnlyShiny) == "boolean" then CONFIG.KeepOnlyShiny = data.KeepOnlyShiny end
    if type(data.SellNPCNames) == "table" and #data.SellNPCNames > 0 then CONFIG.SellNPCNames = data.SellNPCNames end
    if type(data.BuyNPCNames) == "table" and #data.BuyNPCNames > 0 then CONFIG.BuyNPCNames = data.BuyNPCNames end
    if type(data.InventorySellThreshold) == "number" then CONFIG.InventorySellThreshold = data.InventorySellThreshold end
    if type(data.NPCCooldown) == "number" then CONFIG.NPCCooldown = data.NPCCooldown end
    if type(data.LoopDelay) == "number" and data.LoopDelay >= 0.1 then CONFIG.LoopDelay = data.LoopDelay end
    if type(data.MaxItemDistance) == "number" then CONFIG.MaxItemDistance = data.MaxItemDistance end
    if type(data.FarmZoneRadius) == "number" then CONFIG.FarmZoneRadius = data.FarmZoneRadius end
    if type(data.SafeSpot) == "table" and #data.SafeSpot >= 3 then
        CONFIG.SafeSpot = Vector3.new(data.SafeSpot[1], data.SafeSpot[2], data.SafeSpot[3])
    end
    if type(data.TeleportPoints) == "table" then
        for name, coords in pairs(data.TeleportPoints) do
            if type(coords) == "table" and #coords >= 3 then
                CONFIG.TeleportPoints[name] = Vector3.new(coords[1], coords[2], coords[3])
            end
        end
    end
    if type(data.TPOrder) == "table" then TPOrder = data.TPOrder end
    for name in pairs(CONFIG.TeleportPoints) do
        local found = false
        for _, n in ipairs(TPOrder) do if n == name then found = true; break end end
        if not found then table.insert(TPOrder, name) end
    end
end

local function saveConfig()
    if not writefile then return end
    local s = serializeConfig()
    if s then pcall(writefile, SETTINGS_FILE, s) end
end

loadConfig()

local State = getgenv().YBA_State or {
    AutoFarmItems = false, AutoSell = false, AutoBuy = false,
    StandFarm = false, AntiAFK = false,
}
getgenv().YBA_State = State

local RunId = (getgenv().YBA_RunId or 0) + 1
getgenv().YBA_RunId = RunId
local function isActive() return getgenv().YBA_RunId == RunId end

local function teleportTo(position)
    if not position then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Human