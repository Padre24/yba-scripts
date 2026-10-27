-- ============================================================
--  YBA Multi-Tool v8 — completo
--  Fix: sezione ItemFarm attivata PRIMA di Settings,
--  widget Settings in pcall, print avanzamento, font fix.
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

-- ============================================================
--  LISTA STAND
-- ============================================================
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

-- ============================================================
--  CONFIG
-- ============================================================
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

-- ============================================================
--  PERSISTENZA
-- ============================================================
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

-- ============================================================
--  STATO
-- ============================================================
local State = getgenv().YBA_State or {
    AutoFarmItems = false, AutoSell = false, AutoBuy = false,
    StandFarm = false, AntiAFK = false,
}
getgenv().YBA_State = State

local RunId = (getgenv().YBA_RunId or 0) + 1
getgenv().YBA_RunId = RunId
local function isActive() return getgenv().YBA_RunId == RunId end

-- ============================================================
--  UTILITY
-- ============================================================
local function teleportTo(position)
    if not position then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local target = CFrame.new(position)
    pcall(function() char:PivotTo(target) end)
    task.wait(0.05)
    if (root.Position - position).Magnitude > 5 then
        for _ = 1, 3 do
            root.CFrame = target
            RunService.Heartbeat:Wait()
        end
    end
    if (root.Position - position).Magnitude > 100 then
        pcall(function() hum:MoveTo(position) end)
    end
    task.wait(0.15)
end

local function getMainPart(obj)
    if obj:IsA("BasePart") then return obj
    elseif obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("Tool") then return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end

