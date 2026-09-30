-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  ☣️  INFECTION GUI  |  Corrupted Farm & Kill  |  by xdar4k       ║
-- ║  ✅ Авто-фарм деревьев (Small / Big Corrupted Tree)              ║
-- ║  ✅ Авто-фарм волков (Corrupted Wolf / Alpha Wolf)               ║
-- ║  ✅ ESP Highlight + Circle                                       ║
-- ║  ✅ Слайдеры: задержка / целей за раз                            ║
-- ║  ✅ ТП на HOME при пустом мире (1 раз за цикл)                   ║
-- ║  ✅ Счётчики: Chopped / Killed  |  RightShift = GUI              ║
-- ║  💾 AUTO-SAVE: Автоматическое сохранение и загрузка настроек     ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- очистка предыдущего запуска
pcall(function()
    local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("INFECTION_GUI")
    if g then g:Destroy() end
end)
pcall(function()
    local c = workspace:FindFirstChild("CFCircle")
    if c then c:Destroy() end
end)

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local HttpService= game:GetService("HttpService")

local player  = Players.LocalPlayer
local inv     = player:WaitForChild("Inventory")
local foliage = workspace:WaitForChild("Map"):WaitForChild("Foliage")

-- ── СИСТЕМА СОХРАНЕНИЯ НАСТРОЕК (CONFIG AUTO-SAVE) ──────────────────
local CONFIG_FILE = "InfectionGui_Config.json"
local SavedSettings = {}
local autoRestoreList = {}

local function LoadSettings()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(decoded) == "table" then
                SavedSettings = decoded
            end
        end
    end)
end

local function SaveSettings()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(SavedSettings))
        end
    end)
end

LoadSettings()

-- ── конфиг ──────────────────────────────────────────────────────────
local DELAY       = 0.5
local MAX_TARGETS = 3
local farming     = false
local killing     = false
local chopped     = 0
local killed      = 0
local farmBig     = false
local farmSmall   = true
local HITS_SMALL  = 2
local HITS_BIG    = 20
local circleOn    = true

local HOME_POS     = Vector3.new(0, 5, 0)
local tpedHomeTree = false
local tpedHomeWolf = false

-- ── оружие ──────────────────────────────────────────────────────────
local WEAPONS = {
    "Morning star", "Hellish Sword", "Obsidion Hammer", "Spear", "Katana",
    "Laser Sword", "Ice Sword", "Trident", "Poison Spear", "Strong Axe",
    "King - Cultist Mace", "Old Axe", "Good Axe", "Ice axe",
    "Vampire Scythe", "Hair"
}
local cachedWeapon = nil

local function getWeapon()
    if cachedWeapon and inv:FindFirstChild(cachedWeapon.Name) then
        return cachedWeapon
    end
    for _, name in ipairs(WEAPONS) do
        local w = inv:FindFirstChild(name)
        if w then cachedWeapon = w; return w end
    end
    return nil
end

local function equipWeapon()
    local w = getWeapon()
    if w then
        pcall(function()
            RS.RemoteEvents.EquipItemHandle:FireServer("FireAllClients", w)
        end)
    end
end

-- ── утилиты ─────────────────────────────────────────────────────────
local function getPos(t)
    if not t then return nil end
    local ok, result = pcall(function()
        if t:IsA("BasePart") then return t.Position end
        if t:IsA("Model") then
            if t.PrimaryPart then return t.PrimaryPart.Position end
            for _, c in pairs(t:GetChildren()) do
                if c:IsA("BasePart") then return c.Position end
            end
        end
    end)
    return ok and result or nil
end

local function isAlive(t)
    return t ~= nil and t.Parent ~= nil
end

local function tpTo(pos)
    if not pos then return end
    pcall(function()
        local ch = player.Character
        local hr = ch and ch:FindFirstChild("HumanoidRootPart")
        if hr then
            local yRot = select(2, hr.CFrame:ToEulerAnglesYXZ())
            hr.CFrame = CFrame.new(pos + Vector3.new(3, 0, 0)) * CFrame.Angles(0, yRot, 0)
        end
    end)
end

local function tpHomeTree()
    if tpedHomeTree then return end
    tpedHomeTree = true
    pcall(function()
        local ch = player.Character
        local hr = ch and ch:FindFirstChild("HumanoidRootPart")
        if hr then hr.CFrame = CFrame.new(HOME_POS) end
    end)
end

local function tpHomeWolf()
    if tpedHomeWolf then return end
    tpedHomeWolf = true
    pcall(function()
        local ch = player.Character
        local hr = ch and ch:FindFirstChild("HumanoidRootPart")
        if hr then hr.CFrame = CFrame.new(HOME_POS) end
    end)
end

local function hit(t, w)
    local ch = player.Character
    if not ch then return end
    local hr = ch:FindFirstChild("HumanoidRootPart")
    if not hr then return end
    pcall(function()
        local head = ch:FindFirstChild("Head")
        if head then
            RS.RemoteEvents.RequestReplicateSound:FireServer(
                "FireAllClients", "WeaponHit",
                {Instance = head, Volume = 0.4}
            )
        end
        RS.RemoteEvents.ToolDamageObject:InvokeServer(
            t, w, "1_10928695084", hr.CFrame, false
        )
    end)
end

-- ── кэш мира ────────────────────────────────────────────────────────
local treeCache = {small = {}, big = {}}
local wolfCache = {}
local lastScan  = 0

local function scanWorld()
    local now = tick()
    if now - lastScan < 1 then return end
    lastScan = now
    local small, big, wolves = {}, {}, {}
    for _, v in pairs(foliage:GetChildren()) do
        local name = v.Name
        local p    = getPos(v)
        if not p then continue end
        if name == "Corrupted Small Tree" then
            table.insert(small, {obj = v, pos = p})
        elseif name:find("Corrupted Tree") then
            table.insert(big, {obj = v, pos = p})
        end
    end
    for _, v in pairs(workspace.Characters:GetChildren()) do
        local name = v.Name
        if name == "Corrupted Wolf" or name == "Corrupted Alpha Wolf" then
            local p = getPos(v)
            if p then table.insert(wolves, {obj = v, pos = p}) end
        end
    end
    treeCache.small = small
    treeCache.big   = big
    wolfCache       = wolves
