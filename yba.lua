-- ============================================================
--  YBA Multi-Tool (Madium / Executor)
--  Funzionalità: Teleport, Stand/Skin Grind, Auto Item Farm,
--  Auto Sell, Auto Buy.
--  Istruzioni: incolla in autoexec o esegui dopo l'iniezione.
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

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

    -- Secondi minimi tra due interazioni con un NPC (evita teleport a raffica)
    NPCCooldown = 10,

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

-- Ogni esecuzione ha un proprio ID: i loop di un'esecuzione precedente
-- vedono che l'ID è cambiato e si fermano (prima si duplicavano).
local RunId = (getgenv().YBA_RunId or 0) + 1
getgenv().YBA_RunId = RunId
local function isActive()
    return getgenv().YBA_RunId == RunId
end

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

--- Restituisce la BasePart "principale" di un oggetto (BasePart, Model o Tool).
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

--- True se l'oggetto appartiene al personaggio di un giocatore (incluso il nostro).
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

--- Restituisce una lista di oggetti nell'workspace che corrispondono ai nomi configurati.
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

--- Trova l'oggetto più vicino al giocatore dalla lista fornita.
local function getClosestItem(items)
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closest = nil
    local minDist = math.huge

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

--- Raccoglie un oggetto teletrasportandosi e simulando il tocco.
local function collectItem(item)
    if not item then return end
    local part = getMainPart(item)
    if not part then return end

    teleportTo(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.2)

    -- Prova a usare firetouchinterest se disponibile (richiede una BasePart, non un Model)
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

    -- Prova anche con ProximityPrompt, se presente
    if item.Parent then
        local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and fireproximityprompt then
            pcall(function()
                fireproximityprompt(prompt)
            end)
        end
    end
end

--- Cerca un NPC per nome e interagisce (per vendita/acquisto).
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
    -- Nome esatto prima ("Rokakaka" non deve prendere "Pure Rokakaka"), poi parziale
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
        do
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

--- Prova a leggere lo stand attuale. Il percorso dipende dal gioco:
--- cerca uno StringValue chiamato "Stand" sotto LocalPlayer. Restituisce nil se non trovato.
local function getCurrentStand()
    local value = LocalPlayer:FindFirstChild("Stand", true)
    if value and value:IsA("StringValue") then
        return value.Value
    end
    return nil
end

--- True se lo stand attuale soddisfa CONFIG.DesiredStands / KeepOnlyShiny.
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
--  GUI (Instance.new)
-- ============================================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Rimuove la GUI di un'esecuzione precedente
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

-- Pulsanti di toggle
local y = 40
local function toggleButton(text, key)
    -- "btn" va dichiarato prima: la callback lo usa
    local btn
    btn = createButton(text .. ": OFF", y, function()
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

-- Sezione teletrasporto (due colonne)
local tpCount = 0
for _ in pairs(CONFIG.TeleportPoints) do tpCount = tpCount + 1 end
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

local tpIndex = 0
for name, pos in pairs(CONFIG.TeleportPoints) do
    local col = tpIndex % 2
    local row = math.floor(tpIndex / 2)
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
        State.SelectedTP = name
        teleportTo(pos)
    end)
    tpIndex = tpIndex + 1
end

-- ============================================================
--  LOOP DI AUTOMAZIONE
-- ============================================================

--- Avvia un loop che si ferma quando lo script viene rieseguito.
--- Gli errori vengono stampati invece di uccidere il loop.
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

-- Auto Farm Items
startLoop("AutoFarmItems", CONFIG.LoopDelay, function()
    if not State.AutoFarmItems then return end

    local items = findItems()
    local closest = getClosestItem(items)
    if closest then
        collectItem(closest)
    end
end)

-- Auto Sell
startLoop("AutoSell", 2, function()
    if not State.AutoSell then return end

    if countInventoryItems() >= CONFIG.InventorySellThreshold then
        interactWithNPC(CONFIG.SellNPCNames)
        task.wait(1)
    end
end)

-- Auto Buy (frecce/roka)
startLoop("AutoBuy", 5, function()
    if not State.AutoBuy then return end

    -- Se l'inventario è vuoto di frecce/roka, prova ad acquistare
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
    if not hasArrow then
        interactWithNPC(CONFIG.BuyNPCNames)
    end
end)

-- Stand Farm
startLoop("StandFarm", 1, function()
    if not State.StandFarm then return end

    local stand = getCurrentStand()
    if stand ~= nil and hasDesiredStand(stand) then
        -- Stand desiderato ottenuto: ferma il farm
        State.StandFarm = false
        print("[YBA Multi-Tool] Stand ottenuto: " .. stand .. ". Stand Farm disattivato.")
        return
    end

    local used = false
    local hasStand = stand ~= nil and stand ~= "" and stand ~= "None"
    if hasStand then
        -- Con uno stand indesiderato serve prima una Rokakaka (non Pure) per rimuoverlo
        used = useItemFromBackpack("Rokakaka")
    else
        used = useItemFromBackpack("Mysterious Arrow") or useItemFromBackpack("Lucky Arrow")
        if not used and stand == nil then
            -- Stand sconosciuto: comportamento originale
            used = useItemFromBackpack("Rokakaka")
        end
    end

    -- Se non ci sono, prova a comprarne (con cooldown)
    if not used then
        interactWithNPC(CONFIG.BuyNPCNames)
    end
end)

-- Anti-AFK: Roblox emette Idled dopo ~2 minuti di inattività
LocalPlayer.Idled:Connect(function()
    if not isActive() or not State.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(), Workspace.CurrentCamera.CFrame)
end)

print("[YBA Multi-Tool] Caricato. GUI pronta.")
