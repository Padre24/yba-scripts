-- ============================================================
--  YBA Multi-Tool (Madium / Executor)
--  Funzionalità: Teleport, Stand/Skin Grind, Auto Item Farm,
--  Auto Sell, Auto Buy.
--  Istruzioni: incolla in autoexec o esegui dopo l'iniezione.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
--  CONFIGURAZIONE (modifica qui se necessario)
-- ============================================================
local CONFIG = {
    -- Velocità di aggiornamento dei loop (secondi)
    LoopDelay = 0.5,

    -- Distanza massima per considerare un oggetto "raggiungibile"
    MaxItemDistance = 5000,

    -- Nomi degli oggetti da raccogliere automaticamente
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

    -- Nomi degli NPC per la vendita (ShiftPlox è il mercante viaggiante)
    SellNPCNames = { "ShiftPlox", "Merchant", "Shop" },

    -- Nomi degli NPC/oggetti per l'acquisto di frecce/roka
    BuyNPCNames = { "Isabelle", "Arrow Smith", "Shop" },

    -- Soglia inventario per attivare l'auto-sell (numero di oggetti)
    InventorySellThreshold = 20,

    -- Stand da tenere durante lo stand farm (se vuoto, tiene qualsiasi)
    DesiredStands = {}, -- es: {"Star Platinum", "The World"}

    -- Se true, tiene solo stand shiny
    KeepOnlyShiny = false,

    -- Posizioni di teletrasporto predefinite (Vector3)
    -- Modifica queste coordinate in base alla mappa attuale
    TeleportPoints = {
        Spawn = Vector3.new(0, 5, 0),
        Arcade = Vector3.new(120, 5, 80),
        Sewers = Vector3.new(200, -15, 200),
        Mansion = Vector3.new(-150, 5, -120),
        Merchant = Vector3.new(80, 5, 120),
        ArrowSmith = Vector3.new(90, 5, 90),
        TrainStation = Vector3.new(-50, 5, 200),
        Park = Vector3.new(-80, 5, 50),
    },
}

-- ============================================================
--  STATO GLOBALE (persistente tra esecuzioni)
-- ============================================================
local State = getgenv().YBA_State or {
    AutoFarmItems = false,
    AutoSell = false,
    AutoBuy = false,
    StandFarm = false,
    AntiAFK = false,
    SelectedTP = "Spawn",
}
getgenv().YBA_State = State

-- ============================================================
--  FUNZIONI UTILI
-- ============================================================

--- Teletrasporta il personaggio in una posizione specifica.
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(position)
    end
end

--- Restituisce una lista di oggetti nell'workspace che corrispondono ai nomi configurati.
local function findItems()
    local found = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool") then
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

--- Trova l'oggetto più vicino al giocatore dalla lista fornita.
local function getClosestItem(items)
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closest = nil
    local minDist = math.huge

    for _, item in ipairs(items) do
        local itemPos
        if item:IsA("BasePart") then
            itemPos = item.Position
        elseif item:IsA("Model") then
            itemPos = item:GetPivot().Position
        else
            continue
        end

        local dist = (root.Position - itemPos).Magnitude
        if dist < minDist and dist <= CONFIG.MaxItemDistance then
            minDist = dist
            closest = item
        end
    end
    return closest
end

--- Raccoglie un oggetto teletrasportandosi e simulando il tocco.
local function collectItem(item)
    if not item then return end
    local pos
    if item:IsA("BasePart") then
        pos = item.Position
    elseif item:IsA("Model") then
        pos = item:GetPivot().Position
    else
        return
    end

    teleportTo(pos + Vector3.new(0, 3, 0))
    task.wait(0.2)

    -- Prova a usare firetouchinterest se disponibile
    if firetouchinterest then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                pcall(function()
                    firetouchinterest(root, item, 0)
                    task.wait(0.1)
                    firetouchinterest(root, item, 1)
                end)
            end
        end
    end

    -- Prova anche con ProximityPrompt, se presente
    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
    end
end