local function isInsideCharacter(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    while model do
        if Players:GetPlayerFromCharacter(model) then return true end
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
            local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                local part = getMainPart(obj)
                if part and part.Transparency < 1 then
                    local inRange = true
                    if CONFIG.FarmZoneRadius and CONFIG.FarmZoneRadius > 0 and CONFIG.SafeSpot then
                        inRange = (part.Position - CONFIG.SafeSpot).Magnitude <= CONFIG.FarmZoneRadius
                    end
                    if inRange then
                        for _, name in ipairs(CONFIG.ItemNames) do
                            if obj.Name:lower():find(name:lower(), 1, true) then
                                table.insert(found, obj); break
                            end
                        end
                    end
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
            local d = (root.Position - part.Position).Magnitude
            if d < minDist and d <= CONFIG.MaxItemDistance then minDist = d; closest = item end
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
local function interactWithNPC(npcNames, force)
    if not force and os.clock() - lastNPCInteraction < CONFIG.NPCCooldown then return false end
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

local function countInventoryItems()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end
    local n = 0
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") then n = n + 1 end
    end
    return n
end

local function useItemFromBackpack(itemName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    local tool = bp:FindFirstChild(itemName)
    if not (tool and tool:IsA("Tool")) then
        tool = nil
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(itemName:lower(), 1, true) then
                tool = t; break
            end
        end
    end
    if tool then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:EquipTool(tool)
                task.wait(0.2)
                tool:Activate()
                task.wait(0.5)
                return true
            end
        end
    end
    return false
end

local function findRokaTool(pure)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    local exactName = pure and "Pure Rokakaka" or "Rokakaka"
    local exact = bp:FindFirstChild(exactName)
    if exact and exact:IsA("Tool") then return exact end
    if not pure then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("rokakaka", 1, true)
                and not t.Name:lower():find("pure", 1, true) then
                return t
            end
        end
    end
    return nil
end

local function clickDialogueYes()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local gui = pg:FindFirstChild("DialogueGui")
    if not gui then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextButton") then
            local txt = (d.Text or ""):lower()
            if txt:find("yes") or txt:find("confirm") or txt:find("option1") then
                pcall(function() d:Activate() end)
                return true
            end
        end
    end
    return false
end

local function useRoka(pure)
    local roka = findRokaTool(pure)
    if not roka then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    hum:EquipTool(roka)
    task.wait(0.3)
    pcall(function() roka:Activate() end)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local gui
    local t0 = tick()
    while tick() - t0 < 3 do
        gui = pg and pg:FindFirstChild("DialogueGui")
        if gui then break end
        task.wait(0.1)
    end
    if not gui then
        local remote = char:FindFirstChild("RemoteEvent")
        if remote then pcall(function() remote:FireServer("UseItem", roka) end) end
        task.wait(1)
        return true
    end
    task.wait(0.2)
    local remote = char:FindFirstChild("RemoteEvent")
    local npcName = pure and "Pure Rokakaka" or "Rokakaka"
    if remote then
        pcall(function()
            remote:FireServer("EndDialogue", {
                NPC = npcName, Option = "Option1", Dialogue = "Dialogue2",
            })
        end)
    end
    task.wait(0.5)
    if pg and pg:FindFirstChild("DialogueGui") then clickDialogueYes() end
    return true
end

local function waitRespawn(oldChar, timeout)
    timeout = timeout or 10
    local t0 = tick()
    while tick() - t0 < timeout do
        if not isActive() then return false end
        local cur = LocalPlayer.Character
        if cur and cur ~= oldChar then task.wait(1); return true end
        task.wait(0.2)
    end
    return false
end

local function getCurrentStand()
    local stats = LocalPlayer:FindFirstChild("PlayerStats")
    if stats then
        local sn = stats:FindFirstChild("Stand")
        if sn and sn:IsA("StringValue") then return sn.Value end
    end
    return nil
end

local function hasDesiredStand(stand)
    if not stand or stand == "" or stand == "None" then return false end
    if CONFIG.KeepOnlyShiny and not stand:lower():find("shiny", 1, true) then return false end
    if #CONFIG.DesiredStands == 0 then return true end
    for _, wanted in ipairs(CONFIG.DesiredStands) do
        if stand:lower():find(wanted:lower(), 1, true) then return true end
    end
    return false
end

-- ============================================================
--  PALETTE
-- ============================================================
local C = {
    bg        = Color3.fromRGB(20, 22, 32),
    sidebar   = Color3.fromRGB(28, 30, 44),
    content   = Color3.fromRGB(34, 36, 52),
    accent    = Color3.fromRGB(72, 118, 240),
    text      = Color3.fromRGB(240, 242, 250),
    textDim   = Color3.fromRGB(140, 145, 165),
    green     = Color3.fromRGB(80, 200, 120),
    greenDim  = Color3.fromRGB(50, 140, 85),
    red       = Color3.fromRGB(230, 75, 85),
    redDim    = Color3.fromRGB(150, 50, 55),
    border    = Color3.fromRGB(48, 52, 70),
    hover     = Color3.fromRGB(44, 48, 66),
    row       = Color3.fromRGB(30, 33, 48),
    input     = Color3.fromRGB(22, 24, 36),
}

-- ============================================================
--  GUI BASE
-- ============================================================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("YBA_MultiTool")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YBA_MultiTool"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MAIN_W, MAIN_H = 560, 400
local SIDEBAR_W = 110

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
MainFrame.Position = UDim2.new(0, 80, 0, 80)
MainFrame.BackgroundColor3 = C.bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = C.sidebar
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "YBA Multi-Tool"
Title.TextColor3 = C.text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
CloseBtn.BackgroundColor3 = C.red
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = C.text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.AutoButtonColor = false
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = C.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -SIDEBAR_W, 1, -38)
Content.Position = UDim2.new(0, SIDEBAR_W, 0, 38)
Content.BackgroundColor3 = C.content
Content.BorderSizePixel = 0
Content.Parent = MainFrame

local Sections = {}
local SectionButtons = {}

local function createSection(name)
    local s = Instance.new("Frame")
    s.Name = name
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.Visible = false
    s.Parent = Content
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = s
    Sections[name] = s
    return s
end

local function selectSection(name)
    for k, v in pairs(Sections) do v.Visible = (k == name) end
    for k, btn in pairs(SectionButtons) do
        if k == name then
            btn.BackgroundColor3 = C.accent
            btn.TextColor3 = C.text
        else
            btn.BackgroundColor3 = C.sidebar
            btn.TextColor3 = C.textDim
        end
    end
end

local function makeSectionButton(name, label, yOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 40)
    btn.Position = UDim2.new(0, 6, 0, yOffset)
    btn.BackgroundColor3 = C.sidebar
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseEnter:Connect(function()
        if not Sections[name].Visible then btn.BackgroundColor3 = C.hover end
    end)
    btn.MouseLeave:Connect(function()
        if not Sections[name].Visible then btn.BackgroundColor3 = C.sidebar end
    end)
    btn.MouseButton1Click:Connect(function() selectSection(name) end)
    SectionButtons[name] = btn
    return btn
end

local function createToggleRow(parent, label, getter, setter, layoutOrder, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder or 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -70, 1, 0)
    txt.Position = UDim2.new(0, 14, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.TextColor3 = C.text
    txt.Font = Enum.Font.GothamMedium
    txt.TextSize = 14
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = row

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 44, 0, 24)
    switch.Position = UDim2.new(1, -58, 0.5, -12)
    switch.BackgroundColor3 = getter() and C.green or C.redDim
    switch.BorderSizePixel = 0
    switch.Parent = row
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = getter() and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = C.text
    knob.BorderSizePixel = 0
    knob.Parent = switch
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local v = getter()
        switch.BackgroundColor3 = v and C.green or C.redDim
        knob.Position = v and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    end

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Parent = row
    click.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh()
        if onChange then onChange() end
    end)
    return { row = row, refresh = refresh }
end