end

-- ── ESP ─────────────────────────────────────────────────────────────
local espList = {}

local function clearESP()
    for _, e in pairs(espList) do pcall(function() e:Destroy() end) end
    espList = {}
end

local function addESP(obj, color)
    local e = Instance.new("Highlight")
    e.FillColor           = color
    e.FillTransparency    = 0.6
    e.OutlineColor        = Color3.fromRGB(192, 132, 252)
    e.OutlineTransparency = 0
    e.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    e.Adornee             = obj
    e.Parent              = workspace
    table.insert(espList, e)
end

-- ── Circle ESP ──────────────────────────────────────────────────────
local circle       = Instance.new("Part")
circle.Name        = "CFCircle"
circle.Shape       = Enum.PartType.Cylinder
circle.Size        = Vector3.new(1300, 0.1, 1300)
circle.Color       = Color3.fromRGB(80, 40, 120)
circle.Transparency = 0.85
circle.Anchored    = true
circle.CanCollide  = false
circle.CastShadow  = false
circle.Material    = Enum.Material.ForceField
circle.Parent      = workspace

-- ════════════════════════════════════════════════════════════════════
--  ☣️  GUI
-- ════════════════════════════════════════════════════════════════════
local C = {
    BG     = Color3.fromRGB(6, 4, 10),
    PANEL  = Color3.fromRGB(14, 9, 22),
    PANEL2 = Color3.fromRGB(20, 14, 32),
    HEADER = Color3.fromRGB(10, 6, 16),
    ACCENT = Color3.fromRGB(120, 60, 200),
    NEON_G = Color3.fromRGB(0, 210, 90),
    NEON_R = Color3.fromRGB(255, 60, 60),
    NEON_Y = Color3.fromRGB(255, 208, 0),
    NEON_P = Color3.fromRGB(180, 60, 255),
    NEON_C = Color3.fromRGB(0, 220, 216),
    NEON_O = Color3.fromRGB(249, 115, 22),
    WHITE  = Color3.fromRGB(230, 220, 245),
    GRAY   = Color3.fromRGB(100, 90, 120),
    BLACK  = Color3.fromRGB(0, 0, 0),
}

local WW, WH       = 310, 510
local HEADER_H     = 44
local TAB_H        = 36
local GuiOpen      = false
local minimized    = false
local ActiveTab    = "FARM"
local TabScrolls   = {}
local TabBtns      = {}

