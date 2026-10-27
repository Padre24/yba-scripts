-- ============================================================
--  YBA Multi-Tool (Madium / Executor)
--  Base: Claude + fix Venice (ordine TP) + fix soglia inventario
--  Loader consigliato nell'executor (NON qui dentro):
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/TUOUSER/yba-scripts/main/yba.lua"))()
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
--  CONFIGURAZIONE
-- ============================================================
local CONFIG = {
    LoopDelay = 0.5,
    MaxItemDistance = 5000,

    ItemNames = {
        "Mysterious Arrow",
        "Rokakaka",
        "Pure Rokakaka",
        "Lucky Arrow",
        "Diamond",
        "Gold Coin",
        "Stone Mask",
        "Dio's Diary",
        "Steel Ball",
        "Rib Cage of The Saint's Corpse",
        "Ancient Scroll",
        "Quinton's Glove",
        "Zepellin's Headband",
    },

    SellNPCNames = { "ShiftPlox", "Merchant", "Shop" },
    BuyNPCNames  = { "Isabelle", "Arrow Smith", "Shop" },

    NPCCooldown = 10,
    InventorySellThreshold = 20,

    DesiredStands = {},
    KeepOnlyShiny = false,

    TeleportPoints = {
        Spawn        = Vector3.new(0, 5, 0),
        Arcade       = Vector3.new(120, 5, 80),
        Sewers       = Vector3.new(200, -15, 200),
        Mansion      = Vector3.new(-150, 5, -120),
        Merchant     = Vector3.new(80, 5, 120),
        ArrowSmith   = Vector3.new(90, 5, 90),
        TrainStation = Vector3.new(-50, 5, 200),
        Park         = Vector3.new(-80, 5, 50),
    },
}

-- Ordine fisso per i pulsanti (fix Venice: pairs() non garantisce ordine)
local TPOrder = {
    "Spawn", "Arcade", "Sewers", "Mansion",
    "Merchant", "ArrowSmith", "TrainStation", "Park",
}

-- ============================================================
--  STATO GLOBALE
-- ============================================================
local State = getgenv().YBA_State or {
    AutoFarmItems = false,
    AutoSell = false,
    AutoBuy = false,
    StandFarm = false,
    AntiAFK = false,
}
getgenv().YBA_State = State

local RunId = (getgenv().YBA_RunId or 0) + 1
getgenv().YBA_RunId = RunId
local function isActive()
    return getgenv().YBA_RunId == RunId
end

-- ============================================================
--  FUNZIONI UTILI
-- ============================================================
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(position)
    end
end