local function createActionButton(parent, text, callback, layoutOrder, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color or C.row
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.LayoutOrder = layoutOrder or 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local base = color or C.row
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = base:Lerp(Color3.new(1,1,1), 0.1)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = base}):Play()
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createNumberRow(parent, label, value, onChange, order, min, max)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 80, 0, 30)
    box.Position = UDim2.new(1, -92, 0.5, -15)
    box.BackgroundColor3 = C.input
    box.BorderSizePixel = 0
    box.Text = tostring(value)
    box.TextColor3 = C.text
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local lastValid = value
    local function commit()
        local n = tonumber(box.Text)
        if n then
            if min and n < min then n = min end
            if max and n > max then n = max end
            lastValid = n
            box.Text = tostring(n)
            onChange(n)
        else
            box.Text = tostring(lastValid)
        end
    end
    box.FocusLost:Connect(commit)
    local pending
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if pending then task.cancel(pending) end
        pending = task.delay(2, commit)
    end)
    return row
end

local function createTextareaRow(parent, label, value, onChange, order, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 120)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.textDim
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 0, (height or 120) - 32)
    box.Position = UDim2.new(0, 10, 0, 26)
    box.BackgroundColor3 = C.input
    box.BorderSizePixel = 0
    box.Text = value
    box.TextColor3 = C.text
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextWrapped = true
    box.MultiLine = true
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    local p = Instance.new("UIPadding", box)
    p.PaddingLeft = UDim.new(0, 6)
    p.PaddingRight = UDim.new(0, 6)
    p.PaddingTop = UDim.new(0, 4)
    p.PaddingBottom = UDim.new(0, 4)

    local function commit()
        local lines = {}
        for line in box.Text:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then table.insert(lines, line) end
        end
        onChange(lines)
    end
    box.FocusLost:Connect(commit)
    local pending
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if pending then task.cancel(pending) end
        pending = task.delay(2, commit)
    end)
    return row
end

-- ============================================================
--  SEZIONI
-- ============================================================
local StandFarmSec = createSection("StandFarm")
local ItemFarmSec  = createSection("ItemFarm")
local TeleportSec  = createSection("Teleport")
local NPCSec       = createSection("NPC")
local SettingsSec  = createSection("Settings")

for _, sec in ipairs({StandFarmSec, ItemFarmSec, NPCSec}) do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = sec
end

local tpg = Instance.new("UIGridLayout")
tpg.CellSize = UDim2.new(0.5, -4, 0, 34)
tpg.CellPadding = UDim.new(0, 8, 0, 8)
tpg.SortOrder = Enum.SortOrder.LayoutOrder
tpg.Parent = TeleportSec

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 6
SettingsScroll.ScrollBarImageColor3 = C.accent
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
pcall(function() SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
SettingsScroll.Parent = SettingsSec

local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 8)
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.Parent = SettingsScroll

local sp = Instance.new("UIPadding")
sp.PaddingRight = UDim.new(0, 8)
sp.Parent = SettingsScroll

makeSectionButton("StandFarm", "Stand Farm", 10)
makeSectionButton("ItemFarm",  "Item Farm",  58)
makeSectionButton("Teleport",  "Teleport",   106)
makeSectionButton("NPC",       "NPC",        154)
makeSectionButton("Settings",  "⚙ Settings", 202)
print("[YBA] Bottoni sidebar creati")

-- ============================================================
--  STAND FARM SECTION
-- ============================================================
local standCurrentLabel = Instance.new("TextLabel")
standCurrentLabel.Size = UDim2.new(1, 0, 0, 32)
standCurrentLabel.BackgroundColor3 = C.row
standCurrentLabel.BorderSizePixel = 0
standCurrentLabel.Text = "Stand attuale: ..."
standCurrentLabel.TextColor3 = C.text
standCurrentLabel.Font = Enum.Font.GothamMedium
standCurrentLabel.TextSize = 13
standCurrentLabel.LayoutOrder = 1
standCurrentLabel.Parent = StandFarmSec
Instance.new("UICorner", standCurrentLabel).CornerRadius = UDim.new(0, 8)

local standFarmToggle = createToggleRow(StandFarmSec, "Stand Farm",
    function() return State.StandFarm end,
    function(v) State.StandFarm = v end, 2)

local sfInfo = Instance.new("TextLabel")
sfInfo.Size = UDim2.new(1, 0, 0, 80)
sfInfo.BackgroundTransparency = 1
sfInfo.Text = "Rerolla con frecce/roka. Si teletrasporta al SafeSpot\n" ..
    "prima di ogni tentativo e dopo ogni respawn.\n" ..
    "Configura desiderati e SafeSpot in Settings."
sfInfo.TextColor3 = C.textDim
sfInfo.Font = Enum.Font.Gotham
sfInfo.TextSize = 11
sfInfo.TextWrapped = true
sfInfo.TextXAlignment = Enum.TextXAlignment.Left
sfInfo.TextYAlignment = Enum.TextYAlignment.Top
sfInfo.LayoutOrder = 3
sfInfo.Parent = StandFarmSec
print("[YBA] Stand Farm popolata")

-- ============================================================
--  ITEM FARM SECTION
-- ============================================================
createToggleRow(ItemFarmSec, "Auto Farm Items",
    function() return State.AutoFarmItems end,
    function(v) State.AutoFarmItems = v end, 1)