local function New(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Tw(o, p, d, st, dir)
    st  = st  or Enum.EasingStyle.Quart
    dir = dir or Enum.EasingDirection.Out
    TweenSvc:Create(o, TweenInfo.new(d, st, dir), p):Play()
end

local function Clamp(v, mn, mx)
    return math.max(mn, math.min(mx, v))
end

-- ── ScreenGui ──────────────────────────────────────────────────────
local ScreenGui = New("ScreenGui", {
    Name           = "INFECTION_GUI",
    ResetOnSpawn   = false,
    IgnoreGuiInset = true,
    DisplayOrder   = 999,
}, player.PlayerGui)

-- ── Кнопка открытия ────────────────────────────────────────────────
local ToggleFrame = New("Frame", {
    Size             = UDim2.new(0, 54, 0, 54),
    Position         = UDim2.new(0, 16, 0, 16),
    BackgroundColor3 = C.BG,
    BorderSizePixel  = 0,
    ZIndex           = 500,
    Active           = true,
}, ScreenGui)
New("UICorner", {CornerRadius = UDim.new(0, 14)}, ToggleFrame)
New("UIStroke", {Color = C.NEON_G, Thickness = 2.5}, ToggleFrame)
New("TextLabel", {
    Size                   = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text                   = "☣",
    TextSize               = 24,
    Font                   = Enum.Font.GothamBold,
    ZIndex                 = 502,
}, ToggleFrame)
local TDot = New("Frame", {
    Size             = UDim2.new(0, 10, 0, 10),
    Position         = UDim2.new(1, -4, 0, -4),
    BackgroundColor3 = C.NEON_G,
    BorderSizePixel  = 0,
    ZIndex           = 504,
}, ToggleFrame)
New("UICorner", {CornerRadius = UDim.new(1, 0)}, TDot)

-- ── Основное окно ──────────────────────────────────────────────────
local WinFrame = New("Frame", {
    Name                   = "WinFrame",
    Size                   = UDim2.new(0, WW, 0, WH),
    Position               = UDim2.new(0, 0, 0, 0),
    BackgroundColor3       = C.BG,
    BorderSizePixel        = 0,
    ClipsDescendants       = true,
    ZIndex                 = 200,
    Visible                = false,
    Active                 = true,
    BackgroundTransparency = 1,
}, ScreenGui)
New("UICorner", {CornerRadius = UDim.new(0, 16)}, WinFrame)
New("UIStroke", {Color = C.ACCENT, Thickness = 2}, WinFrame)

-- ── Шапка ──────────────────────────────────────────────────────────
local Header = New("Frame", {
    Size             = UDim2.new(1, 0, 0, HEADER_H),
    BackgroundColor3 = C.HEADER,
    BorderSizePixel  = 0,
    ZIndex           = 210,
    Active           = true,
}, WinFrame)
New("UICorner", {CornerRadius = UDim.new(0, 16)}, Header)

local RecDot = New("Frame", {
    Size             = UDim2.new(0, 8, 0, 8),
    Position         = UDim2.new(0, 14, 0.5, -4),
    BackgroundColor3 = C.NEON_G,
    BorderSizePixel  = 0,
    ZIndex           = 213,
}, Header)
New("UICorner", {CornerRadius = UDim.new(1, 0)}, RecDot)

New("TextLabel", {
    Size                   = UDim2.new(1, -120, 1, 0),
    Position               = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "☣ INFECTION | Corrupted Farm",
    TextColor3             = C.WHITE,
    Font                   = Enum.Font.GothamBold,
    TextSize               = 11,
    TextXAlignment         = Enum.TextXAlignment.Left,
    ZIndex                 = 212,
}, Header)

New("TextLabel", {
    Size                   = UDim2.new(0, 66, 0, 18),
    Position               = UDim2.new(1, -102, 0.5, -9),
    BackgroundColor3       = Color3.fromRGB(20, 12, 34),
    BorderSizePixel        = 0,
    Text                   = "RightShift",
    TextColor3             = C.GRAY,
    Font                   = Enum.Font.Code,
    TextSize               = 9,
    TextXAlignment         = Enum.TextXAlignment.Center,
    ZIndex                 = 213,
}, Header)

local ContentHolder = New("Frame", {
    Name                   = "ContentHolder",
    Size                   = UDim2.new(1, 0, 1, -HEADER_H),
    Position               = UDim2.new(0, 0, 0, HEADER_H),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 201,
    ClipsDescendants       = true,
}, WinFrame)

local MinBtn = New("TextButton", {
    Size             = UDim2.new(0, 26, 0, 26),
    Position         = UDim2.new(1, -64, 0.5, -13),
    BackgroundColor3 = Color3.fromRGB(60, 30, 100),
    BorderSizePixel  = 0,
    Text             = "-",
    TextColor3       = C.WHITE,
    Font             = Enum.Font.GothamBold,
    TextSize         = 14,
    AutoButtonColor  = false,
    ZIndex           = 215,
}, Header)
New("UICorner", {CornerRadius = UDim.new(0, 6)}, MinBtn)

local CloseBtn = New("TextButton", {
    Size             = UDim2.new(0, 26, 0, 26),
    Position         = UDim2.new(1, -32, 0.5, -13),
    BackgroundColor3 = Color3.fromRGB(100, 30, 160),
    BorderSizePixel  = 0,
    Text             = "X",
    TextColor3       = C.WHITE,
    Font             = Enum.Font.GothamBold,
    TextSize         = 12,
    AutoButtonColor  = false,
    ZIndex           = 215,
}, Header)
New("UICorner", {CornerRadius = UDim.new(0, 6)}, CloseBtn)

MinBtn.Activated:Connect(function()
    minimized = not minimized
    ContentHolder.Visible = not minimized
    if minimized then
        Tw(WinFrame, {Size = UDim2.new(0, WW, 0, HEADER_H)}, 0.22,
           Enum.EasingStyle.Back, Enum.EasingDirection.In)
    else
        Tw(WinFrame, {Size = UDim2.new(0, WW, 0, WH)}, 0.28,
           Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end
end)

-- ── Перетаскивание шапки ───────────────────────────────────────────
local dragging, dragOffX, dragOffY, dragType = false, 0, 0, nil
Header.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    dragging = true; dragType = inp.UserInputType
    dragOffX = inp.Position.X - WinFrame.AbsolutePosition.X
    dragOffY = inp.Position.Y - WinFrame.AbsolutePosition.Y
end)
UIS.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local vp = ScreenGui.AbsoluteSize
    WinFrame.Position = UDim2.new(0,
        Clamp(inp.Position.X - dragOffX, 0, vp.X - WW), 0,
        Clamp(inp.Position.Y - dragOffY, 0, vp.Y - WH))
end)
UIS.InputEnded:Connect(function(inp)
    if dragging and inp.UserInputType == dragType then dragging = false end
end)

-- ── Вкладки ────────────────────────────────────────────────────────
local TABS = {
    {id = "FARM", label = "ДЕРЕВЬЯ",   color = C.NEON_G},
    {id = "WOLF", label = "ВОЛКИ",     color = C.NEON_R},
    {id = "CFG",  label = "НАСТРОЙКИ",color = C.NEON_P},
}

local TabBar = New("Frame", {
    Size             = UDim2.new(1, 0, 0, TAB_H),
    BackgroundColor3 = C.PANEL,
    BorderSizePixel  = 0,
    ZIndex           = 220,
}, ContentHolder)