local function getMainPart(obj)
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("Tool") then
        return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function isInsideCharacter(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    while model do
        if Players:GetPlayerFromCharacter(model) then
            return true
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return false
end

local function findItems()
    local found = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool"))
            and not Players:GetPlayerFromCharacter(obj)
            and not isInsideCharacter(obj) then
            for _, name in ipairs(CONFIG.ItemNames) do
                if obj.Name:lower():find(name:lower(), 1, true) then
                    table.insert(found, obj)
                    break
                end
            end
        end
    end
    return found
end

local function getClosestItem(items)
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closest, minDist = nil, math.huge
    for _, item in ipairs(items) do
        local part = getMainPart(item)
        if part then
            local dist = (root.Position - part.Position).Magnitude
            if dist < minDist and dist <= CONFIG.MaxItemDistance then
                minDist = dist
                closest = item
            end
        end
    end
    return closest
end

local function collectItem(item)
    if not item then return end
    local part = getMainPart(item)
    if not part then return end

    teleportTo(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.2)

    if firetouchinterest and part.Parent then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                pcall(function()
                    firetouchinterest(root, part, 0)
                    task.wait(0.1)
                    firetouchinterest(root, part, 1)
                end)
            end
        end
    end

    if item.Parent then
        local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        end
    end
end

local lastNPCInteraction = 0
local function interactWithNPC(npcNames)
    if os.clock() - lastNPCInteraction < CONFIG.NPCCooldown then
        return false
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
            for _, name in ipairs(npcNames) do
                if obj.Name:lower():find(name:lower(), 1, true) then
                    local part = getMainPart(obj)
                    if part then
                        lastNPCInteraction = os.clock()
                        teleportTo(part.Position + Vector3.new(0, 3, 0))
                        task.wait(0.5)

                        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and fireproximityprompt then
                            pcall(function() fireproximityprompt(prompt) end)
                        end

                        local cd = obj:FindFirstChildWhichIsA("ClickDetector", true)
                        if cd and fireclickdetector then
                            pcall(function() fireclickdetector(cd) end)
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- FIX: conta solo i Tool (prima contava anche il LocalScript della Backpack)
local function countInventoryItems()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local count = 0
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") then count = count + 1 end
    end
    return count
end

local function useItemFromBackpack(itemName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    -- Nome esatto prima, poi parziale (evita che "Rokakaka" prenda "Pure Rokakaka")
    local tool = backpack:FindFirstChild(itemName)
    if not (tool and tool:IsA("Tool")) then
        tool = nil
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(itemName:lower(), 1, true) then
                tool = t
                break
            end
        end
    end
    if tool then
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
                task.wait(0.2)
                tool:Activate()
                task.wait(0.5)
                return true
            end
        end
    end
    return false
end

--- Stand attuale. NB: verifica fatta dall'utente in gioco — se `YBA_Debug()` mostra nil,
--- questa funzione restituisce sempre nil e va cambiato il percorso.
local function getCurrentStand()
    local value = LocalPlayer:FindFirstChild("Stand", true)
    if value and value:IsA("StringValue") then
        return value.Value
    end
    return nil
end

local function hasDesiredStand(stand)
    if not stand or stand == "" or stand == "None" then return false end
    if CONFIG.KeepOnlyShiny and not stand:lower():find("shiny", 1, true) then
        return false
    end
    if #CONFIG.DesiredStands == 0 then return true end
    for _, wanted in ipairs(CONFIG.DesiredStands) do
        if stand:lower():find(wanted:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- ============================================================
--  GUI
-- ============================================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("YBA_MultiTool")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YBA_MultiTool"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 380)
MainFrame.Position = UDim2.new(0, 20, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Title.BorderSizePixel = 0
Title.Text = "YBA Multi-Tool"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.Font = Enum.Font.SourceSansBold
Title.Parent = MainFrame

local function createButton(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.SourceSans
    btn.Parent = MainFrame
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local y = 40
local function toggleButton(text, key)
    local btn
    btn = createButton(text .. ": OFF", y, function()
        State[key] = not State[key]
        btn.Text = text .. ": " .. (State[key] and "ON" or "OFF")
        btn.BackgroundColor3 = State[key] and Color3.fromRGB(70, 120, 70) or Color3.fromRGB(50, 50, 70)
    end)
    if State[key] then
        btn.Text = text .. ": ON"
        btn.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
    end
    y = y + 35
end

toggleButton("Auto Farm Items", "AutoFarmItems")
toggleButton("Auto Sell", "AutoSell")
toggleButton("Auto Buy", "AutoBuy")
toggleButton("Stand Farm", "StandFarm")
toggleButton("Anti-AFK", "AntiAFK")

-- Pannello teletrasporto (ordine FISSO, fix Venice)
local tpCount = #TPOrder
local tpRows = math.ceil(tpCount / 2)

local TPFrame = Instance.new("Frame")
TPFrame.Size = UDim2.new(0.9, 0, 0, 30 + tpRows * 22)
TPFrame.Position = UDim2.new(0.05, 0, 0, y + 10)
TPFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
TPFrame.BorderSizePixel = 0
TPFrame.Parent = MainFrame

MainFrame.Size = UDim2.new(0, 260, 0, y + 20 + 30 + tpRows * 22)

local TPLabel = Instance.new("TextLabel")
TPLabel.Size = UDim2.new(1, 0, 0, 20)
TPLabel.BackgroundTransparency = 1
TPLabel.Text = "Teletrasporto rapido"
TPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TPLabel.Font = Enum.Font.SourceSansBold
TPLabel.Parent = TPFrame

for i, name in ipairs(TPOrder) do
    local pos = CONFIG.TeleportPoints[name]
    if pos then
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0.45, 0, 0, 20)
        tpBtn.Position = UDim2.new(0.03 + col * 0.49, 0, 0, 25 + row * 22)
        tpBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        tpBtn.BorderSizePixel = 0
        tpBtn.Text = name
        tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpBtn.TextScaled = true
        tpBtn.Font = Enum.Font.SourceSans
        tpBtn.Parent = TPFrame
        tpBtn.MouseButton1Click:Connect(function()
            teleportTo(pos)
        end)
    end
end

-- ============================================================
--  LOOP DI AUTOMAZIONE
-- ============================================================
local function startLoop(name, delay, body)
    task.spawn(function()
        while isActive() do
            task.wait(delay)
            if not isActive() then break end
            local ok, err = pcall(body)
            if not ok then
                warn("[YBA Multi-Tool] Errore in " .. name .. ": " .. tostring(err))
            end
        end
    end)
end

startLoop("AutoFarmItems", CONFIG.LoopDelay, function()
    if not State.AutoFarmItems then return end
    local closest = getClosestItem(findItems())
    if closest then collectItem(closest) end
end)

startLoop("AutoSell", 2, function()
    if not State.AutoSell then return end
    if countInventoryItems() >= CONFIG.InventorySellThreshold then
        interactWithNPC(CONFIG.SellNPCNames)
        task.wait(1)
    end
end)

startLoop("AutoBuy", 5, function()
    if not State.AutoBuy then return end
    local hasArrow = false
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            local n = tool.Name:lower()
            if n:find("arrow", 1, true) or n:find("rokakaka", 1, true) then
                hasArrow = true
                break
            end
        end
    end
    if not hasArrow then interactWithNPC(CONFIG.BuyNPCNames) end
end)

startLoop("StandFarm", 1, function()
    if not State.StandFarm then return end

    local stand = getCurrentStand()
    if stand ~= nil and hasDesiredStand(stand) then
        State.StandFarm = false
        print("[YBA Multi-Tool] Stand desiderato: " .. stand .. ". Stand Farm OFF.")
        return
    end

    local used = false
    local hasStand = stand ~= nil and stand ~= "" and stand ~= "None"
    if hasStand then
        used = useItemFromBackpack("Rokakaka")
    else
        used = useItemFromBackpack("Mysterious Arrow") or useItemFromBackpack("Lucky Arrow")
        if not used and stand == nil then
            used = useItemFromBackpack("Rokakaka")
        end
    end

    if not used then
        interactWithNPC(CONFIG.BuyNPCNames)
    end
end)

-- Anti-AFK via Idled (più corretto del polling a timer)
LocalPlayer.Idled:Connect(function()
    if not isActive() or not State.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(), Workspace.CurrentCamera.CFrame)
end)

-- Helper diagnostico: esegui YBA_Debug() in console con lo stand evocato
getgenv().YBA_Debug = function()
    local plr = game:GetService("Players").LocalPlayer
    print("=== YBA_Debug ===")
    print("Stand (FindFirstChild 'Stand', true):", plr:FindFirstChild("Stand", true))
    print("--- LocalPlayer children ---")
    for _, c in ipairs(plr:GetChildren()) do
        local val = ""
        if c:IsA("StringValue") or c:IsA("NumberValue") or c:IsA("BoolValue") then
            val = tostring(c.Value)
        end
        print(string.format("  [%s] %s  %s", c.ClassName, c.Name, val))
    end
    print("--- Character children ---")
    if plr.Character then
        for _, c in ipairs(plr.Character:GetChildren()) do
            print(string.format("  [%s] %s", c.ClassName, c.Name))
        end
    end
    print("=== FINE YBA_Debug ===")
end

print("[YBA Multi-Tool] Caricato. Usa YBA_Debug() in console per ispezionare lo stand.")