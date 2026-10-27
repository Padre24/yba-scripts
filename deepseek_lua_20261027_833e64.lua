-- ============================================================
--  YBA Multi-Tool v2 — UI moderna
--  Fix inclusi: ordine TP fisso (Venice), conteggio Tool (mio),
--  isInsideCharacter + getMainPart + NPCCooldown (Claude)
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

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
        "Quinton's Glove", "Zepellin's Headband",
    },
    SellNPCNames = { "ShiftPlox", "Merchant", "Shop" },
    BuyNPCNames  = { "Isabelle", "Arrow Smith", "Shop" },
    NPCCooldown = 10,
    InventorySellThreshold = 20,
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

local TPOrder = {
    "Spawn", "Arcade", "Sewers", "Mansion",
    "Merchant", "ArrowSmith", "TrainStation", "Park",
}

-- ============================================================
--  STATO GLOBALE
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
--  UTILITY (invariate)
-- ============================================================
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = CFrame.new(position) end
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
            for _, name in ipairs(CONFIG.ItemNames) do
                if obj.Name:lower():find(name:lower(), 1, true) then
                    table.insert(found, obj); break
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

local function getCurrentStand()
    local v = LocalPlayer:FindFirstChild("Stand", true)
    if v and v:IsA("StringValue") then return v.Value end
    return nil
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
}

-- ============================================================
--  GUI
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

local MAIN_W, MAIN_H = 520, 360
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

-- Top bar
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

-- X button
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

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = C.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -SIDEBAR_W, 1, -38)
Content.Position = UDim2.new(0, SIDEBAR_W, 0, 38)
Content.BackgroundColor3 = C.content
Content.BorderSizePixel = 0
Content.Parent = MainFrame

-- ============================================================
--  SEZIONI + BOTTONI SIDEBAR
-- ============================================================
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

-- Helper: toggle row
local function createToggleRow(parent, label, getter, setter, layoutOrder)
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

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Parent = row
    click.MouseButton1Click:Connect(function()
        local new = not getter()
        setter(new)
        TweenService:Create(switch, TweenInfo.new(0.15), {BackgroundColor3 = new and C.green or C.redDim}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = new and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}):Play()
    end)
    return row
end

-- Helper: action button
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

-- Crea le 4 sezioni
local StandFarmSec = createSection("StandFarm")
local ItemFarmSec  = createSection("ItemFarm")
local TeleportSec  = createSection("Teleport")
local NPCSec       = createSection("NPC")

-- Lista verticale in StandFarm / ItemFarm / NPC
for _, sec in ipairs({StandFarmSec, ItemFarmSec, NPCSec}) do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = sec
end

-- Griglia 2 colonne per Teleport
local tpg = Instance.new("UIGridLayout")
tpg.CellSize = UDim2.new(0.5, -4, 0, 34)
tpg.CellPadding = UDim2.new(0, 8, 0, 8)
tpg.SortOrder = Enum.SortOrder.LayoutOrder
tpg.Parent = TeleportSec

-- Bottoni sidebar (4)
makeSectionButton("StandFarm", "Stand Farm", 10)
makeSectionButton("ItemFarm",  "Item Farm",  58)
makeSectionButton("Teleport",  "Teleport",   106)
makeSectionButton("NPC",       "NPC",        154)

-- --- Contenuto Stand Farm ---
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

createToggleRow(StandFarmSec, "Stand Farm", function() return State.StandFarm end,
    function(v) State.StandFarm = v end, 2)

local sfInfo = Instance.new("TextLabel")
sfInfo.Size = UDim2.new(1, 0, 0, 50)
sfInfo.BackgroundTransparency = 1
sfInfo.Text = "Usa automaticamente frecce/roka dall'inventario.\nSe non ne hai, prova ad acquistarle dall'NPC."
sfInfo.TextColor3 = C.textDim
sfInfo.Font = Enum.Font.Gotham
sfInfo.TextSize = 11
sfInfo.TextWrapped = true
sfInfo.TextXAlignment = Enum.TextXAlignment.Left
sfInfo.TextYAlignment = Enum.TextYAlignment.Top
sfInfo.LayoutOrder = 3
sfInfo.Parent = StandFarmSec

