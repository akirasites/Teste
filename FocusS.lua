--[[
    ╔══════════════════════════════════════════════╗
    ║           Focus-S  |  by CoiledTom           ║
    ║         ProximityPrompt Auto Farm  v2         ║
    ╚══════════════════════════════════════════════╝
--]]

-- ─── Services ────────────────────────────────────────────────────────────────
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui     = game:GetService("StarterGui")
local HttpService    = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer    = Players.LocalPlayer
local Mouse          = LocalPlayer:GetMouse()

-- ─── State ───────────────────────────────────────────────────────────────────
local State = {
    AutoFarm   = false,
    MoveMode   = "Tween",
    TweenSpeed = 20,
    Selected   = {},
    PromptList = {},
    OriginalCF = nil,
    FarmThread = nil,
}

-- ─── Character helpers ───────────────────────────────────────────────────────
local function GetHRP()
    local c = LocalPlayer.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local c = LocalPlayer.Character
    if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end

LocalPlayer.CharacterAdded:Connect(function() end)

-- ─── Notification helper (native) ────────────────────────────────────────────
local function Notify(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "Focus-S",
            Text     = msg   or "",
            Duration = dur   or 3,
        })
    end)
end

-- ─── Movement ────────────────────────────────────────────────────────────────
local function TweenTo(targetCF)
    local hrp = GetHRP()
    if not hrp then return end
    local dist = (hrp.Position - targetCF.Position).Magnitude
    local t    = math.max(dist / math.max(State.TweenSpeed, 1), 0.05)
    local tw   = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = targetCF })
    tw:Play()
    tw.Completed:Wait()
end

local function TeleportTo(targetCF)
    local hrp = GetHRP()
    if not hrp then return end
    hrp.CFrame = targetCF
    task.wait(0.05)
end

local function MoveTo(targetCF)
    if State.MoveMode == "Tween" then
        TweenTo(targetCF)
    else
        TeleportTo(targetCF)
    end
end

-- ─── ProximityPrompt helpers ──────────────────────────────────────────────────
local function GetPromptCF(prompt)
    if not prompt or not prompt.Parent then return nil end
    local p = prompt.Parent
    if p:IsA("BasePart") then
        return p.CFrame
    elseif p:IsA("Model") then
        local r = p:FindFirstChild("HumanoidRootPart") or p:FindFirstChildWhichIsA("BasePart")
        if r then return r.CFrame end
    end
    return nil
end

local function SafeFire(prompt)
    if not prompt or not prompt.Parent then return end
    pcall(fireproximityprompt, prompt)
end

-- ─── Farm loop ────────────────────────────────────────────────────────────────
local function StopFarm()
    State.AutoFarm = false
    if State.FarmThread then
        task.cancel(State.FarmThread)
        State.FarmThread = nil
    end
end

local function StartFarm()
    if State.FarmThread then return end
    State.AutoFarm = true
    State.FarmThread = task.spawn(function()
        while State.AutoFarm do
            local hrp = GetHRP()
            if hrp then
                State.OriginalCF = hrp.CFrame
                local queue = {}
                for prompt in pairs(State.Selected) do
                    if prompt and prompt.Parent then
                        table.insert(queue, prompt)
                    end
                end
                for _, prompt in ipairs(queue) do
                    if not State.AutoFarm then break end
                    local cf = GetPromptCF(prompt)
                    if cf then
                        local offset = cf + cf.LookVector * 3
                        pcall(MoveTo, CFrame.new(offset.Position))
                        task.wait(0.1)
                        SafeFire(prompt)
                        task.wait(0.1)
                    end
                end
                if State.OriginalCF then
                    pcall(MoveTo, State.OriginalCF)
                end
            end
            task.wait(0.3)
        end
        State.FarmThread = nil
    end)
end

-- ─── ProximityPrompt registry ─────────────────────────────────────────────────
local PromptRegistry = {}
local OnListUpdate   = nil  -- injected later

local function PromptLabel(p)
    local txt = (p.ActionText ~= "" and p.ActionText) or (p.Parent and p.Parent.Name) or "Prompt"
    return txt
end