local ifInfo = Instance.new("TextLabel")
ifInfo.Size = UDim2.new(1, 0, 0, 100)
ifInfo.BackgroundTransparency = 1
ifInfo.Text = ""
ifInfo.TextColor3 = C.textDim
ifInfo.Font = Enum.Font.Gotham
ifInfo.TextSize = 11
ifInfo.TextWrapped = true
ifInfo.TextXAlignment = Enum.TextXAlignment.Left
ifInfo.TextYAlignment = Enum.TextYAlignment.Top
ifInfo.LayoutOrder = 2
ifInfo.Parent = ItemFarmSec

local function updateItemFarmInfo()
    ifInfo.Text = "Monitora " .. #CONFIG.ItemNames .. " tipi di oggetti:\n" ..
        table.concat(CONFIG.ItemNames, ", ")
end
updateItemFarmInfo()
print("[YBA] Item Farm popolata")

-- Selezione iniziale PRIMA di costruire Settings (così se Settings fallisce, UI è visibile)
selectSection("ItemFarm")
print("[YBA] Sezione ItemFarm attivata")

-- ============================================================
--  TELEPORT SECTION
-- ============================================================
local function rebuildTeleportButtons()
    for _, child in ipairs(TeleportSec:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for i, name in ipairs(TPOrder) do
        if CONFIG.TeleportPoints[name] then
            local b = createActionButton(TeleportSec, name, function()
                local p = CONFIG.TeleportPoints[name]
                if p then teleportTo(p) end
            end, i)
            b.Size = UDim2.new(1, 0, 1, 0)
        end
    end
end
rebuildTeleportButtons()
print("[YBA] Teleport popolata")

-- ============================================================
--  NPC SECTION
-- ============================================================
createToggleRow(NPCSec, "Auto Sell",
    function() return State.AutoSell end,
    function(v) State.AutoSell = v end, 1)
createToggleRow(NPCSec, "Auto Buy",
    function() return State.AutoBuy end,
    function(v) State.AutoBuy = v end, 2)
createActionButton(NPCSec, "Vendi al mercante ora", function()
    interactWithNPC(CONFIG.SellNPCNames, true)
end, 3, C.greenDim)
createActionButton(NPCSec, "Compra frecce", function()
    interactWithNPC(CONFIG.BuyNPCNames, true)
end, 4)
createActionButton(NPCSec, "Compra roka", function()
    interactWithNPC(CONFIG.BuyNPCNames, true)
end, 5)
print("[YBA] NPC popolata")

-- ============================================================
--  SETTINGS SECTION (in pcall per non bloccare il resto)
-- ============================================================
local function safeDo(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[YBA Settings] Errore in " .. name .. ": " .. tostring(err))
    end
    return ok
end

-- SafeSpot block
safeDo("SafeSpot", function()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 90)
    frame.BackgroundColor3 = C.row
    frame.BorderSizePixel = 0
    frame.LayoutOrder = 0
    frame.Parent = SettingsScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = "SafeSpot"
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local coords = Instance.new("TextLabel")
    coords.Size = UDim2.new(1, -20, 0, 18)
    coords.Position = UDim2.new(0, 10, 0, 26)
    coords.BackgroundTransparency = 1
    coords.Font = Enum.Font.Gotham
    coords.TextSize = 11
    coords.TextColor3 = C.textDim
    coords.TextXAlignment = Enum.TextXAlignment.Left
    coords.Parent = frame

    local function refreshCoords()
        local p = CONFIG.SafeSpot
        if p then
            coords.Text = string.format("(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
        else
            coords.Text = "(non impostato)"
        end
    end
    refreshCoords()

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, 50)
    btn.BackgroundColor3 = C.accent
    btn.BorderSizePixel = 0
    btn.Text = "Imposta SafeSpot dalla posizione attuale"
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        CONFIG.SafeSpot = root.Position
        CONFIG.TeleportPoints["SafeSpot"] = root.Position
        local found = false
        for _, n in ipairs(TPOrder) do if n == "SafeSpot" then found = true; break end end
        if not found then table.insert(TPOrder, "SafeSpot") end
        refreshCoords()
        rebuildTeleportButtons()
        saveConfig()
        print(string.format("[YBA] SafeSpot salvato: (%.1f, %.1f, %.1f)",
            root.Position.X, root.Position.Y, root.Position.Z))
    end)
end)

safeDo("FarmZoneRadius", function()
    createNumberRow(SettingsScroll, "Raggio farm item (0 = tutto)",
        CONFIG.FarmZoneRadius,
        function(n) CONFIG.FarmZoneRadius = n; saveConfig() end,
        1, 0, 100000)
end)

safeDo("ItemNames", function()
    createTextareaRow(SettingsScroll, "Item da farmare (uno per riga)",
        table.concat(CONFIG.ItemNames, "\n"),
        function(lines)
            if #lines > 0 then
                CONFIG.ItemNames = lines
                updateItemFarmInfo()
                saveConfig()
            end
        end, 2, 180)
end)