local TabLine = New("Frame", {
    Size             = UDim2.new(1 / #TABS, -6, 0, 3),
    Position         = UDim2.new(0, 3, 1, -3),
    BackgroundColor3 = C.NEON_G,
    BorderSizePixel  = 0,
    ZIndex           = 224,
}, TabBar)
New("UICorner", {CornerRadius = UDim.new(1, 0)}, TabLine)

local ContentArea = New("Frame", {
    Size                   = UDim2.new(1, 0, 1, -TAB_H),
    Position               = UDim2.new(0, 0, 0, TAB_H),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ZIndex                 = 205,
    ClipsDescendants       = true,
}, ContentHolder)

local function MakeScroll(tabId, color, vis)
    local sc = New("ScrollingFrame", {
        Name                 = "Scroll_" .. tabId,
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 4,
        ScrollBarImageColor3 = color,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ZIndex               = 206,
        Visible              = vis,
    }, ContentArea)
    New("UIListLayout", {
        SortOrder           = Enum.SortOrder.LayoutOrder,
        Padding             = UDim.new(0, 5),
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, sc)
    New("UIPadding", {
        PaddingTop    = UDim.new(0, 7),
        PaddingLeft   = UDim.new(0, 7),
        PaddingRight  = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 7),
    }, sc)
    TabScrolls[tabId] = sc
    return sc
end

local scFarm = MakeScroll("FARM", C.NEON_G, true)
local scWolf = MakeScroll("WOLF", C.NEON_R, false)
local scCfg  = MakeScroll("CFG",  C.NEON_P, false)

local SwitchTab
SwitchTab = function(id)
    if id == ActiveTab then return end
    if TabScrolls[ActiveTab] then TabScrolls[ActiveTab].Visible = false end
    for _, t in ipairs(TABS) do
        if TabBtns[t.id] then TabBtns[t.id].TextColor3 = C.GRAY end
    end
    ActiveTab = id
    if TabScrolls[id] then TabScrolls[id].Visible = true end
    for i, t in ipairs(TABS) do
        if t.id == id then
            if TabBtns[t.id] then TabBtns[t.id].TextColor3 = t.color end
            local f = 1 / #TABS
            Tw(TabLine, {
                Position         = UDim2.new((i - 1) * f, 3, 1, -3),
                Size             = UDim2.new(f, -6, 0, 3),
                BackgroundColor3 = t.color,
            }, 0.26)
            break
        end
    end
end

for i, tab in ipairs(TABS) do
    local f  = 1 / #TABS
    local tb = New("TextButton", {
        Size                   = UDim2.new(f, 0, 1, 0),
        Position               = UDim2.new((i - 1) * f, 0, 0, 0),
        BackgroundTransparency = 1,
        Text                   = tab.label,
        TextColor3             = i == 1 and tab.color or C.GRAY,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 9,
        AutoButtonColor        = false,
        ZIndex                 = 223,
    }, TabBar)
    TabBtns[tab.id] = tb
    local id = tab.id
    tb.Activated:Connect(function() SwitchTab(id) end)
end

-- ── Вспомогательные виджеты ────────────────────────────────────────
local function Divider(p, txt, ord)
    local d = New("Frame", {
        Size                   = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        ZIndex                 = 207,
        LayoutOrder            = ord,
    }, p)
    New("TextLabel", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "-- " .. txt .. " --",
        TextColor3             = C.GRAY,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 9,
        TextXAlignment         = Enum.TextXAlignment.Center,
        ZIndex                 = 208,
    }, d)
end

local function Toggle(p, txt, color, ord, cb)
    local row = New("Frame", {
        Size             = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.PANEL2,
        BorderSizePixel  = 0,
        ZIndex           = 207,
        LayoutOrder      = ord,
    }, p)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, row)
    New("TextLabel", {
        Size                   = UDim2.new(1, -64, 1, 0),
        Position               = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text                   = txt,
        TextColor3             = color,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 11,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 208,
    }, row)
    local track = New("Frame", {
        Size             = UDim2.new(0, 42, 0, 20),
        Position         = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(40, 28, 55),
        BorderSizePixel  = 0,
        ZIndex           = 208,
    }, row)
    New("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
    local thumb = New("Frame", {
        Size             = UDim2.new(0, 16, 0, 16),
        Position         = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = C.GRAY,
        BorderSizePixel  = 0,
        ZIndex           = 209,
    }, track)
    New("UICorner", {CornerRadius = UDim.new(1, 0)}, thumb)
    local state = false
    local btn = New("TextButton", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        AutoButtonColor        = false,
        ZIndex                 = 210,
    }, row)
    local function setState(s)
        state = s
        if s then
            Tw(thumb, {Position = UDim2.new(0, 23, 0.5, -8), BackgroundColor3 = color}, 0.18)
            Tw(track, {BackgroundColor3 = Color3.fromRGB(30, 20, 50)}, 0.18)
        else
            Tw(thumb, {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = C.GRAY}, 0.18)
            Tw(track, {BackgroundColor3 = Color3.fromRGB(40, 28, 55)}, 0.18)
        end
        SavedSettings[txt] = state
        SaveSettings()
        if cb then cb(s) end
    end
    btn.Activated:Connect(function() setState(not state) end)

    table.insert(autoRestoreList, function()
        if SavedSettings[txt] == true then
            setState(true)
        end
    end)

    return setState
end

local function Btn(p, txt, color, ord, cb)
    local b = New("TextButton", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.PANEL,
        BorderSizePixel  = 0,
        Text             = txt,
        TextColor3       = color,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        AutoButtonColor  = false,
        ZIndex           = 207,
        LayoutOrder      = ord,
    }, p)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, b)
    New("UIStroke", {Color = color, Thickness = 1.5, Transparency = 0.4}, b)
    b.MouseEnter:Connect(function()
        Tw(b, {BackgroundColor3 = color}, 0.14)
        b.TextColor3 = C.BLACK
    end)
    b.MouseLeave:Connect(function()
        Tw(b, {BackgroundColor3 = C.PANEL}, 0.14)
        b.TextColor3 = color
    end)
    if cb then b.Activated:Connect(cb) end
    return b
end