local function RegisterPrompt(p)
    if PromptRegistry[p] then return end
    PromptRegistry[p] = true
    table.insert(State.PromptList, { Prompt = p, Label = PromptLabel(p) })
    p.AncestryChanged:Connect(function()
        if not p:IsDescendantOf(game) then
            PromptRegistry[p] = nil
            State.Selected[p] = nil
            for i, e in ipairs(State.PromptList) do
                if e.Prompt == p then table.remove(State.PromptList, i) break end
            end
            if OnListUpdate then OnListUpdate() end
        end
    end)
    if OnListUpdate then OnListUpdate() end
end

local function ScanAll()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then RegisterPrompt(obj) end
    end
end

ScanAll()
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then task.wait(0.1) RegisterPrompt(obj) end
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  GUI — Native Roblox, Glass Style
-- ══════════════════════════════════════════════════════════════════════════════

-- Remove old GUI if re-executing
if gethui then
    local old = gethui():FindFirstChild("FocusS_GUI")
    if old then old:Destroy() end
else
    local old = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("FocusS_GUI")
    if old then old:Destroy() end
end

local GuiParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

-- ─── Root ScreenGui ──────────────────────────────────────────────────────────
local ScreenGui       = Instance.new("ScreenGui")
ScreenGui.Name        = "FocusS_GUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent      = GuiParent

-- ─── Color palette ───────────────────────────────────────────────────────────
local C = {
    BG         = Color3.fromRGB(10, 11, 18),
    TopBar     = Color3.fromRGB(16, 18, 30),
    Panel      = Color3.fromRGB(18, 20, 34),
    Element    = Color3.fromRGB(25, 28, 48),
    ElementHov = Color3.fromRGB(32, 36, 60),
    Accent     = Color3.fromRGB(110, 80, 255),
    AccentDim  = Color3.fromRGB(70, 50, 180),
    Green      = Color3.fromRGB(50, 220, 120),
    Red        = Color3.fromRGB(220, 70, 70),
    Text       = Color3.fromRGB(230, 230, 245),
    SubText    = Color3.fromRGB(130, 130, 160),
    White      = Color3.fromRGB(255, 255, 255),
    Border     = Color3.fromRGB(40, 44, 70),
}

local TRANS = {
    BG      = 0.28,  -- main window bg
    TopBar  = 0.15,
    Panel   = 0.22,
    Element = 0.10,
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function MkInst(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    return i
end

local function MkCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local function MkStroke(parent, color, thickness, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = trans or 0.5
    s.Parent = parent
end

local function MkPadding(parent, all, top, bottom, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top    or all or 6)
    p.PaddingBottom = UDim.new(0, bottom or all or 6)
    p.PaddingLeft   = UDim.new(0, left   or all or 8)
    p.PaddingRight  = UDim.new(0, right  or all or 8)
    p.Parent = parent
end

local function MkListLayout(parent, dir, pad, ha, va)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding       = UDim.new(0, pad or 6)
    l.HorizontalAlignment = ha or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = va or Enum.VerticalAlignment.Top
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function Tween(obj, props, t, style)
    TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad), props):Play()
end

-- ─── Drag ────────────────────────────────────────────────────────────────────
local function MakeDraggable(handle, frame)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ─── Main Frame ──────────────────────────────────────────────────────────────
local MainFrame = MkInst("Frame", {
    Name             = "MainFrame",
    Size             = UDim2.fromOffset(400, 520),
    Position         = UDim2.new(0.5, -200, 0.5, -260),
    BackgroundColor3 = C.BG,
    BackgroundTransparency = TRANS.BG,
    BorderSizePixel  = 0,
    Parent           = ScreenGui,
})
MkCorner(MainFrame, 12)
MkStroke(MainFrame, C.Border, 1, 0.3)

-- blur / glass shimmer layer
local BlurLayer = MkInst("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(255,255,255),
    BackgroundTransparency = 0.96,
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = MainFrame,
})
MkCorner(BlurLayer, 12)

-- ─── Top Bar ─────────────────────────────────────────────────────────────────
local TopBar = MkInst("Frame", {
    Name             = "TopBar",
    Size             = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = C.TopBar,
    BackgroundTransparency = TRANS.TopBar,
    BorderSizePixel  = 0,
    ZIndex           = 2,
    Parent           = MainFrame,
})
MkCorner(TopBar, 12)

-- cover bottom corners of topbar
MkInst("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = C.TopBar,
    BackgroundTransparency = TRANS.TopBar,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = TopBar,
})