-- Stand selector
safeDo("StandSelector", function()
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.LayoutOrder = 3
    row.Parent = SettingsScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -110, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Stand desiderati (" .. #CONFIG.DesiredStands .. ")"
    label.TextColor3 = C.text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.Position = UDim2.new(1, -100, 0.5, -15)
    btn.BackgroundColor3 = C.accent
    btn.BorderSizePixel = 0
    btn.Text = "Seleziona"
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function openSelector()
        if ScreenGui:FindFirstChild("StandSelectorOverlay") then return end

        local overlay = Instance.new("TextButton")
        overlay.Name = "StandSelectorOverlay"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Color3.new(0, 0, 0)
        overlay.BackgroundTransparency = 0.5
        overlay.Text = ""
        overlay.AutoButtonColor = false
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 50
        overlay.Parent = ScreenGui

        local panel = Instance.new("TextButton")
        panel.Size = UDim2.new(0, 380, 0, 440)
        panel.Position = UDim2.new(0.5, -190, 0.5, -220)
        panel.BackgroundColor3 = C.bg
        panel.Text = ""
        panel.AutoButtonColor = false
        panel.BorderSizePixel = 0
        panel.ZIndex = 51
        panel.Parent = overlay
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -50, 0, 34)
        title.Position = UDim2.new(0, 14, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = "Seleziona stand desiderati"
        title.TextColor3 = C.text
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 51
        title.Parent = panel

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 26, 0, 26)
        closeBtn.Position = UDim2.new(1, -34, 0, 10)
        closeBtn.BackgroundColor3 = C.red
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = C.text
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 12
        closeBtn.AutoButtonColor = false
        closeBtn.ZIndex = 52
        closeBtn.Parent = panel
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -20, 1, -110)
        scroll.Position = UDim2.new(0, 10, 0, 48)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 6
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        pcall(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        scroll.ZIndex = 51
        scroll.Parent = panel

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 6)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = scroll

        local selected = {}
        for _, name in ipairs(CONFIG.DesiredStands) do selected[name] = true end

        for _, standName in ipairs(ALL_STANDS) do
            local cbRow = Instance.new("Frame")
            cbRow.Size = UDim2.new(1, 0, 0, 34)
            cbRow.BackgroundColor3 = C.row
            cbRow.BorderSizePixel = 0
            cbRow.Parent = scroll
            Instance.new("UICorner", cbRow).CornerRadius = UDim.new(0, 6)

            local cb = Instance.new("TextButton")
            cb.Size = UDim2.new(0, 22, 0, 22)
            cb.Position = UDim2.new(0, 8, 0.5, -11)
            cb.BackgroundColor3 = selected[standName] and C.green or C.redDim
            cb.BorderSizePixel = 0
            cb.Text = selected[standName] and "✔" or ""
            cb.TextColor3 = C.text
            cb.Font = Enum.Font.GothamBold
            cb.TextSize = 14
            cb.AutoButtonColor = false
            cb.ZIndex = 52
            cb.Parent = cbRow
            Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 4)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -50, 1, 0)
            nameLbl.Position = UDim2.new(0, 38, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = standName
            nameLbl.TextColor3 = C.text
            nameLbl.Font = Enum.Font.Gotham
            nameLbl.TextSize = 12
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.ZIndex = 52
            nameLbl.Parent = cbRow

            cb.MouseButton1Click:Connect(function()
                selected[standName] = not selected[standName]
                if selected[standName] then
                    cb.BackgroundColor3 = C.green
                    cb.Text = "✔"
                else
                    cb.BackgroundColor3 = C.redDim
                    cb.Text = ""
                end
            end)
        end

        local okBtn = Instance.new("TextButton")
        okBtn.Size = UDim2.new(0.5, -15, 0, 36)
        okBtn.Position = UDim2.new(0, 10, 1, -46)
        okBtn.BackgroundColor3 = C.accent
        okBtn.BorderSizePixel = 0
        okBtn.Text = "Conferma"
        okBtn.TextColor3 = C.text
        okBtn.Font = Enum.Font.GothamBold
        okBtn.TextSize = 12
        okBtn.AutoButtonColor = false
        okBtn.ZIndex = 52
        okBtn.Parent = panel
        Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 6)

        local cancelBtn = Instance.new("TextButton")
        cancelBtn.Size = UDim2.new(0.5, -15, 0, 36)
        cancelBtn.Position = UDim2.new(0.5, 5, 1, -46)
        cancelBtn.BackgroundColor3 = C.redDim
        cancelBtn.BorderSizePixel = 0
        cancelBtn.Text = "Annulla"
        cancelBtn.TextColor3 = C.text
        cancelBtn.Font = Enum.Font.GothamBold
        cancelBtn.TextSize = 12
        cancelBtn.AutoButtonColor = false
        cancelBtn.ZIndex = 52
        cancelBtn.Parent = panel
        Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)

        local function close() overlay:Destroy() end

        okBtn.MouseButton1Click:Connect(function()
            local finalList = {}
            for _, name in ipairs(ALL_STANDS) do
                if selected[name] then table.insert(finalList, name) end
            end
            CONFIG.DesiredStands = finalList
            label.Text = "Stand desiderati (" .. #finalList .. ")"
            saveConfig()
            close()
        end)
        cancelBtn.MouseButton1Click:Connect(close)
        closeBtn.MouseButton1Click:Connect(close)
        overlay.MouseButton1Click:Connect(close)
    end

    btn.MouseButton1Click:Connect(openSelector)