local function BtnRow(p, ord, leftTxt, leftCol, leftCb, rightTxt, rightCol, rightCb)
    local row = New("Frame", {
        Size                   = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        ZIndex                 = 207,
        LayoutOrder            = ord,
    }, p)
    local function makeHalf(txt, col, cb, xPos)
        local b = New("TextButton", {
            Size             = UDim2.new(0.5, -3, 1, 0),
            Position         = UDim2.new(xPos, xPos == 0 and 0 or 3, 0, 0),
            BackgroundColor3 = C.PANEL,
            BorderSizePixel  = 0,
            Text             = txt,
            TextColor3       = col,
            Font             = Enum.Font.GothamBold,
            TextSize         = 10,
            AutoButtonColor  = false,
            ZIndex           = 208,
        }, row)
        New("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
        New("UIStroke", {Color = col, Thickness = 1.2, Transparency = 0.5}, b)
        b.MouseEnter:Connect(function()
            Tw(b, {BackgroundColor3 = col}, 0.12)
            b.TextColor3 = C.BLACK
        end)
        b.MouseLeave:Connect(function()
            Tw(b, {BackgroundColor3 = C.PANEL}, 0.12)
            b.TextColor3 = col
        end)
        if cb then b.Activated:Connect(cb) end
        return b
    end
    local bL = makeHalf(leftTxt,  leftCol,  leftCb,  0)
    local bR = makeHalf(rightTxt, rightCol, rightCb, 0.5)
    return bL, bR
end

local function Slider(p, txt, color, minV, maxV, defV, ord, cb, dispFn)
    if SavedSettings[txt] ~= nil then
        defV = SavedSettings[txt]
        if cb then cb(defV) end
    end

    local row = New("Frame", {
        Size             = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = C.PANEL2,
        BorderSizePixel  = 0,
        ZIndex           = 207,
        LayoutOrder      = ord,
    }, p)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, row)
    New("TextLabel", {
        Size                   = UDim2.new(1, -74, 0, 22),
        Position               = UDim2.new(0, 11, 0, 4),
        BackgroundTransparency = 1,
        Text                   = txt,
        TextColor3             = color,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 11,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 208,
    }, row)
    local valLbl = New("TextLabel", {
        Size                   = UDim2.new(0, 62, 0, 22),
        Position               = UDim2.new(1, -70, 0, 4),
        BackgroundTransparency = 1,
        Text                   = dispFn and dispFn(defV) or tostring(defV),
        TextColor3             = color,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 11,
        TextXAlignment         = Enum.TextXAlignment.Right,
        ZIndex                 = 208,
    }, row)
    local track = New("Frame", {
        Size             = UDim2.new(1, -22, 0, 6),
        Position         = UDim2.new(0, 11, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 30, 70),
        BorderSizePixel  = 0,
        ZIndex           = 208,
    }, row)
    New("UICorner", {CornerRadius = UDim.new(0, 3)}, track)
    local pct  = (defV - minV) / (maxV - minV)
    local fill = New("Frame", {
        Size             = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel  = 0,
        ZIndex           = 209,
    }, track)
    New("UICorner", {CornerRadius = UDim.new(0, 3)}, fill)
    local handle = New("TextButton", {
        Size             = UDim2.new(0, 13, 0, 13),
        Position         = UDim2.new(pct, -6, 0.5, -6),
        BackgroundColor3 = color,
        Text             = "",
        BorderSizePixel  = 0,
        ZIndex           = 210,
        AutoButtonColor  = false,
    }, track)
    New("UICorner", {CornerRadius = UDim.new(1, 0)}, handle)
    local sd = false
    handle.MouseButton1Down:Connect(function() sd = true end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = false end
    end)
    local function applyX(xPos)
        local tw = track.AbsoluteSize.X
        if tw <= 0 then return end
        local p2  = math.clamp((xPos - track.AbsolutePosition.X) / tw, 0, 1)
        local val = math.floor(minV + p2 * (maxV - minV))
        fill.Size       = UDim2.new(p2, 0, 1, 0)
        handle.Position = UDim2.new(p2, -6, 0.5, -6)
        valLbl.Text     = dispFn and dispFn(val) or tostring(val)
        SavedSettings[txt] = val
        SaveSettings()
        if cb then cb(val) end
    end
    UIS.InputChanged:Connect(function(i)
        if not sd then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        applyX(i.Position.X)
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        applyX(i.Position.X)
    end)
end

local function StatusBox(p, lines, ord)
    local h = 10 + #lines * 17
    local f = New("Frame", {
        Size             = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = Color3.fromRGB(10, 6, 20),
        BorderSizePixel  = 0,
        ZIndex           = 207,
        LayoutOrder      = ord,
    }, p)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, f)
    New("UIStroke", {Color = C.ACCENT, Thickness = 1, Transparency = 0.6}, f)
    local lbls = {}
    for i, l in ipairs(lines) do
        local lbl = New("TextLabel", {
            Size                   = UDim2.new(1, -14, 0, 15),
            Position               = UDim2.new(0, 7, 0, 5 + (i - 1) * 17),
            BackgroundTransparency = 1,
            Text                   = l.text,
            TextColor3             = l.color or C.GRAY,
            Font                   = Enum.Font.GothamBold,
            TextSize               = 9,
            TextXAlignment         = Enum.TextXAlignment.Left,
            ZIndex                 = 208,
        }, f)
        lbls[i] = lbl
    end
    return f, lbls
end

-- ════════════════════════════════════════════════════════════════════
--  ВКЛАДКА: ДЕРЕВЬЯ
-- ════════════════════════════════════════════════════════════════════
Divider(scFarm, "СТАТУС", 1)
local _, stLbls = StatusBox(scFarm, {
    {text = "ДЕРЕВЬЯ: ВЫКЛ",             color = C.NEON_G},
    {text = "ЦЕЛЬ: нет",                 color = C.GRAY},
    {text = "СРУБЛЕНО: 0  УБИТО: 0",     color = C.NEON_Y},
    {text = "SMALL: 0  BIG: 0  ВОЛК: 0", color = Color3.fromRGB(80, 70, 100)},
}, 2)
local stTrees   = stLbls[1]
local stTarget  = stLbls[2]
local stChopped = stLbls[3]
local stFound   = stLbls[4]

Divider(scFarm, "ТИП ДЕРЕВЬЕВ", 3)
local farmSmallOn = true
local farmBigOn   = false

local smallBtn, bigBtn = BtnRow(scFarm, 4,
    "Small: ВКЛ",  C.NEON_G, nil,
    "Big:   ВЫКЛ", C.GRAY,   nil)