MkInst("TextLabel", {
    Text = "Focus-S",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = C.White,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = TopBar,
})

MkInst("TextLabel", {
    Text = "by CoiledTom",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C.SubText,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(0, 14, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = TopBar,
})

-- Close button
local CloseBtn = MkInst("TextButton", {
    Text = "✕",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.SubText,
    BackgroundColor3 = Color3.fromRGB(200, 60, 60),
    BackgroundTransparency = 0.6,
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -38, 0.5, -14),
    ZIndex = 4,
    Parent = TopBar,
})
MkCorner(CloseBtn, 6)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, {BackgroundTransparency = 0.2}) end)
CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, {BackgroundTransparency = 0.6}) end)

-- Minimize button
local MinBtn = MkInst("TextButton", {
    Text = "—",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.SubText,
    BackgroundColor3 = C.Element,
    BackgroundTransparency = 0.3,
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -70, 0.5, -14),
    ZIndex = 4,
    Parent = TopBar,
})
MkCorner(MinBtn, 6)

local minimized = false
local ContentArea -- defined below

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Tween(MainFrame, { Size = UDim2.fromOffset(400, 44) })
    else
        Tween(MainFrame, { Size = UDim2.fromOffset(400, 520) })
    end
end)

MakeDraggable(TopBar, MainFrame)

-- ─── Tab Bar ─────────────────────────────────────────────────────────────────
local TabBar = MkInst("Frame", {
    Name             = "TabBar",
    Size             = UDim2.new(1, 0, 0, 38),
    Position         = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = C.Panel,
    BackgroundTransparency = TRANS.Panel,
    BorderSizePixel  = 0,
    ZIndex           = 2,
    Parent           = MainFrame,
})

local TabLayout = MkListLayout(TabBar, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
MkPadding(TabBar, 0, 0, 0, 8, 8)
TabLayout.Padding = UDim.new(0, 4)

-- ─── Content ─────────────────────────────────────────────────────────────────
ContentArea = MkInst("Frame", {
    Name             = "Content",
    Size             = UDim2.new(1, 0, 1, -82),
    Position         = UDim2.new(0, 0, 0, 82),
    BackgroundTransparency = 1,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
    ZIndex           = 2,
    Parent           = MainFrame,
})

-- ─── Tab system ──────────────────────────────────────────────────────────────
local Tabs       = {}
local ActiveTab  = nil

local function CreateTab(name, icon)
    -- Tab button
    local btn = MkInst("TextButton", {
        Text = (icon and (icon .. "  ") or "") .. name,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextColor3 = C.SubText,
        BackgroundColor3 = C.Element,
        BackgroundTransparency = 0.7,
        AutoButtonColor = false,
        Size = UDim2.new(0, 90, 0, 28),
        ZIndex = 3,
        Parent = TabBar,
    })
    MkCorner(btn, 6)

    -- Content frame
    local panel = MkInst("ScrollingFrame", {
        Name             = "Panel_" .. name,
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize       = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible          = false,
        ZIndex           = 2,
        Parent           = ContentArea,
    })
    MkPadding(panel, 0, 8, 8, 10, 10)
    local panelLayout = MkListLayout(panel, Enum.FillDirection.Vertical, 7)

    local tab = { Btn = btn, Panel = panel, Layout = panelLayout }
    table.insert(Tabs, tab)

    btn.MouseButton1Click:Connect(function()
        if ActiveTab then
            ActiveTab.Panel.Visible = false
            Tween(ActiveTab.Btn, { BackgroundTransparency = 0.7, TextColor3 = C.SubText })
        end
        ActiveTab = tab
        panel.Visible = true
        Tween(btn, { BackgroundTransparency = 0.2, TextColor3 = C.White })
    end)

    -- auto size tab button
    local tmp = MkInst("TextLabel", {
        Text = btn.Text, Font = btn.Font, TextSize = btn.TextSize,
        Size = UDim2.fromScale(0,0), Parent = ScreenGui
    })
    btn.Size = UDim2.fromOffset(math.max(tmp.TextBounds.X + 20, 80), 28)
    tmp:Destroy()

    return tab
end

-- ─── Element builders ────────────────────────────────────────────────────────

local function MkSection(parent, title)
    local frame = MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 0,
        Parent = parent,
    })
    MkInst("TextLabel", {
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = C.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = C.Border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = frame,
    })
    return frame