end)

safeDo("KeepOnlyShiny", function()
    createToggleRow(SettingsScroll, "Accetta solo shiny (KeepOnlyShiny)",
        function() return CONFIG.KeepOnlyShiny end,
        function(v) CONFIG.KeepOnlyShiny = v end, 4,
        function() saveConfig() end)
end)

safeDo("SogliaVendita", function()
    createNumberRow(SettingsScroll, "Soglia vendita inventario",
        CONFIG.InventorySellThreshold,
        function(n) CONFIG.InventorySellThreshold = n; saveConfig() end,
        5, 1, 200)
end)

safeDo("NPCCooldown", function()
    createNumberRow(SettingsScroll, "Cooldown NPC (secondi)",
        CONFIG.NPCCooldown,
        function(n) CONFIG.NPCCooldown = n; saveConfig() end,
        6, 0.5, 120)
end)

safeDo("LoopDelay", function()
    createNumberRow(SettingsScroll, "Loop delay (secondi)",
        CONFIG.LoopDelay,
        function(n) CONFIG.LoopDelay = n; saveConfig() end,
        7, 0.1, 5)
end)

safeDo("MaxItemDistance", function()
    createNumberRow(SettingsScroll, "Distanza massima item",
        CONFIG.MaxItemDistance,
        function(n) CONFIG.MaxItemDistance = n; saveConfig() end,
        8, 10, 100000)
end)

safeDo("SellNPCNames", function()
    createTextareaRow(SettingsScroll, "NPC vendita (uno per riga)",
        table.concat(CONFIG.SellNPCNames, "\n"),
        function(lines)
            if #lines > 0 then CONFIG.SellNPCNames = lines; saveConfig() end
        end, 9, 90)
end)

safeDo("BuyNPCNames", function()
    createTextareaRow(SettingsScroll, "NPC acquisto (uno per riga)",
        table.concat(CONFIG.BuyNPCNames, "\n"),
        function(lines)
            if #lines > 0 then CONFIG.BuyNPCNames = lines; saveConfig() end
        end, 10, 90)
end)

safeDo("AddTP", function()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 74)
    frame.BackgroundColor3 = C.row
    frame.BorderSizePixel = 0
    frame.LayoutOrder = 11
    frame.Parent = SettingsScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Aggiungi punto TP (posizione attuale)"
    lbl.TextColor3 = C.textDim
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, -100, 0, 30)
    nameBox.Position = UDim2.new(0, 10, 0, 32)
    nameBox.BackgroundColor3 = C.input
    nameBox.BorderSizePixel = 0
    nameBox.Text = ""
    nameBox.PlaceholderText = "Nome punto"
    nameBox.TextColor3 = C.text
    nameBox.PlaceholderColor3 = C.textDim
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 12
    nameBox.ClearTextOnFocus = false
    nameBox.Parent = frame
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(0, 80, 0, 30)
    addBtn.Position = UDim2.new(1, -90, 0, 32)
    addBtn.BackgroundColor3 = C.accent
    addBtn.BorderSizePixel = 0
    addBtn.Text = "Aggiungi"
    addBtn.TextColor3 = C.text
    addBtn.Font = Enum.Font.GothamBold
    addBtn.TextSize = 12
    addBtn.AutoButtonColor = false
    addBtn.Parent = frame
    Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)

    addBtn.MouseButton1Click:Connect(function()
        local name = nameBox.Text:match("^%s*(.-)%s*$")
        if name == "" then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        CONFIG.TeleportPoints[name] = root.Position
        local found = false
        for _, n in ipairs(TPOrder) do if n == name then found = true; break end end
        if not found then table.insert(TPOrder, name) end
        saveConfig()
        rebuildTeleportButtons()
        nameBox.Text = ""
    end)
end)

