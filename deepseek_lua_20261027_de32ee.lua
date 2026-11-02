-- ============================================================
--  YBA Multi-Tool — CoolUI + bypass anti-tp
--  • Bypass: Reset + Kick + Returner + Client anti-cheat
--  • Info: sezione default con dettagli
--  • Farm: 3 bottoni (Stand / Item / Requiem)
--  • Teleport: ShiftPlox, SunoTheArrowsmith, FangTheNegotiator
--  • RightCtrl: collassa/espandi (quadratino draggabile)
-- ============================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
--  PARTE 1: BYPASS ANTI-TP
-- ============================================================
local bypassInfo = {
    nameKey      = nil,
    namecallOk   = false,
    clientHooked = false,
}

local function _searchTable(t, target)
    for _, v in pairs(t) do
        if tostring(v) == target then return true end
    end
    return false
end

-- 1) Chiave Returner da getgc
do
    local ok, gc = pcall(getgc, true)
    if ok and type(gc) == "table" then
        for i = #gc, 1, -1 do
            if type(gc[i]) == "table" then
                local a = rawget(gc[i], "A")
                if a and type(a) == "table" and #a > 2 then
                    bypassInfo.nameKey = a[2]
                    break
                end
            end
        end
    end
end

-- 2) Hook __namecall: Returner + Reset + Kick
do
    local ok = pcall(function()
        local oldNC
        oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local args = {...}
            local m = getnamecallmethod()
            if not checkcaller() then
                if m == "InvokeServer" and tostring(self) == "Returner" and args[1] == "idklolbrah2de" then
                    return bypassInfo.nameKey or " ___XP DE KEY"
                end
                if (m == "InvokeServer" or m == "FireServer") and args[1] == "Reset" then
                    return
                end
                if m == "Kick" then
                    return
                end
            end
            return oldNC(self, ...)
        end))
    end)
    bypassInfo.namecallOk = ok
end

-- 3) Sospendi funzione Client anti-cheat
do
    local ok, gc = pcall(getgc)
    if ok and type(gc) == "table" then
        for _, v in pairs(gc) do
            if type(v) == "function" then
                local ok1, script = pcall(function() return getfenv(v).script end)
                if ok1 and tostring(script) == "Client" then
                    local ok2, protos = pcall(debug.getprotos, v)
                    if ok2 and #protos == 7 then
                        local ok3, upvals = pcall(debug.getupvalues, v)
                        if ok3 and _searchTable(upvals, "RemoteEvent") then
                            local ok4 = pcall(hookfunction, v, function() return task.wait(9e9) end)
                            bypassInfo.clientHooked = ok4
                            break
                        end
                    end
                end
            end
        end
    end
end

print(string.format("[BYPASS] namecall=%s, clientHook=%s, key=%s",
    tostring(bypassInfo.namecallOk), tostring(bypassInfo.clientHooked),
    tostring(bypassInfo.nameKey)))

-- ============================================================
--  PARTE 2: TELEPORT HELPER
-- ============================================================
local function teleportTo(pos)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

-- ============================================================
--  PARTE 3: CoolUI (adattata)
-- ============================================================
local THEME = {
    Accent      = Color3.fromRGB(124, 92, 255),
    AccentB     = Color3.fromRGB(64, 196, 255),
    Background  = Color3.fromRGB(18, 20, 28),
    BackgroundB = Color3.fromRGB(12, 13, 19),
    Panel       = Color3.fromRGB(30, 33, 45),
    PanelHover  = Color3.fromRGB(42, 46, 63),
    Track       = Color3.fromRGB(46, 51, 68),
    Stroke      = Color3.fromRGB(58, 64, 86),
    Text        = Color3.fromRGB(236, 238, 245),
    SubText     = Color3.fromRGB(148, 155, 176),
    Font        = Enum.Font.Gotham,
    FontMedium  = Enum.Font.GothamMedium,
    FontBold    = Enum.Font.GothamBold,
    Corner      = 10,
}

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in props or {} do (inst :: any)[k] = v end
    for _, c in children or {} do c.Parent = inst end
    return inst
end
local function corner(r) return create("UICorner", { CornerRadius = UDim.new(0, r or THEME.Corner) }) end
local function stroke(color, thickness, transparency)
    return create("UIStroke", {
        Color = color or THEME.Stroke, Thickness = thickness or 1,
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end
local function gradient(a, b, rot)
    return create("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 0 })
end
local function pad(all)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
        PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
    })
end
local function tween(o, t, g) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), g):Play() end
local function iconButton(symbol)
    local b = create("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.3,
        AutoButtonColor = false, BorderSizePixel = 0,
        Text = symbol, Font = THEME.FontBold, TextSize = 15, TextColor3 = THEME.SubText,
    }, { corner(8) })
    b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0, TextColor3 = THEME.Text }) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0.3, TextColor3 = THEME.SubText }) end)
    return b