--- Cerca un NPC per nome e interagisce (per vendita/acquisto).
local function interactWithNPC(npcNames)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            for _, name in ipairs(npcNames) do
                if obj.Name:lower():find(name:lower(), 1, true) then
                    local pos
                    if obj:IsA("Model") then
                        pos = obj:GetPivot().Position
                    else
                        pos = obj.Position
                    end
                    teleportTo(pos + Vector3.new(0, 3, 0))
                    task.wait(0.5)

                    -- Prova ProximityPrompt
                    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and fireproximityprompt then
                        pcall(function()
                            fireproximityprompt(prompt)
                        end)
                    end

                    -- Prova ClickDetector
                    local cd = obj:FindFirstChildWhichIsA("ClickDetector", true)
                    if cd and fireclickdetector then
                        pcall(function()
                            fireclickdetector(cd)
                        end)
                    end
                    return true
                end
            end
        end
    end
    return false
end

--- Conta gli oggetti nell'inventario del giocatore (Backpack).
local function countInventoryItems()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    return #backpack:GetChildren()
end

--- Usa una freccia o una roka dall'inventario.
local function useItemFromBackpack(itemName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(itemName:lower(), 1, true) then
            -- Equipaggia e attiva
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
    end
    return false
end

-- ============================================================
--  GUI (Instance.new)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YBA_MultiTool"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 500)
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

-- Pulsanti di toggle
local y = 40
local function toggleButton(text, key)
    local btn = createButton(text .. ": OFF", y, function()
        State[key] = not State[key]
        btn.Text = text .. ": " .. (State[key] and "ON" or "OFF")
        btn.BackgroundColor3 = State[key] and Color3.fromRGB(70, 120, 70) or Color3.fromRGB(50, 50, 70)
    end)
    -- Imposta stato iniziale
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

-- Sezione teletrasporto
local TPFrame = Instance.new("Frame")
TPFrame.Size = UDim2.new(0.9, 0, 0, 120)
TPFrame.Position = UDim2.new(0.05, 0, 0, y + 10)
TPFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
TPFrame.BorderSizePixel = 0
TPFrame.Parent = MainFrame

local TPLabel = Instance.new("TextLabel")
TPLabel.Size = UDim2.new(1, 0, 0, 20)
TPLabel.BackgroundTransparency = 1
TPLabel.Text = "Teletrasporto rapido"
TPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TPLabel.Font = Enum.Font.SourceSansBold
TPLabel.Parent = TPFrame

local tpY = 25
for name, pos in pairs(CONFIG.TeleportPoints) do
    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0.45, 0, 0, 20)
    tpBtn.Position = UDim2.new(0.03, 0, 0, tpY)
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
    tpY = tpY + 22
end

-- ============================================================
--  LOOP DI AUTOMAZIONE
-- ============================================================

-- Auto Farm Items
task.spawn(function()
    while true do
        task.wait(CONFIG.LoopDelay)
        if not State.AutoFarmItems then continue end

        local items = findItems()
        local closest = getClosestItem(items)
        if closest then
            collectItem(closest)
        end
    end
end)

-- Auto Sell
task.spawn(function()
    while true do
        task.wait(2) -- controlla ogni 2 secondi
        if not State.AutoSell then continue end

        if countInventoryItems() >= CONFIG.InventorySellThreshold then
            interactWithNPC(CONFIG.SellNPCNames)
            task.wait(1)
        end
    end
end)

-- Auto Buy (frecce/roka)
task.spawn(function()
    while true do
        task.wait(5) -- meno frequente
        if not State.AutoBuy then continue end

        -- Se l'inventario è vuoto di frecce/roka, prova ad acquistare
        local hasArrow = false
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool.Name:lower():find("arrow") or tool.Name:lower():find("rokakaka") then
                    hasArrow = true
                    break
                end
            end
        end
        if not hasArrow then
            interactWithNPC(CONFIG.BuyNPCNames)
        end
    end
end)

-- Stand Farm
task.spawn(function()
    while true do
        task.wait(1)
        if not State.StandFarm then continue end

        -- Controlla se ci sono frecce/roka nell'inventario
        local used = false
        if useItemFromBackpack("Mysterious Arrow") then used = true end
        if not used and useItemFromBackpack("Rokakaka") then used = true end
        if not used and useItemFromBackpack("Lucky Arrow") then used = true end

        -- Se non ci sono, prova a comprarne
        if not used then
            interactWithNPC(CONFIG.BuyNPCNames)
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    while true do
        task.wait(60)
        if not State.AntiAFK then continue end
        -- Simula un input per evitare il disconnect per inattività
        local vu = game:GetService("VirtualUser")
        if vu then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end
    end
end)

print("[YBA Multi-Tool] Caricato. GUI pronta.")