end

local function MkRow(parent, labelText, order)
    local row = MkInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.Element,
        BackgroundTransparency = TRANS.Element,
        BorderSizePixel  = 0,
        LayoutOrder      = order or 0,
        Parent           = parent,
    })
    MkCorner(row, 8)
    MkStroke(row, C.Border, 1, 0.5)
    MkPadding(row, 0, 0, 0, 10, 10)

    MkInst("TextLabel", {
        Text  = labelText,
        Font  = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = C.Text,
        BackgroundTransparency = 1,
        Size  = UDim2.new(0.55, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    return row
end

-- Toggle
local function MkToggle(parent, label, default, order, callback)
    local row = MkRow(parent, label, order)
    local state = default or false

    local track = MkInst("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -44, 0.5, -12),
        BackgroundColor3 = state and C.Green or C.Element,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = row,
    })
    MkCorner(track, 12)
    MkStroke(track, C.Border, 1, 0.4)

    local knob = MkInst("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = C.White,
        BorderSizePixel = 0,
        Parent = track,
    })
    MkCorner(knob, 9)

    local btn = MkInst("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Parent = row,
    })

    btn.MouseButton1Click:Connect(function()
        state = not state
        Tween(track, { BackgroundColor3 = state and C.Green or C.AccentDim })
        Tween(knob,  { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
        if callback then callback(state) end
    end)

    row.MouseEnter:Connect(function() Tween(row, {BackgroundTransparency = 0.05}) end)
    row.MouseLeave:Connect(function() Tween(row, {BackgroundTransparency = TRANS.Element}) end)

    return row
end

-- Dropdown (single)
local function MkDropdown(parent, label, options, default, order, callback)
    local open    = false
    local current = default or options[1]

    local row = MkRow(parent, label, order)
    row.Size = UDim2.new(1, 0, 0, 40)
    row.ClipsDescendants = false

    local valBtn = MkInst("TextButton", {
        Text = current .. "  ▾",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = C.Accent,
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.2,
        Size = UDim2.fromOffset(120, 26),
        Position = UDim2.new(1, -120, 0.5, -13),
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = row,
    })
    MkCorner(valBtn, 6)

    local dropFrame = MkInst("Frame", {
        Size = UDim2.fromOffset(120, #options * 30 + 6),
        Position = UDim2.new(1, -120, 1, 4),
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
        Parent = row,
    })
    MkCorner(dropFrame, 8)
    MkStroke(dropFrame, C.Border, 1, 0.3)
    MkPadding(dropFrame, 3, 3, 3, 3, 3)
    MkListLayout(dropFrame, Enum.FillDirection.Vertical, 2)

    for _, opt in ipairs(options) do
        local optBtn = MkInst("TextButton", {
            Text = opt,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = opt == current and C.Accent or C.Text,
            BackgroundColor3 = C.Element,
            BackgroundTransparency = 0.3,
            Size = UDim2.new(1, 0, 0, 26),
            BorderSizePixel = 0,
            ZIndex = 21,
            Parent = dropFrame,
        })
        MkCorner(optBtn, 5)
        optBtn.MouseButton1Click:Connect(function()
            current = opt
            valBtn.Text = opt .. "  ▾"
            dropFrame.Visible = false
            open = false
            for _, c2 in ipairs(dropFrame:GetChildren()) do
                if c2:IsA("TextButton") then
                    c2.TextColor3 = c2.Text == opt and C.Accent or C.Text
                end
            end
            if callback then callback(opt) end
        end)
        optBtn.MouseEnter:Connect(function() Tween(optBtn, {BackgroundTransparency = 0.05}) end)
        optBtn.MouseLeave:Connect(function() Tween(optBtn, {BackgroundTransparency = 0.3}) end)
    end

    valBtn.MouseButton1Click:Connect(function()
        open = not open
        dropFrame.Visible = open
    end)

    row.MouseEnter:Connect(function() Tween(row, {BackgroundTransparency = 0.05}) end)
    row.MouseLeave:Connect(function() Tween(row, {BackgroundTransparency = TRANS.Element}) end)

    return row
end

-- TextBox Input
local function MkInput(parent, label, default, placeholder, order, callback)
    local row = MkRow(parent, label, order)

    local box = MkInst("TextBox", {
        Text = tostring(default or ""),
        PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = C.Text,
        PlaceholderColor3 = C.SubText,
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.2,
        Size = UDim2.fromOffset(110, 26),
        Position = UDim2.new(1, -110, 0.5, -13),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        ZIndex = 5,
        Parent = row,
    })
    MkCorner(box, 6)
    MkStroke(box, C.Accent, 1, 0.6)

    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
    end)

    row.MouseEnter:Connect(function() Tween(row, {BackgroundTransparency = 0.05}) end)
    row.MouseLeave:Connect(function() Tween(row, {BackgroundTransparency = TRANS.Element}) end)

    return row
end

-- Button
local function MkButton(parent, label, order, callback)
    local btn = MkInst("TextButton", {
        Text = label,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = C.White,
        BackgroundColor3 = C.Accent,
        BackgroundTransparency = 0.1,
        Size = UDim2.new(1, 0, 0, 36),
        BorderSizePixel = 0,
        LayoutOrder = order or 0,
        AutoButtonColor = false,
        Parent = parent,
    })
    MkCorner(btn, 8)
    MkStroke(btn, C.AccentDim, 1, 0.5)

    btn.MouseButton1Click:Connect(function()
        Tween(btn, {BackgroundTransparency = 0.4})
        task.delay(0.15, function() Tween(btn, {BackgroundTransparency = 0.1}) end)
        if callback then callback() end
    end)
    btn.MouseEnter:Connect(function() Tween(btn, {BackgroundTransparency = 0.0}) end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundTransparency = 0.1}) end)

    return btn