local function setSmallState(s)
    farmSmallOn = s
    if farmSmallOn then
        smallBtn.Text       = "Small: ВКЛ"
        smallBtn.TextColor3 = C.NEON_G
        Tw(smallBtn, {BackgroundColor3 = Color3.fromRGB(0, 40, 18)}, 0.14)
    else
        smallBtn.Text       = "Small: ВЫКЛ"
        smallBtn.TextColor3 = C.GRAY
        Tw(smallBtn, {BackgroundColor3 = C.PANEL}, 0.14)
    end
    farmSmall = farmSmallOn
    SavedSettings["FarmSmallTree"] = farmSmallOn
    SaveSettings()
end

local function setBigState(s)
    farmBigOn = s
    if farmBigOn then
        bigBtn.Text       = "Big:   ВКЛ"
        bigBtn.TextColor3 = C.NEON_O
        Tw(bigBtn, {BackgroundColor3 = Color3.fromRGB(40, 16, 0)}, 0.14)
    else
        bigBtn.Text       = "Big:   ВЫКЛ"
        bigBtn.TextColor3 = C.GRAY
        Tw(bigBtn, {BackgroundColor3 = C.PANEL}, 0.14)
    end
    farmBig = farmBigOn
    SavedSettings["FarmBigTree"] = farmBigOn
    SaveSettings()
end

smallBtn.Activated:Connect(function()
    setSmallState(not farmSmallOn)
end)

bigBtn.Activated:Connect(function()
    setBigState(not farmBigOn)
end)

table.insert(autoRestoreList, function()
    if SavedSettings["FarmSmallTree"] ~= nil then
        setSmallState(SavedSettings["FarmSmallTree"])
    end
    if SavedSettings["FarmBigTree"] ~= nil then
        setBigState(SavedSettings["FarmBigTree"])
    end
end)

Divider(scFarm, "УПРАВЛЕНИЕ", 5)
local bFarmStart, bFarmStop = BtnRow(scFarm, 6,
    "▶ ДЕРЕВЬЯ ВКЛ", C.NEON_G, nil,
    "■ СТОП",        C.NEON_R, nil)

Divider(scFarm, "ИНФО", 7)
do
    local inf = New("Frame", {
        Size             = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Color3.fromRGB(8, 18, 10),
        BorderSizePixel  = 0,
        ZIndex           = 207,
        LayoutOrder      = 8,
    }, scFarm)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, inf)
    New("UIStroke", {Color = C.NEON_G, Thickness = 1, Transparency = 0.7}, inf)
    New("TextLabel", {
        Size                   = UDim2.new(1, -14, 1, 0),
        Position               = UDim2.new(0, 7, 0, 0),
        BackgroundTransparency = 1,
        Text                   = "Small = 2 удара  |  Big = 20 ударов  |  "
                               .. "Нет деревьев → ТП на HOME  |  "
                               .. "ESP: фиолет=Small, оранжев=Big",
        TextColor3             = Color3.fromRGB(40, 100, 50),
        Font                   = Enum.Font.Gotham,
        TextSize               = 9,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextWrapped            = true,
        ZIndex                 = 208,
    }, inf)
end

-- ════════════════════════════════════════════════════════════════════
--  ВКЛАДКА: ВОЛКИ
-- ════════════════════════════════════════════════════════════════════
Divider(scWolf, "СТАТУС", 1)
local _, wstLbls = StatusBox(scWolf, {
    {text = "ВОЛКИ: ВЫКЛ", color = C.NEON_R},
    {text = "ЦЕЛЬ: нет",   color = C.GRAY},
    {text = "УБИТО: 0",    color = C.NEON_Y},
    {text = "ВОЛКОВ: 0",   color = Color3.fromRGB(80, 70, 100)},
}, 2)
local wstWolves = wstLbls[1]
local wstTarget = wstLbls[2]
local wstKilled = wstLbls[3]
local wstFound  = wstLbls[4]

Divider(scWolf, "УПРАВЛЕНИЕ", 3)
local bWolfStart, bWolfStop = BtnRow(scWolf, 4,
    "▶ ВОЛКИ ВКЛ", C.NEON_R, nil,
    "■ СТОП",      C.GRAY,   nil)

Divider(scWolf, "ЦЕЛИ", 5)
Toggle(scWolf, "Corrupted Wolf",       C.NEON_R, 6, nil)
Toggle(scWolf, "Corrupted Alpha Wolf", C.NEON_R, 7, nil)

Divider(scWolf, "ИНФО", 8)
do
    local inf2 = New("Frame", {
        Size             = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Color3.fromRGB(18, 6, 6),
        BorderSizePixel  = 0,
        ZIndex           = 207,
        LayoutOrder      = 9,
    }, scWolf)
    New("UICorner", {CornerRadius = UDim.new(0, 10)}, inf2)
    New("UIStroke", {Color = C.NEON_R, Thickness = 1, Transparency = 0.7}, inf2)
    New("TextLabel", {
        Size                   = UDim2.new(1, -14, 1, 0),
        Position               = UDim2.new(0, 7, 0, 0),
        BackgroundTransparency = 1,
        Text                   = "Фарм до смерти (макс 500 ударов)  |  "
                               .. "Нет волков → ТП на HOME  |  ESP: красный",
        TextColor3             = Color3.fromRGB(100, 40, 40),
        Font                   = Enum.Font.Gotham,
        TextSize               = 9,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextWrapped            = true,
        ZIndex                 = 208,
    }, inf2)
end

-- ════════════════════════════════════════════════════════════════════
--  ВКЛАДКА: НАСТРОЙКИ
-- ════════════════════════════════════════════════════════════════════
Divider(scCfg, "ЦЕЛЕЙ ЗА РАЗ", 1)
Slider(scCfg, "Целей за раз", C.NEON_G, 1, 10, 3, 2,
    function(v) MAX_TARGETS = v end,
    function(v) return tostring(v) end)

Divider(scCfg, "ЗАДЕРЖКА УДАРОВ", 3)
Slider(scCfg, "Задержка (сек)", C.NEON_Y, 1, 20, 5, 4,
    function(v) DELAY = v / 10 end,
    function(v) return string.format("%.1fс", v / 10) end)