end

local Tab = {}
Tab.__index = Tab
local UILib = {}
UILib.__index = UILib

function UILib:_select(tab)
    for _, t in self.tabs do
        local on = (t == tab)
        t.content.Visible = on
        t.indicator.Visible = on
        tween(t.button, 0.15, { BackgroundTransparency = on and 0 or 0.4 })
        tween(t.label, 0.15, { TextColor3 = on and THEME.Text or THEME.SubText })
    end
    self.activeTab = tab
end

function UILib:AddTab(name)
    local button = create("TextButton", {
        Name = name, Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.4,
        AutoButtonColor = false, BorderSizePixel = 0, Text = "",
        LayoutOrder = #self.tabs + 1, Parent = self.sidebar,
    }, { corner(8) })
    local indicator = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 18), BorderSizePixel = 0, Visible = false,
        Parent = button,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(THEME.Accent, THEME.AccentB, 90) })
    local label = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1, Text = name, Font = THEME.FontMedium,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.SubText, Parent = button,
    })
    local content = create("ScrollingFrame", {
        Name = name .. "Page", Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = THEME.Accent,
        ScrollBarImageTransparency = 0.2, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
        Parent = self.contentContainer,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        pad(14),
    })
    local tab = setmetatable({ name = name, button = button, indicator = indicator, label = label, content = content, _order = 0 }, Tab)
    button.MouseButton1Click:Connect(function() self:_select(tab) end)
    button.MouseEnter:Connect(function()
        if self.activeTab ~= tab then tween(button, 0.15, { BackgroundTransparency = 0.15 }) end
    end)
    button.MouseLeave:Connect(function()
        if self.activeTab ~= tab then tween(button, 0.15, { BackgroundTransparency = 0.4 }) end
    end)
    table.insert(self.tabs, tab)
    if not self.activeTab then self:_select(tab) end
    return tab
end

function UILib.new(titleText)
    local self = setmetatable({}, UILib)
    self.tabs = {}
    self.activeTab = nil

    local gui = create("ScreenGui", {
        Name = "YBA_MultiTool", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, Parent = playerGui,
    })
    self.gui = gui

    local window = create("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(540, 380),
        BackgroundColor3 = THEME.Background, BorderSizePixel = 0, Parent = gui,
    }, { corner(14), gradient(THEME.Background, THEME.BackgroundB, 90) })
    self.window = window
    create("UIStroke", { Color = THEME.Accent, Thickness = 1.5, Transparency = 0.45, Parent = window },
        { gradient(THEME.Accent, THEME.AccentB, 35) })

    local titleBar = create("Frame", {
        Name = "TitleBar", Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.35,
        BorderSizePixel = 0, Parent = window,
    }, { corner(14) })
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.35,
        BorderSizePixel = 0, Parent = titleBar,
    })
    local titleContent = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = titleBar,
    }, { pad(14) })
    create("Frame", {
        Name = "Dot", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, Parent = titleContent,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), gradient(THEME.Accent, THEME.AccentB, 45) })
    create("TextLabel", {
        Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -110, 1, 0),
        BackgroundTransparency = 1, Text = titleText or "Menu",
        Font = THEME.FontBold, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Text,
        Parent = titleContent,
    }, { gradient(THEME.Accent, THEME.AccentB, 0) })

    local icons = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(62, 28), BackgroundTransparency = 1, Parent = titleContent,
    }, {
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local minBtn = iconButton("—"); minBtn.LayoutOrder, minBtn.Parent = 1, icons
    local closeBtn = iconButton("✕"); closeBtn.LayoutOrder, closeBtn.Parent = 2, icons

    local body = create("Frame", {
        Name = "Body", Position = UDim2.new(0, 0, 0, 46),
        Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, Parent = window,
    })
    self.body = body

    self.sidebar = create("Frame", {
        Name = "Sidebar", Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = THEME.Background, BackgroundTransparency = 0.35,
        BorderSizePixel = 0, Parent = body,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        pad(12),
    })
    create("Frame", {
        Position = UDim2.new(0, 150, 0, 0), Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = THEME.Stroke, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, Parent = body,
    })
    self.contentContainer = create("Frame", {
        Name = "Content", Position = UDim2.new(0, 151, 0, 0),
        Size = UDim2.new(1, -151, 1, 0), BackgroundTransparency = 1, Parent = body,
    })

    -- Drag window
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- Quadratino mini draggabile
    local mini = create("Frame", {
        Name = "Mini", AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(56, 56),
        Position = window.Position,
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0, Visible = false, Active = true,
        Parent = gui,
    }, { corner(14) })
    create("UIStroke", { Color = THEME.AccentB, Thickness = 1.5, Transparency = 0.2, Parent = mini },
        { gradient(THEME.Accent, THEME.AccentB, 45) })
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "YBA", Font = THEME.FontBold, TextSize = 14,
        TextColor3 = THEME.Text, Parent = mini,
    })

    local miniDragging, miniMoved, miniStart, miniStartPos = false, false, nil, nil
    mini.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            miniDragging, miniMoved = true, false
            miniStart, miniStartPos = input.Position, mini.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if miniDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - miniStart
            if d.Magnitude > 5 then miniMoved = true end
            mini.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + d.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if miniDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            miniDragging = false
            if not miniMoved then
                mini.Visible = false
                window.Visible = true
            end
        end
    end)

    local function toggleMini()
        if window.Visible then
            mini.Position = window.Position
            window.Visible = false
            mini.Visible = true
        else
            mini.Visible = false
            window.Visible = true
        end
    end

    minBtn.MouseButton1Click:Connect(toggleMini)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            if not gui.Enabled then
                gui.Enabled = true
                window.Visible = true
                mini.Visible = false
            else
                toggleMini()
            end
        end
    end)

    return self