end

-- Label
local function MkLabel(parent, text, order)
    local lbl = MkInst("TextLabel", {
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = C.SubText,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    return lbl
end

-- Slider
local function MkSlider(parent, label, min, max, default, order, callback)
    local row = MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = C.Element,
        BackgroundTransparency = TRANS.Element,
        BorderSizePixel = 0,
        LayoutOrder = order or 0,
        Parent = parent,
    })
    MkCorner(row, 8)
    MkStroke(row, C.Border, 1, 0.5)
    MkPadding(row, 0, 6, 6, 10, 10)

    local value = default or min
    local topRow = MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Parent = row,
    })
    MkInst("TextLabel", {
        Text = label,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.Text, BackgroundTransparency = 1,
        Size = UDim2.new(0.7, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topRow,
    })
    local valLbl = MkInst("TextLabel", {
        Text = tostring(value),
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = C.Accent, BackgroundTransparency = 1,
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.7, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = topRow,
    })

    local track = MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = row,
    })
    MkCorner(track, 3)

    local fill = MkInst("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = C.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    MkCorner(fill, 3)

    local knob = MkInst("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7),
        BackgroundColor3 = C.White,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = track,
    })
    MkCorner(knob, 7)

    local sliding = false
    local btn = MkInst("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6, Parent = track,
    })

    local function UpdateSlider(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + rel * (max - min))
        valLbl.Text = tostring(value)
        Tween(fill, { Size = UDim2.new(rel, 0, 1, 0) })
        Tween(knob, { Position = UDim2.new(rel, -7, 0.5, -7) })
        if callback then callback(value) end
    end

    btn.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    btn.MouseButton1Click:Connect(function()
        UpdateSlider(Mouse.X)
    end)

    row.MouseEnter:Connect(function() Tween(row, {BackgroundTransparency = 0.05}) end)
    row.MouseLeave:Connect(function() Tween(row, {BackgroundTransparency = TRANS.Element}) end)

    return row
end

-- Multi-select list
local PromptCheckboxes = {}  -- label -> { frame, state, prompt }
local PromptScrollFrame