Divider(scCfg, "HOME ПОЗИЦИЯ", 5)
StatusBox(scCfg, {
    {text = "X=0  Y=5  Z=0",                     color = C.NEON_C},
    {text = "ТП при отсутствии целей (1 раз)",   color = C.GRAY},
}, 6)

Divider(scCfg, "ESP КРУГ", 7)
Toggle(scCfg, "Радиус-круг (ForceField)", C.NEON_C, 8,
    function(on)
        circleOn = on
        circle.Transparency = on and 0.85 or 1
    end)

-- ════════════════════════════════════════════════════════════════════
--  ЛОГИКА ФАРМА
-- ════════════════════════════════════════════════════════════════════

-- ── Деревья: логика старта и остановки ────────────────────────────
local startFarmTrees, stopFarmTrees

startFarmTrees = function()
    if farming then return end
    farming      = true
    tpedHomeTree = false
    SavedSettings["AutoFarmTrees"] = true
    SaveSettings()
    Tw(bFarmStart, {BackgroundColor3 = Color3.fromRGB(0, 60, 28)}, 0.15)
    task.spawn(function()
        equipWeapon()
        task.wait(0.3)
        while farming do
            scanWorld()
            stFound.Text = "SMALL:" .. #treeCache.small
                        .. " BIG:"  .. #treeCache.big
                        .. " ВОЛК:" .. #wolfCache
            local list = {}
            if farmSmall and #treeCache.small > 0 then
                list = treeCache.small
            elseif farmBig and #treeCache.big > 0 then
                list = treeCache.big
            end
            if #list == 0 then
                stTarget.Text = "ЖДУ ДЕРЕВЬЕВ..."
                clearESP()
                tpHomeTree()
                task.wait(2)
                continue
            end
            tpedHomeTree = false
            local count = math.min(MAX_TARGETS, #list)
            clearESP()
            for i = 1, count do
                if isAlive(list[i].obj) then
                    addESP(list[i].obj,
                        list[i].obj.Name:find("Small")
                        and Color3.fromRGB(150, 0, 255)
                        or  Color3.fromRGB(255, 100, 0))
                end
            end
            for i = 1, count do
                if not farming then break end
                local t = list[i]
                if not isAlive(t.obj) then continue end
                tpTo(t.pos)
                task.wait(0.1)
                stTarget.Text = "ЦЕЛЬ " .. i .. "/" .. count
                local w = getWeapon()
                if not w then
                    equipWeapon()
                    task.wait(0.3)
                    w = getWeapon()
                end
                if not w then continue end
                local isBig      = not t.obj.Name:find("Small")
                local hitsNeeded = isBig and HITS_BIG or HITS_SMALL
                for _ = 1, hitsNeeded do
                    if not farming or not isAlive(t.obj) then break end
                    if isBig and farmSmall then
                        scanWorld()
                        if #treeCache.small > 0 then break end
                    end
                    w = getWeapon()
                    if not w then break end
                    hit(t.obj, w)
                    task.wait(DELAY)
                end
                if not isAlive(t.obj) then
                    chopped = chopped + 1
                    stChopped.Text = "СРУБЛЕНО:" .. chopped .. " УБИТО:" .. killed
                end
            end
            clearESP()
            stTarget.Text = "ЦЕЛЬ: нет"
            task.wait(0.05)
        end
        Tw(bFarmStart, {BackgroundColor3 = C.PANEL}, 0.15)
    end)
end

stopFarmTrees = function()
    farming = false
    SavedSettings["AutoFarmTrees"] = false
    SaveSettings()
    clearESP()
    stTarget.Text = "ЦЕЛЬ: нет"
    stTrees.Text  = "ДЕРЕВЬЯ: ВЫКЛ"
    Tw(bFarmStart, {BackgroundColor3 = C.PANEL}, 0.15)
end

bFarmStart.Activated:Connect(startFarmTrees)
bFarmStop.Activated:Connect(stopFarmTrees)

-- ── Волки: логика старта и остановки ──────────────────────────────
local startKillWolves, stopKillWolves

startKillWolves = function()
    if killing then return end
    killing      = true
    tpedHomeWolf = false
    SavedSettings["AutoKillWolves"] = true
    SaveSettings()
    Tw(bWolfStart, {BackgroundColor3 = Color3.fromRGB(60, 10, 10)}, 0.15)
    task.spawn(function()
        equipWeapon()
        task.wait(0.3)
        while killing do
            scanWorld()
            local wolves = wolfCache
            wstFound.Text = "ВОЛКОВ: " .. #wolves
            stFound.Text  = "SMALL:" .. #treeCache.small
                         .. " BIG:"  .. #treeCache.big
                         .. " ВОЛК:" .. #wolves
            if #wolves == 0 then
                wstTarget.Text = "ЖДУ ВОЛКОВ..."
                tpHomeWolf()
                task.wait(2)
                continue
            end
            tpedHomeWolf = false
            for i, wobj in ipairs(wolves) do
                if not killing then break end
                if not isAlive(wobj.obj) then continue end
                tpTo(wobj.pos)
                task.wait(0.1)
                addESP(wobj.obj, Color3.fromRGB(255, 0, 0))
                wstTarget.Text = "ЦЕЛЬ " .. i .. "/" .. #wolves
                local hits = 0
                while killing and isAlive(wobj.obj) and hits < 500 do
                    local wpn = getWeapon()
                    if not wpn then
                        equipWeapon()
                        task.wait(0.3)
                        wpn = getWeapon()
                    end
                    if not wpn then break end
                    hit(wobj.obj, wpn)
                    hits = hits + 1
                    task.wait(DELAY)
                end
                if not isAlive(wobj.obj) then
                    killed = killed + 1
                    wstKilled.Text = "УБИТО: " .. killed
                    stChopped.Text = "СРУБЛЕНО:" .. chopped .. " УБИТО:" .. killed
                end
                clearESP()
            end
            wstTarget.Text = "ЦЕЛЬ: нет"
            task.wait(0.05)
        end
        Tw(bWolfStart, {BackgroundColor3 = C.PANEL}, 0.15)
    end)
end

stopKillWolves = function()
    killing = false
    SavedSettings["AutoKillWolves"] = false
    SaveSettings()
    clearESP()
    wstTarget.Text = "ЦЕЛЬ: нет"
    wstWolves.Text = "ВОЛКИ: ВЫКЛ"
    Tw(bWolfStart, {BackgroundColor3 = C.PANEL}, 0.15)
end

bWolfStart.Activated:Connect(startKillWolves)
bWolfStop.Activated:Connect(stopKillWolves)

-- ── Автозапуск сохраненных режимов ────────────────────────────────
table.insert(autoRestoreList, function()
    if SavedSettings["AutoFarmTrees"] == true then
        startFarmTrees()
    end
    if SavedSettings["AutoKillWolves"] == true then
        startKillWolves()
    end
end)

-- ── Переключение GUI ──────────────────────────────────────────────
local function ToggleGui()
    GuiOpen = not GuiOpen
    if GuiOpen then
        local vp = ScreenGui.AbsoluteSize
        WinFrame.Position = UDim2.new(0,
            math.floor((vp.X - WW) / 2), 0,
            math.floor((vp.Y - WH) / 2))
        WinFrame.Size                   = UDim2.new(0, WW * 0.88, 0, WH * 0.88)
        WinFrame.BackgroundTransparency = 1
        WinFrame.Visible                = true
        ContentHolder.Visible           = not minimized
        TweenSvc:Create(WinFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, WW, 0, minimized and HEADER_H or WH),
             BackgroundTransparency = 0}):Play()
    else
        TweenSvc:Create(WinFrame,
            TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Size = UDim2.new(0, WW * 0.88, 0, WH * 0.88),
             BackgroundTransparency = 1}):Play()
        task.delay(0.23, function()
            if not GuiOpen then WinFrame.Visible = false end
        end)
    end