safeDo("RemoveTP", function()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 74)
    frame.BackgroundColor3 = C.row
    frame.BorderSizePixel = 0
    frame.LayoutOrder = 12
    frame.Parent = SettingsScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Rimuovi punto TP (per nome)"
    lbl.TextColor3 = C.textDim
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, -100, 0, 30)
    nameBox.Position = UDim2.new(0, 10, 0, 32)
    nameBox.BackgroundColor3 = C.input
    nameBox.BorderSizePixel = 0
    nameBox.Text = ""
    nameBox.PlaceholderText = "Nome punto da rimuovere"
    nameBox.TextColor3 = C.text
    nameBox.PlaceholderColor3 = C.textDim
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextSize = 12
    nameBox.ClearTextOnFocus = false
    nameBox.Parent = frame
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

    local rmBtn = Instance.new("TextButton")
    rmBtn.Size = UDim2.new(0, 80, 0, 30)
    rmBtn.Position = UDim2.new(1, -90, 0, 32)
    rmBtn.BackgroundColor3 = C.red
    rmBtn.BorderSizePixel = 0
    rmBtn.Text = "Rimuovi"
    rmBtn.TextColor3 = C.text
    rmBtn.Font = Enum.Font.GothamBold
    rmBtn.TextSize = 12
    rmBtn.AutoButtonColor = false
    rmBtn.Parent = frame
    Instance.new("UICorner", rmBtn).CornerRadius = UDim.new(0, 6)

    rmBtn.MouseButton1Click:Connect(function()
        local name = nameBox.Text:match("^%s*(.-)%s*$")
        if name == "" or not CONFIG.TeleportPoints[name] then return end
        CONFIG.TeleportPoints[name] = nil
        for i, n in ipairs(TPOrder) do
            if n == name then table.remove(TPOrder, i); break end
        end
        saveConfig()
        rebuildTeleportButtons()
        nameBox.Text = ""
    end)
end)

safeDo("Reset", function()
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = C.redDim
    btn.BorderSizePixel = 0
    btn.Text = "Ripristina tutti i default (cancella il file)"
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.LayoutOrder = 13
    btn.Parent = SettingsScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        if delfile then pcall(delfile, SETTINGS_FILE) end
        warn("[YBA Multi-Tool] Default ripristinati. Re-inietta per ricaricare.")
    end)
end)

print("[YBA] Settings popolata")

-- ============================================================
--  MINI BUTTON
-- ============================================================
local MiniBtn = Instance.new("Frame")
MiniBtn.Name = "MiniBtn"
MiniBtn.Size = UDim2.new(0, 52, 0, 52)
MiniBtn.Position = UDim2.new(0, 80, 0, 80)
MiniBtn.BackgroundColor3 = C.accent
MiniBtn.BorderSizePixel = 0
MiniBtn.Visible = false
MiniBtn.Active = true
MiniBtn.Parent = ScreenGui
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0, 14)

local miniLabel = Instance.new("TextLabel")
miniLabel.Size = UDim2.new(1, 0, 1, 0)
miniLabel.BackgroundTransparency = 1
miniLabel.Text = "YBA"
miniLabel.TextColor3 = C.text
miniLabel.Font = Enum.Font.GothamBold
miniLabel.TextSize = 14
miniLabel.Parent = MiniBtn

local function toggleMinimize()
    if not isActive() then return end
    if MainFrame.Visible then
        MainFrame.Visible = false
        MiniBtn.Visible = true
    else
        MainFrame.Visible = true
        MiniBtn.Visible = false
    end
end

local miniDragging, miniDragMoved, miniDragStart, miniStartPos = false, false, nil, nil
MiniBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniDragMoved = false
        miniDragStart = input.Position
        miniStartPos = MiniBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if miniDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - miniDragStart
        if d.Magnitude > 5 then miniDragMoved = true end
        MiniBtn.Position = UDim2.new(
            miniStartPos.X.Scale, miniStartPos.X.Offset + d.X,
            miniStartPos.Y.Scale, miniStartPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch) and miniDragging then
        miniDragging = false
        if not miniDragMoved then toggleMinimize() end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not isActive() then return end
    if input.KeyCode == Enum.KeyCode.RightControl then toggleMinimize() end
end)

-- ============================================================
--  DIALOG CHIUSURA
-- ============================================================
local dialogOpen = false
local function stopScript()
    getgenv().YBA_RunId = (getgenv().YBA_RunId or 0) + 1
    if ScreenGui then ScreenGui:Destroy() end
end