local function BuildPromptList(parentPanel)
    local section = MkSection(parentPanel, "ProximityPrompts Detectados")
    section.LayoutOrder = 10

    local container = MkInst("Frame", {
        Size = UDim2.new(1, 0, 0, 180),
        BackgroundColor3 = C.Panel,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        LayoutOrder = 11,
        ClipsDescendants = true,
        Parent = parentPanel,
    })
    MkCorner(container, 8)
    MkStroke(container, C.Border, 1, 0.4)

    local scroll = MkInst("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Accent,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = container,
    })
    MkPadding(scroll, 0, 4, 4, 6, 6)
    MkListLayout(scroll, Enum.FillDirection.Vertical, 4)

    PromptScrollFrame = scroll
    PromptCheckboxes  = {}

    local function Rebuild()
        for _, c in ipairs(scroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
        PromptCheckboxes = {}

        if #State.PromptList == 0 then
            MkInst("TextLabel", {
                Text = "Nenhum ProximityPrompt encontrado",
                Font = Enum.Font.Gotham, TextSize = 11,
                TextColor3 = C.SubText, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = scroll,
            })
            return
        end

        for _, entry in ipairs(State.PromptList) do
            local checked = State.Selected[entry.Prompt] or false

            local row2 = MkInst("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = checked and Color3.fromRGB(40, 50, 80) or C.Element,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                Parent = scroll,
            })
            MkCorner(row2, 6)
            MkPadding(row2, 0, 0, 0, 8, 8)

            local chk = MkInst("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, 0, 0.5, -8),
                BackgroundColor3 = checked and C.Accent or C.Panel,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Parent = row2,
            })
            MkCorner(chk, 4)

            if checked then
                MkInst("TextLabel", {
                    Text = "✓", Font = Enum.Font.GothamBold,
                    TextSize = 10, TextColor3 = C.White,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1,1),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Parent = chk,
                })
            end

            local nameLabel = MkInst("TextLabel", {
                Text = entry.Label,
                Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = C.Text, BackgroundTransparency = 1,
                Size = UDim2.new(1, -26, 1, 0),
                Position = UDim2.new(0, 24, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row2,
            })

            local clickBtn = MkInst("TextButton", {
                Text = "", BackgroundTransparency = 1,
                Size = UDim2.fromScale(1,1), Parent = row2,
            })
            clickBtn.MouseButton1Click:Connect(function()
                checked = not checked
                State.Selected[entry.Prompt] = checked or nil
                Tween(row2, { BackgroundColor3 = checked and Color3.fromRGB(40,50,80) or C.Element })
                Tween(chk,  { BackgroundColor3 = checked and C.Accent or C.Panel })
                -- update checkmark
                local old = chk:FindFirstChildOfClass("TextLabel")
                if checked and not old then
                    MkInst("TextLabel", {
                        Text = "✓", Font = Enum.Font.GothamBold,
                        TextSize = 10, TextColor3 = C.White,
                        BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1,1),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        Parent = chk,
                    })
                elseif not checked and old then
                    old:Destroy()
                end
            end)
        end
    end

    OnListUpdate = Rebuild
    Rebuild()

    return container
end

-- ══════════════════════════════════════════════════════════════════════════════
--  TAB 1 — Player
-- ══════════════════════════════════════════════════════════════════════════════
local T_Player = CreateTab("Player", "🏃")
local P = T_Player.Panel

MkSection(P, "Movimento").LayoutOrder = 0

MkSlider(P, "WalkSpeed", 16, 500, 16, 1, function(v)
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = v end
end)

MkSlider(P, "JumpPower", 50, 500, 50, 2, function(v)
    local hum = GetHumanoid()
    if hum then hum.JumpPower = v end
end)

local NoclipEnabled = false
MkToggle(P, "Noclip", false, 3, function(val)
    NoclipEnabled = val
end)

RunService.Stepped:Connect(function()
    if NoclipEnabled then
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
end)

local FlyEnabled = false
local FlyBodyVel, FlyBodyGyro

MkToggle(P, "Fly", false, 4, function(val)
    FlyEnabled = val
    local hrp = GetHRP()
    if not hrp then return end
    if val then
        FlyBodyVel = Instance.new("BodyVelocity")
        FlyBodyVel.Velocity = Vector3.zero
        FlyBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyVel.Parent = hrp

        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyGyro.CFrame = hrp.CFrame
        FlyBodyGyro.Parent = hrp

        task.spawn(function()
            while FlyEnabled do
                local hrp2 = GetHRP()
                if not hrp2 or not FlyBodyVel or not FlyBodyVel.Parent then break end
                local cam = workspace.CurrentCamera
                local cf  = cam.CFrame
                local vel = Vector3.zero
                local speed = 40
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + cf.LookVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - cf.LookVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - cf.RightVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + cf.RightVector * speed end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, speed, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel = vel - Vector3.new(0, speed, 0) end
                FlyBodyVel.Velocity = vel
                FlyBodyGyro.CFrame  = cf
                task.wait()
            end
        end)
    else
        if FlyBodyVel  then FlyBodyVel:Destroy()  FlyBodyVel  = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
    end
end)

