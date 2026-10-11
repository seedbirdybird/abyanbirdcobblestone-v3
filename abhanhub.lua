-- abyanbirdy practice UI (executor version)
-- Self-contained: window library, overlay objects and all logic.
-- Re-executing cleans up the previous copy automatically.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

-- Pick the best GUI container available in this environment
local function getGuiParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then
        -- some executors block writes to CoreGui; test it
        local t = Instance.new("Folder")
        local wrote = pcall(function() t.Parent = ui end)
        t:Destroy()
        if wrote then return ui end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end
local playerGui = getGuiParent()

-- Remove leftovers from a previous execution
for _, name in ipairs({"PracticeUI", "PracticeOverlay"}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local THEME = {
    bg = Color3.fromRGB(24, 24, 30),
    panel = Color3.fromRGB(34, 34, 42),
    item = Color3.fromRGB(48, 48, 58),
    accent = Color3.fromRGB(120, 90, 255),
    text = Color3.fromRGB(235, 235, 240),
    dim = Color3.fromRGB(150, 150, 165),
}

local settings = {
    enabled = true,
    notifications = true,
    mode = "Smooth",
    speed = 50,
    delay = 250,
    duration = 100,
    fps = false,
    opacity = 100,
    crosshair = false,
    fov = false,
    fovRadius = 120,
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function corner(parent, r)
    return create("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
end

-- Animation settings actually drive every tween in the UI
local function animTime()
    local t = 0.4 - 0.37 * (settings.speed / 100) -- 0.40s at 0%, 0.03s at 100%
    if settings.mode == "Fast" then t = t * 0.5 end
    return t
end

local function animStyle()
    if settings.mode == "Default" then return Enum.EasingStyle.Quad end
    if settings.mode == "Fast" then return Enum.EasingStyle.Linear end
    return Enum.EasingStyle.Quint -- Smooth
end

local function tween(obj, props)
    TweenService:Create(obj, TweenInfo.new(animTime(), animStyle(), Enum.EasingDirection.Out), props):Play()
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function label(text, parent, props)
    local base = {
        BackgroundTransparency = 1, Text = text, TextColor3 = THEME.text,
        Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props or {}) do base[k] = v end
    return create("TextLabel", base, parent)
end

----------------------------------------------------------------------
-- Mini UI library
----------------------------------------------------------------------
local Library = {}
local Window, Tab, Section = {}, {}, {}
Window.__index, Tab.__index, Section.__index = Window, Tab, Section

function Window:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self.Connections, c)
    return c
end

function Library:CreateWindow(title)
    local self = setmetatable({Connections = {}, Tabs = {}, _token = 0}, Window)

    self._gui = create("ScreenGui", {
        Name = "PracticeUI", ResetOnSpawn = false, DisplayOrder = 10,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)

    self._main = create("CanvasGroup", {
        Size = UDim2.fromOffset(520, 360), Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.bg, BorderSizePixel = 0,
    }, self._gui)
    corner(self._main, 8)
    self._scale = create("UIScale", {Scale = 1}, self._main)

    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, self._main)
    label(title, top, {
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0),
        Font = Enum.Font.GothamBold, TextSize = 14,
    })

    self._tabBar = create("Frame", {
        Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, self._main)
    create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, self._tabBar)
    create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 3)}, self._tabBar)

    self._pages = create("Frame", {
        Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1,
    }, self._main)

    -- dragging via title bar
    local dragging, dragStart, startPos = false, nil, nil
    top.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging, dragStart, startPos = true, input.Position, self._main.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            self._main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if isPress(input) then dragging = false end
    end)

    -- RightShift toggles the menu
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            self:SetVisible(not self._main.Visible)
        end
    end)

    return self
end

function Window:SetOpacity(percent)
    self._main.GroupTransparency = 1 - math.clamp(percent, 0, 100) / 100
end

function Window:SetVisible(visible)
    self._token += 1
    local token = self._token
    if visible then
        self._scale.Scale = 0.92
        self._main.Visible = true
        tween(self._scale, {Scale = 1})
    else
        tween(self._scale, {Scale = 0.92})
        task.delay(animTime(), function()
            if self._token == token then self._main.Visible = false end
        end)
    end
end

function Window:Destroy()
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    table.clear(self.Connections)
    self._gui:Destroy()
end

function Window:_select(tab)
    for _, t in ipairs(self.Tabs) do
        local active = t == tab
        t._page.Visible = active
        t._button.BackgroundColor3 = active and THEME.accent or THEME.panel
    end
end