local function showCloseDialog()
    if dialogOpen then return end
    dialogOpen = true

    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.5
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.BorderSizePixel = 0
    backdrop.ZIndex = 20
    backdrop.Parent = ScreenGui

    local dlg = Instance.new("Frame")
    dlg.Size = UDim2.new(0, 300, 0, 160)
    dlg.Position = UDim2.new(0.5, -150, 0.5, -80)
    dlg.BackgroundColor3 = C.bg
    dlg.BorderSizePixel = 0
    dlg.ZIndex = 21
    dlg.Parent = ScreenGui
    Instance.new("UICorner", dlg).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", dlg)
    st.Color = C.border

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 34)
    title.Position = UDim2.new(0, 10, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Chiudere lo script?"
    title.TextColor3 = C.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.ZIndex = 21
    title.Parent = dlg

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 26)
    sub.Position = UDim2.new(0, 10, 0, 44)
    sub.BackgroundTransparency = 1
    sub.Text = "Scegli un'azione:"
    sub.TextColor3 = C.textDim
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.ZIndex = 21
    sub.Parent = dlg

    local function closeDialog()
        backdrop:Destroy()
        dlg:Destroy()
        dialogOpen = false
    end

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.5, -15, 0, 40)
    stopBtn.Position = UDim2.new(0, 10, 1, -55)
    stopBtn.BackgroundColor3 = C.red
    stopBtn.BorderSizePixel = 0
    stopBtn.Text = "Ferma script"
    stopBtn.TextColor3 = C.text
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 13
    stopBtn.AutoButtonColor = false
    stopBtn.ZIndex = 21
    stopBtn.Parent = dlg
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
    stopBtn.MouseButton1Click:Connect(function()
        closeDialog(); stopScript()
    end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0.5, -15, 0, 40)
    minBtn.Position = UDim2.new(0.5, 5, 1, -55)
    minBtn.BackgroundColor3 = C.accent
    minBtn.BorderSizePixel = 0
    minBtn.Text = "Minimizza"
    minBtn.TextColor3 = C.text
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 21
    minBtn.Parent = dlg
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
    minBtn.MouseButton1Click:Connect(function()
        closeDialog()
        MainFrame.Visible = false
        MiniBtn.Visible = true
    end)

    backdrop.MouseButton1Click:Connect(closeDialog)
end

CloseBtn.MouseButton1Click:Connect(showCloseDialog)

-- ============================================================
--  LOOP
-- ============================================================
local function startLoop(name, delay, body)
    task.spawn(function()
        while isActive() do
            task.wait(delay)
            if not isActive() then break end
            local ok, err = pcall(body)
            if not ok then warn("[YBA Multi-Tool] " .. name .. ": " .. tostring(err)) end
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
    local has = false
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            local n = t.Name:lower()
            if n:find("arrow", 1, true) or n:find("rokakaka", 1, true) then has = true; break end
        end
    end
    if not has then interactWithNPC(CONFIG.BuyNPCNames) end
end)

startLoop("StandFarm", 1.5, function()
    if not State.StandFarm then return end

    if CONFIG.SafeSpot then
        teleportTo(CONFIG.SafeSpot)
        task.wait(0.3)
    end

    local stand = getCurrentStand()
    if stand and hasDesiredStand(stand) then
        State.StandFarm = false
        standFarmToggle.refresh()
        print("[YBA] Stand desiderato già posseduto: " .. stand .. ". Stand Farm OFF.")
        return
    end

    local used = false
    local hasStand = stand and stand ~= "" and stand ~= "None"
    local oldChar = LocalPlayer.Character

    if hasStand then
        used = useRoka(false)
    else
        used = useItemFromBackpack("Mysterious Arrow")
            or useItemFromBackpack("Lucky Arrow")
    end

    if not used then
        interactWithNPC(CONFIG.BuyNPCNames)
        return
    end

    if hasStand then
        local respawned = waitRespawn(oldChar, 10)
        if respawned and CONFIG.SafeSpot then
            teleportTo(CONFIG.SafeSpot)
        end
        task.wait(0.5)
    else
        task.wait(1)
    end
end)

task.spawn(function()
    while isActive() do
        task.wait(1)
        if not isActive() then break end
        if standCurrentLabel and standCurrentLabel.Parent then
            local st = getCurrentStand()
            standCurrentLabel.Text = "Stand attuale: " ..
                ((st and st ~= "") and st or "nessuno / non rilevato")
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if not isActive() then return end
    if State.StandFarm and CONFIG.SafeSpot then
        task.wait(1.5)
        if isActive() and State.StandFarm then
            teleportTo(CONFIG.SafeSpot)
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    if not isActive() or not State.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(), Workspace.CurrentCamera.CFrame)
end)

-- ============================================================
--  DEBUG
-- ============================================================
getgenv().YBA_Debug = function()
    print("=== YBA_Debug v8 ===")
    print("writefile:", writefile ~= nil, "readfile:", readfile ~= nil, "isfile:", isfile ~= nil)
    if isfile then
        local ok, exists = pcall(isfile, SETTINGS_FILE)
        print("file exists:", ok and exists)
    end
    print("ItemNames:", #CONFIG.ItemNames)
    print("DesiredStands:", #CONFIG.DesiredStands, "->", table.concat(CONFIG.DesiredStands, ", "))
    print("KeepOnlyShiny:", CONFIG.KeepOnlyShiny)
    if CONFIG.SafeSpot then
        print(string.format("SafeSpot: (%.1f, %.1f, %.1f)",
            CONFIG.SafeSpot.X, CONFIG.SafeSpot.Y, CONFIG.SafeSpot.Z))
    else
        print("SafeSpot: nil")
    end
    print("FarmZoneRadius:", CONFIG.FarmZoneRadius)
    print("Current stand:", getCurrentStand())
    print("hasDesiredStand(current):", hasDesiredStand(getCurrentStand()))
    print("=== FINE ===")
end

print("[YBA Multi-Tool v8] Caricato. RightCtrl = minimizza. YBA_Debug() per diagnostica.")