end

CloseBtn.Activated:Connect(ToggleGui)

-- Перетаскивание кнопки-тоггла
local tbDrag, tbMoved, tbDragType = false, false, nil
local tbOffX, tbOffY = 0, 0
local ToggleHit = New("TextButton", {
    Size                   = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text                   = "",
    AutoButtonColor        = false,
    ZIndex                 = 503,
}, ToggleFrame)
ToggleHit.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    tbDrag = true; tbMoved = false; tbDragType = inp.UserInputType
    tbOffX = inp.Position.X - ToggleFrame.AbsolutePosition.X
    tbOffY = inp.Position.Y - ToggleFrame.AbsolutePosition.Y
end)
UIS.InputChanged:Connect(function(inp)
    if not tbDrag then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    tbMoved = true
    local vp = ScreenGui.AbsoluteSize
    ToggleFrame.Position = UDim2.new(0,
        Clamp(inp.Position.X - tbOffX, 0, vp.X - 54), 0,
        Clamp(inp.Position.Y - tbOffY, 0, vp.Y - 54))
end)
UIS.InputEnded:Connect(function(inp)
    if tbDrag and inp.UserInputType == tbDragType then
        tbDrag = false
        if not tbMoved then ToggleGui() end
    end
end)

UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then ToggleGui() end
end)

-- ── Heartbeat ────────────────────────────────────────────────────
local renderTick = 0
local recAcc, recOn = 0, true
RunService.Heartbeat:Connect(function(dt)
    local now = tick()
    if now - renderTick >= 0.5 then
        renderTick = now
        pcall(function()
            local ch = player.Character
            local hr = ch and ch:FindFirstChild("HumanoidRootPart")
            if hr and circleOn then
                circle.CFrame = hr.CFrame * CFrame.new(0, -3.5, 0)
            end
            local active = farming or killing
            circle.Color = active
                and Color3.fromRGB(168, 85, 247)
                or  Color3.fromRGB(80, 40, 120)
            circle.Transparency = active
                and (circleOn and 0.65 or 1)
                or  (circleOn and 0.85 or 1)
            stTrees.Text       = "ДЕРЕВЬЯ: " .. (farming and "ВКЛ" or "ВЫКЛ")
            stTrees.TextColor3 = farming and C.NEON_G or C.GRAY
            wstWolves.Text       = "ВОЛКИ: " .. (killing and "ВКЛ" or "ВЫКЛ")
            wstWolves.TextColor3 = killing and C.NEON_R or C.GRAY
        end)
    end
    recAcc = recAcc + dt
    if recAcc >= 0.9 then
        recAcc = 0; recOn = not recOn
        Tw(RecDot, {BackgroundTransparency = recOn and 0 or 0.85}, 0.3)
        Tw(TDot,   {BackgroundTransparency = recOn and 0 or 0.85}, 0.3)
    end
end)

-- ── АВТО-ВОССТАНОВЛЕНИЕ НАСТРОЕК (RESTORE PREVIOUS STATE) ──────────
task.spawn(function()
    task.wait(1)
    for _, restoreFunc in ipairs(autoRestoreList) do
        pcall(restoreFunc)
    end
    print("[INFECTION] Сохраненные настройки успешно восстановлены!")
end)

print("[INFECTION|xdar4k] Загружено! RightShift = открыть GUI")
print("  ДЕРЕВЬЯ: вкладка ДЕРЕВЬЯ -> ВКЛ")
print("  ВОЛКИ:   вкладка ВОЛКИ   -> ВКЛ")
print("  НАСТРОЙКИ: вкладка НАСТРОЙКИ -> слайдеры")
print("  💾 АВТО-СЕЙВ: активен, сохраняется в InfectionGui_Config.json")