function Window:AddTab(name)
    local tab = setmetatable({}, Tab)
    tab._button = create("TextButton", {
        Size = UDim2.fromOffset(90, 24), BackgroundColor3 = THEME.panel, Text = name,
        TextColor3 = THEME.text, Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = false,
    }, self._tabBar)
    corner(tab._button, 5)

    tab._page = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, self._pages)

    local function column(pos)
        local c = create("ScrollingFrame", {
            Position = pos, Size = UDim2.new(0.5, -15, 1, -10), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, tab._page)
        create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, c)
        return c
    end
    tab._columns = {Left = column(UDim2.new(0, 10, 0, 0)), Right = column(UDim2.new(0.5, 5, 0, 0))}

    table.insert(self.Tabs, tab)
    tab._window = self
    tab._button.MouseButton1Click:Connect(function() self:_select(tab) end)
    if #self.Tabs == 1 then self:_select(tab) end
    return tab
end

function Tab:AddSection(name, side)
    local section = setmetatable({_order = 0, _window = self._window}, Section)
    section._frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.panel, BorderSizePixel = 0,
    }, self._columns[side or "Left"])
    corner(section._frame, 6)
    create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, section._frame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, section._frame)
    label(name, section._frame, {
        Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold,
        TextColor3 = THEME.accent, LayoutOrder = 0,
    })
    return section
end

local function row(section, height)
    section._order += 1
    return create("Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = section._order,
    }, section._frame)
end

function Section:AddLabel(text)
    local r = row(self, 18)
    label(text, r, {Size = UDim2.fromScale(1, 1), TextColor3 = THEME.dim, TextWrapped = true, TextSize = 12})
end

function Section:AddButton(text, callback)
    self._order += 1
    local b = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = THEME.item, Text = text,
        TextColor3 = THEME.text, Font = Enum.Font.GothamMedium, TextSize = 13,
        LayoutOrder = self._order,
    }, self._frame)
    corner(b, 5)
    b.MouseButton1Click:Connect(function() if callback then callback() end end)
end

function Section:AddToggle(text, default, callback)
    local r = row(self, 26)
    label(text, r, {Size = UDim2.new(1, -46, 1, 0)})
    local sw = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(38, 18), BackgroundColor3 = THEME.item,
    }, r)
    corner(sw, 9)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = THEME.text,
    }, sw)
    corner(knob, 7)
    local btn = create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ""}, r)

    local obj = {Value = default}
    function obj:Set(v)
        v = v and true or false
        self.Value = v
        tween(sw, {BackgroundColor3 = v and THEME.accent or THEME.item})
        tween(knob, {Position = v and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)})
        if callback then callback(v) end
    end
    btn.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    obj:Set(default)
    return obj
end

function Section:AddSlider(text, min, max, default, suffix, callback)
    local r = row(self, 38)
    label(text, r, {Size = UDim2.new(0.65, 0, 0, 16)})
    local valueLabel = label("", r, {
        Size = UDim2.new(0.35, 0, 0, 16), Position = UDim2.fromScale(0.65, 0),
        TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = THEME.dim,
    })
    local track = create("Frame", {
        Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = THEME.item,
    }, r)
    corner(track, 3)
    local fill = create("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.accent}, track)
    corner(fill, 3)
    local hit = create("TextButton", {
        Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1, Text = "",
    }, r)

    local obj = {Value = default}
    function obj:Set(v, instant)
        v = math.clamp(math.floor(v + 0.5), min, max)
        self.Value = v
        valueLabel.Text = v .. (suffix or "")
        local size = UDim2.fromScale((v - min) / (max - min), 1)
        if instant then fill.Size = size else tween(fill, {Size = size}) end
        if callback then callback(v) end
    end

    local dragging = false
    local function fromX(x)
        local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
        obj:Set(min + (max - min) * math.clamp((x - a) / w, 0, 1), true)
    end
    hit.InputBegan:Connect(function(input)
        if isPress(input) then dragging = true; fromX(input.Position.X) end
    end)
    self._window:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    self._window:_connect(UserInputService.InputEnded, function(input)
        if isPress(input) then dragging = false end
    end)

    obj:Set(default, true)
    return obj
end

function Section:AddDropdown(text, options, default, callback)
    self._order += 1
    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = self._order,
    }, self._frame)
    create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, box)

    local head = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = THEME.item, Text = "",
        AutoButtonColor = false, LayoutOrder = 1,
    }, box)
    corner(head, 5)
    label(text, head, {Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromOffset(8, 0)})
    local current = label("", head, {
        Size = UDim2.new(0.45, -8, 1, 0), Position = UDim2.fromScale(0.55, 0),
        TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = THEME.accent,
    })

    local list = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false, LayoutOrder = 2,
    }, box)
    create("UIListLayout", {Padding = UDim.new(0, 2)}, list)

    local obj = {Value = default}
    function obj:Set(v)
        self.Value = v
        current.Text = v
        list.Visible = false
        if callback then callback(v) end
    end
    for _, opt in ipairs(options) do
        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = THEME.bg, Text = opt,
            TextColor3 = THEME.text, Font = Enum.Font.Gotham, TextSize = 12,
        }, list)
        corner(b, 4)
        b.MouseButton1Click:Connect(function() obj:Set(opt) end)
    end
    head.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
    obj:Set(default)
    return obj
end