MkSection(P, "Outros").LayoutOrder = 5

MkToggle(P, "God Mode (Anti-Kill)", false, 6, function(val)
    local hum = GetHumanoid()
    if hum then
        hum.MaxHealth = val and math.huge or 100
        hum.Health    = hum.MaxHealth
    end
end)

MkButton(P, "Reset Character", 7, function()
    local hum = GetHumanoid()
    if hum then hum.Health = 0 end
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  TAB 2 — Auto Farm
-- ══════════════════════════════════════════════════════════════════════════════
local T_Farm = CreateTab("Auto Farm", "⚡")
local F = T_Farm.Panel

MkSection(F, "Configurações").LayoutOrder = 0

MkDropdown(F, "Modo Movimento", {"Tween", "Teleport"}, "Tween", 1, function(val)
    State.MoveMode = val
end)

MkInput(F, "Velocidade Tween (st/s)", 20, "ex: 20", 2, function(val)
    local n = tonumber(val)
    if n and n > 0 then State.TweenSpeed = n end
end)

MkToggle(F, "Auto Farm", false, 3, function(val)
    if val then StartFarm() else StopFarm() end
end)

MkButton(F, "↺ Atualizar Lista", 9, function()
    ScanAll()
    if OnListUpdate then OnListUpdate() end
    Notify("Focus-S", "Lista atualizada! " .. #State.PromptList .. " botões encontrados.")
end)

BuildPromptList(F)

-- ══════════════════════════════════════════════════════════════════════════════
--  TAB 3 — Configurações
-- ══════════════════════════════════════════════════════════════════════════════
local T_Config = CreateTab("Config", "⚙️")
local CF2 = T_Config.Panel

MkSection(CF2, "Servidor").LayoutOrder = 0

MkButton(CF2, "🔁 Rejoin", 1, function()
    local id = game.PlaceId
    local ok, err2 = pcall(function()
        TeleportService:Teleport(id, LocalPlayer)
    end)
    if not ok then Notify("Focus-S", "Erro ao rejoin: " .. tostring(err2)) end
end)

MkButton(CF2, "🔀 Server Hop", 2, function()
    local ok, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)
    if ok and servers and servers.data then
        local list = servers.data
        local current = game.JobId
        for _, s in ipairs(list) do
            if s.id ~= current and s.playing < s.maxPlayers then
                pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, s.id, LocalPlayer)
                return
            end
        end
        Notify("Focus-S", "Nenhum servidor disponível encontrado.")
    else
        Notify("Focus-S", "Falha ao buscar servidores.")
    end
end)

MkSection(CF2, "Interface").LayoutOrder = 3

MkSlider(CF2, "Transparência GUI", 0, 80, 28, 4, function(v)
    MainFrame.BackgroundTransparency = v / 100
end)

MkSection(CF2, "Hotkeys").LayoutOrder = 5
MkLabel(CF2, "Insert   —  Mostrar / Esconder GUI", 6)
MkLabel(CF2, "Delete   —  Fechar GUI", 7)

MkSection(CF2, "Info").LayoutOrder = 8
MkLabel(CF2, "Focus-S v2.0  |  by CoiledTom", 9)
MkLabel(CF2, "Executors: Delta · KRNL · Synapse", 10)
MkLabel(CF2, "Fluxus · Arceus X · Hydrogen", 11)

-- ══════════════════════════════════════════════════════════════════════════════
--  Activate first tab
-- ══════════════════════════════════════════════════════════════════════════════
T_Player.Btn:MouseButton1Click()  -- fire click to activate

-- ─── Hotkeys ─────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.Delete then
        ScreenGui:Destroy()
        StopFarm()
    end
end)

-- ─── Done ────────────────────────────────────────────────────────────────────
Notify("Focus-S", "Carregado com sucesso! v2.0 by CoiledTom", 4)
print("[Focus-S v2] Loaded | by CoiledTom")