-- --- Contenuto Item Farm ---
createToggleRow(ItemFarmSec, "Auto Farm Items", function() return State.AutoFarmItems end,
    function(v) State.AutoFarmItems = v end, 1)

local ifInfo = Instance.new("TextLabel")
ifInfo.Size = UDim2.new(1, 0, 0, 100)
ifInfo.BackgroundTransparency = 1
ifInfo.Text = "Monitora " .. #CONFIG.ItemNames .. " tipi di oggetti:\n" ..
    table.concat(CONFIG.ItemNames, ", ")
ifInfo.TextColor3 = C.textDim
ifInfo.Font = Enum.Font.Gotham
ifInfo.TextSize = 11
ifInfo.TextWrapped = true
ifInfo.TextXAlignment = Enum.TextXAlignment.Left
ifInfo.TextYAlignment = Enum.TextYAlignment.Top
ifInfo.LayoutOrder = 2
ifInfo.Parent = ItemFarmSec

-- --- Contenuto Teleport ---
for i, name in ipairs(TPOrder) do
    local pos = CONFIG.TeleportPoints[name]
    if pos then
        local b = createActionButton(TeleportSec, name, function() teleportTo(pos) end, i)
        b.Size = UDim2.new(1, 0, 1, 0)
    end
end

-- --- Contenuto NPC ---
createToggleRow(NPCSec, "Auto Sell", function() return State.AutoSell end,
    function(v) State.AutoSell = v end, 1)
createToggleRow(NPCSec, "Auto Buy", function() return State.AutoBuy end,
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

selectSection("ItemFarm")

-- ============================================================
--  MINI BUTTON (quadratino blu draggabile)
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

-- Drag + click su MiniBtn
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

-- Right Ctrl toggle
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not isActive() then return end
    if input.KeyCode == Enum.KeyCode.RightControl then toggleMinimize() end
end)

-- ============================================================
--  DIALOG CHIUSURA (X)
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
    local s = Instance.new("UIStroke", dlg)
    s.Color = C.border

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
        closeDialog()
        stopScript()
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
--  LOOP DI AUTOMAZIONE
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

startLoop("StandFarm", 1, function()
    if not State.StandFarm then return end
    local stand = getCurrentStand()
    local hasStand = stand ~= nil and stand ~= "" and stand ~= "None"
    local used = false
    if hasStand then
        used = useItemFromBackpack("Rokakaka")
    else
        used = useItemFromBackpack("Mysterious Arrow") or useItemFromBackpack("Lucky Arrow")
        if not used then used = useItemFromBackpack("Rokakaka") end
    end
    if not used then interactWithNPC(CONFIG.BuyNPCNames) end
end)

-- Aggiorna label stand
task.spawn(function()
    while isActive() do
        task.wait(1)
        if not isActive() then break end
        if standCurrentLabel and standCurrentLabel.Parent then
            local st = getCurrentStand()
            standCurrentLabel.Text = "Stand attuale: " ..
                (st and st ~= "" and st or "nessuno / non rilevato")
        end
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if not isActive() or not State.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(), Workspace.CurrentCamera.CFrame)
end)

-- ============================================================
--  DEBUG helper
-- ============================================================
getgenv().YBA_Debug = function()
    local st = LocalPlayer:FindFirstChild("Stand", true)
    print("=== YBA_Debug ===")
    if st then
        print("Class:", st.ClassName)
        print("FullName:", st:GetFullName())
        if st:IsA("StringValue") then print("Value:", st.Value) end
    else
        print("Stand: nil")
    end
    print("getCurrentStand() ->", getCurrentStand())
    print("=== FINE ===")
end

print("[YBA Multi-Tool v2] Caricato. RightCtrl = minimizza/espandi.")