----------------------------------------------------------------------
-- Overlay (FPS counter, crosshair, FOV guide)
----------------------------------------------------------------------
local overlay = create("ScreenGui", {
    Name = "PracticeOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
}, playerGui)

local fpsText = label("FPS: --", overlay, {
    Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(100, 20),
    Font = Enum.Font.GothamBold, TextSize = 14, Visible = false,
})
fpsText.TextStrokeTransparency = 0.5

local function centered(w, h, round)
    local f = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false,
    }, overlay)
    if round then corner(f, 100) end
    return f
end
local crossH = centered(16, 2)
local crossV = centered(2, 16)
local crossDot = centered(4, 4, true)

local circle = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
}, overlay)
corner(circle, 1000)
create("UIStroke", {Color = THEME.accent, Thickness = 2}, circle)

local function refreshOverlay()
    local visible = settings.enabled
    fpsText.Visible = visible and settings.fps
    local cross = visible and settings.crosshair
    crossH.Visible, crossV.Visible, crossDot.Visible = cross, cross, cross
    circle.Visible = visible and settings.fov
    local diameter = settings.fovRadius * 2
    circle.Size = UDim2.fromOffset(diameter, diameter)
end

local function notify(message, delaySeconds)
    if not settings.notifications then return end
    task.delay(delaySeconds or 0, function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "abyanbirdy", Text = message,
                Duration = math.max(1, settings.duration / 100),
            })
        end)
    end)
end

----------------------------------------------------------------------
-- Your UI
----------------------------------------------------------------------
local Window = Library:CreateWindow("abyanbirdy")

local mainTab = Window:AddTab("Main")
local general = mainTab:AddSection("General", "Left")
local enabledToggle = general:AddToggle("Enabled", true, function(v)
    settings.enabled = v
    refreshOverlay()
end)
local notificationToggle = general:AddToggle("Show notifications", true, function(v)
    settings.notifications = v
end)
local modeDropdown = general:AddDropdown("Animation mode", {"Default", "Smooth", "Fast"}, "Smooth", function(v)
    settings.mode = v
end)
local speedSlider = general:AddSlider("Animation speed", 0, 100, 50, "%", function(v)
    settings.speed = v
end)

local timing = mainTab:AddSection("Timing", "Right")
local delaySlider = timing:AddSlider("Notification delay", 0, 500, 250, " ms", function(v)
    settings.delay = v
end)
local durationSlider = timing:AddSlider("Notification duration", 0, 500, 100, " ms", function(v)
    settings.duration = v
end)
timing:AddButton("Test notification", function()
    notify("Your practice UI is working!", settings.delay / 1000)
end)

local visuals = Window:AddTab("Visuals")
local look = visuals:AddSection("Appearance", "Left")
local fpsToggle = look:AddToggle("Show FPS", false, function(v)
    settings.fps = v
    refreshOverlay()
end)
local opacitySlider = look:AddSlider("GUI opacity", 20, 100, 100, "%", function(v)
    settings.opacity = v
    Window:SetOpacity(v)
end)

local practice = visuals:AddSection("Practice guides", "Right")
local crosshairToggle = practice:AddToggle("Custom crosshair", false, function(v)
    settings.crosshair = v
    refreshOverlay()
end)
local fovToggle = practice:AddToggle("Show FOV guide", false, function(v)
    settings.fov = v
    refreshOverlay()
end)
local fovSlider = practice:AddSlider("FOV guide radius", 30, 300, 120, " px", function(v)
    settings.fovRadius = v
    refreshOverlay()
end)
practice:AddLabel("Visual guides only; no aim assistance")

local options = Window:AddTab("Settings")
local ui = options:AddSection("Interface", "Left")
ui:AddLabel("Toggle menu: RightShift")
ui:AddButton("Reset settings", function()
    enabledToggle:Set(true)
    notificationToggle:Set(true)
    modeDropdown:Set("Smooth")
    speedSlider:Set(50)
    delaySlider:Set(250)
    durationSlider:Set(100)
    fpsToggle:Set(false)
    opacitySlider:Set(100)
    crosshairToggle:Set(false)
    fovToggle:Set(false)
    fovSlider:Set(120)
    notify("Settings reset")
end)
ui:AddButton("Hide menu", function() Window:SetVisible(false) end)
ui:AddButton("Unload GUI", function()
    overlay:Destroy()
    Window:Destroy()
end)

local frameCount, elapsed = 0, 0
local connection = RunService.RenderStepped:Connect(function(dt)
    frameCount += 1
    elapsed += dt
    if elapsed >= 0.5 then
        fpsText.Text = ("FPS: %d"):format(math.floor(frameCount / elapsed + 0.5))
        frameCount, elapsed = 0, 0
    end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local center = camera.ViewportSize / 2
    local position = UDim2.fromOffset(center.X, center.Y)
    crossH.Position = position
    crossV.Position = position
    crossDot.Position = position
    circle.Position = position
end)
table.insert(Window.Connections, connection)

refreshOverlay()
return Library