end

-- ============================================================
--  CONTROLS
-- ============================================================
function Tab:_next() self._order += 1; return self._order end

function Tab:AddSection(text)
    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        LayoutOrder = self:_next(), Parent = self.content,
    })
    create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = string.upper(text), Font = THEME.FontBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.SubText,
        Parent = holder,
    })
    return holder
end

function Tab:AddLabel(text)
    return create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = text, Font = THEME.Font, TextSize = 13,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.SubText, LayoutOrder = self:_next(), Parent = self.content,
    })
end

function Tab:AddButton(text, callback)
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = THEME.Panel,
        AutoButtonColor = false, BorderSizePixel = 0,
        Text = text, Font = THEME.FontMedium, TextSize = 14,
        TextColor3 = THEME.Text, LayoutOrder = self:_next(), Parent = self.content,
    }, { corner(8), stroke(THEME.Stroke, 1, 0.3) })
    btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.PanelHover }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.Panel }) end)
    btn.MouseButton1Down:Connect(function() tween(btn, 0.08, { BackgroundColor3 = THEME.Accent }) end)
    btn.MouseButton1Up:Connect(function() tween(btn, 0.15, { BackgroundColor3 = THEME.PanelHover }) end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)
    return btn
end

-- ============================================================
--  BUILD MENU
-- ============================================================
local Menu = UILib.new("YBA Multi-Tool")

-- Info (default)
local info = Menu:AddTab("Info")
info:AddSection("Benvenuto")
info:AddLabel("YBA Multi-Tool — versione bypass.\n\n" ..
    "RightCtrl: collassa a quadratino (draggabile).\n" ..
    "Clicca il quadratino per riaprire.\n" ..
    "Trascina la barra del titolo per spostare la finestra.")

info:AddSection("Stato bypass")
info:AddLabel(string.format(
    "Returner key: %s\n__namecall hook: %s\nClient anti-cheat: %s",
    bypassInfo.nameKey and "trovata" or "fallback",
    bypassInfo.namecallOk and "attivo" or "FALLITO",
    bypassInfo.clientHooked and "sospeso" or "non trovato"
))

info:AddSection("Sezioni")
info:AddLabel("• Farm — Stand / Item / Requiem\n" ..
    "• Teleport — NPC principali")

-- Farm
local farm = Menu:AddTab("Farm")
farm:AddSection("Farming")
farm:AddLabel("Tutte le funzioni sono in sviluppo. Per ora i pulsanti sono segnaposto.")
farm:AddButton("Stand Farm", function()
    print("[Farm] Stand Farm — da implementare")
end)
farm:AddButton("Item Farm", function()
    print("[Farm] Item Farm — da implementare")
end)
farm:AddButton("Requiem Stand Farm", function()
    print("[Farm] Requiem Stand Farm — da implementare")
end)

-- Teleport
local tp = Menu:AddTab("Teleport")
tp:AddSection("NPC")
tp:AddButton("ShiftPlox", function()
    teleportTo(Vector3.new(-700.1, -25.4, -332.9))
end)
tp:AddButton("SunoTheArrowsmith", function()
    teleportTo(Vector3.new(-665.0, 16.2, -305.9))
end)
tp:AddButton("FangTheNegotiator", function()
    teleportTo(Vector3.new(511.9, 2.1, -41.6))
end)

print("[UI] Caricata. Bypass attivo. RightCtrl per minimizzare.")
