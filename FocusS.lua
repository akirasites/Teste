--[[
    ╔══════════════════════════════════════════════╗
    ║           Focus-S  |  by CoiledTom           ║
    ║      ProximityPrompt Auto Farm  v1.0          ║
    ╚══════════════════════════════════════════════╝
    
    Executor compatibility: Delta, KRNL, Fluxus,
    Synapse X, Arceus X, Hydrogen
--]]

-- ─── Services ────────────────────────────────────────────────────────────────
local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local Workspace       = game:GetService("Workspace")

-- ─── Locals ──────────────────────────────────────────────────────────────────
local LocalPlayer     = Players.LocalPlayer
local Character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP             = Character:WaitForChild("HumanoidRootPart")

-- ─── WindUI v2 Load ──────────────────────────────────────────────────────────
local WindUI
local success, err = pcall(function()
    WindUI = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
    ))()
end)

if not success then
    warn("[Focus-S] Falha ao carregar WindUI v2: " .. tostring(err))
    return
end

-- ─── State ───────────────────────────────────────────────────────────────────
local State = {
    AutoFarm     = false,
    MoveMode     = "Tween",        -- "Tween" | "Teleport"
    TweenSpeed   = 20,             -- studs/second (used to derive tween time)
    Selected     = {},             -- set of ProximityPrompt objects
    PromptList   = {},             -- ordered list for the SelectBox
    FarmLoop     = nil,            -- RBXScriptConnection / coroutine handle
    OriginalCF   = nil,
}

-- ─── Utility: refresh Character refs ─────────────────────────────────────────
local function RefreshCharacter()
    Character = LocalPlayer.Character
    if not Character then return false end
    HRP = Character:FindFirstChild("HumanoidRootPart")
    return HRP ~= nil
end

LocalPlayer.CharacterAdded:Connect(function(c)
    Character = c
    HRP = c:WaitForChild("HumanoidRootPart")
end)

-- ─── Utility: safe fireproximityprompt ───────────────────────────────────────
local function SafeFire(prompt)
    if not prompt or not prompt.Parent then return false end
    local ok = pcall(function()
        fireproximityprompt(prompt)
    end)
    return ok
end

-- ─── Utility: distance ───────────────────────────────────────────────────────
local function GetPromptPosition(prompt)
    if not prompt or not prompt.Parent then return nil end
    local part = prompt.Parent
    if part:IsA("BasePart") then
        return part.Position
    elseif part:IsA("Model") then
        local root = part:FindFirstChild("HumanoidRootPart")
            or part:FindFirstChildWhichIsA("BasePart")
        if root then return root.Position end
    end
    return nil
end

-- ─── Movement: Tween ─────────────────────────────────────────────────────────
local function MoveByTween(targetPos, speed)
    if not RefreshCharacter() then return end
    local dist  = (HRP.Position - targetPos).Magnitude
    local time  = math.max(dist / math.max(speed, 1), 0.05)
    local goal  = { CFrame = CFrame.new(targetPos + Vector3.new(0, 0, 3)) }
    local info  = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(HRP, info, goal)
    tween:Play()
    tween.Completed:Wait()
end

-- ─── Movement: Teleport ──────────────────────────────────────────────────────
local function MoveByTeleport(targetPos)
    if not RefreshCharacter() then return end
    HRP.CFrame = CFrame.new(targetPos + Vector3.new(0, 0, 3))
    task.wait(0.05)
end

-- ─── Core: interact with a single prompt ─────────────────────────────────────
local function InteractPrompt(prompt)
    if not prompt or not prompt.Parent then return end
    local pos = GetPromptPosition(prompt)
    if not pos then return end

    -- save original position once per farm cycle (set by loop)
    if State.MoveMode == "Tween" then
        MoveByTween(pos, State.TweenSpeed)
    else
        MoveByTeleport(pos)
    end

    task.wait(0.15)
    SafeFire(prompt)
    task.wait(0.1)
end

-- ─── Core: farm loop ─────────────────────────────────────────────────────────
local FarmCoroutine = nil

local function StopFarm()
    State.AutoFarm = false
    if FarmCoroutine then
        coroutine.close(FarmCoroutine)
        FarmCoroutine = nil
    end
end

local function StartFarm()
    if FarmCoroutine then return end

    FarmCoroutine = coroutine.create(function()
        while State.AutoFarm do
            if not RefreshCharacter() then
                task.wait(1)
                continue
            end

            State.OriginalCF = HRP.CFrame

            -- collect valid selected prompts
            local queue = {}
            for prompt, _ in pairs(State.Selected) do
                if prompt and prompt.Parent then
                    table.insert(queue, prompt)
                end
            end

            if #queue == 0 then
                task.wait(0.5)
                continue
            end

            for _, prompt in ipairs(queue) do
                if not State.AutoFarm then break end
                local ok, e = pcall(InteractPrompt, prompt)
                if not ok then
                    warn("[Focus-S] Erro ao interagir: " .. tostring(e))
                end
                task.wait(0.05)
            end

            -- return to original position
            if State.OriginalCF and RefreshCharacter() then
                if State.MoveMode == "Tween" then
                    local dist = (HRP.Position - State.OriginalCF.Position).Magnitude
                    local t    = math.max(dist / math.max(State.TweenSpeed, 1), 0.05)
                    local tw   = TweenService:Create(
                        HRP,
                        TweenInfo.new(t, Enum.EasingStyle.Linear),
                        { CFrame = State.OriginalCF }
                    )
                    tw:Play()
                    tw.Completed:Wait()
                else
                    HRP.CFrame = State.OriginalCF
                    task.wait(0.05)
                end
            end

            task.wait(0.2)
        end
        FarmCoroutine = nil
    end)

    coroutine.resume(FarmCoroutine)
end

-- ─── ProximityPrompt Registry ────────────────────────────────────────────────
local PromptRegistry = {}   -- [prompt] = label string
local OnListChanged  = nil  -- callback injected by GUI

local function PromptLabel(prompt)
    local pName = prompt.ActionText ~= "" and prompt.ActionText
        or (prompt.Parent and prompt.Parent.Name)
        or "Prompt"
    local path  = prompt:GetFullName()
    return pName .. "  [" .. path .. "]"
end

local function RegisterPrompt(prompt)
    if PromptRegistry[prompt] then return end
    PromptRegistry[prompt] = PromptLabel(prompt)
    table.insert(State.PromptList, { Prompt = prompt, Label = PromptRegistry[prompt] })

    -- clean up when removed
    prompt.AncestryChanged:Connect(function()
        if not prompt:IsDescendantOf(Workspace) then
            PromptRegistry[prompt]  = nil
            State.Selected[prompt]  = nil
            -- rebuild list
            for i, entry in ipairs(State.PromptList) do
                if entry.Prompt == prompt then
                    table.remove(State.PromptList, i)
                    break
                end
            end
            if OnListChanged then OnListChanged() end
        end
    end)

    if OnListChanged then OnListChanged() end
end

local function ScanDescendants(parent)
    for _, obj in ipairs(parent:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            RegisterPrompt(obj)
        end
    end
end

-- initial scan
ScanDescendants(Workspace)

-- watch for new ones
Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then
        task.wait(0.1) -- let it settle
        RegisterPrompt(obj)
    end
end)

-- ─── GUI ─────────────────────────────────────────────────────────────────────
local Window = WindUI:CreateWindow({
    Title        = "Focus-S",
    Icon         = "crosshair",
    Author       = "by CoiledTom",
    Themeable    = { Background = true },
    Size         = UDim2.fromOffset(380, 480),
    Transparency = 0.25,
})

-- apply glass / frosted style via WindUI theme overrides
WindUI:SetTheme({
    Background        = Color3.fromRGB(12, 14, 22),
    Accent            = Color3.fromRGB(120, 90, 255),
    TopbarBackground  = Color3.fromRGB(18, 20, 32),
    ElementBackground = Color3.fromRGB(22, 25, 40),
    Text              = Color3.fromRGB(235, 235, 245),
    SubText           = Color3.fromRGB(140, 140, 165),
})

local MainTab = Window:CreateTab({
    Title = "Auto Farm",
    Icon  = "zap",
})

-- ── Section: Configurações ────────────────────────────────────────────────────
local ConfigSection = MainTab:CreateSection({ Title = "Configurações" })

-- Move Mode SelectBox
ConfigSection:CreateDropdown({
    Title   = "Modo de Movimento",
    Values  = { "Tween", "Teleport" },
    Default = "Tween",
    Callback = function(val)
        State.MoveMode = val
    end,
})

-- Tween Speed TextBox
ConfigSection:CreateInput({
    Title       = "Velocidade do Tween (studs/s)",
    Placeholder = "20",
    Default     = "20",
    Callback    = function(val)
        local n = tonumber(val)
        if n and n > 0 then
            State.TweenSpeed = n
        end
    end,
})

-- ── Section: Botões ───────────────────────────────────────────────────────────
local PromptSection = MainTab:CreateSection({ Title = "ProximityPrompts" })

-- Build label list for SelectBox
local function GetLabelList()
    local labels = {}
    for _, entry in ipairs(State.PromptList) do
        table.insert(labels, entry.Label)
    end
    return labels
end

-- Multi-select dropdown for prompts
local PromptDropdown = PromptSection:CreateMultiDropdown({
    Title    = "Selecionar Botões",
    Values   = GetLabelList(),
    Callback = function(selected)
        -- selected = { [label] = true, ... }
        State.Selected = {}
        for label, active in pairs(selected) do
            if active then
                for _, entry in ipairs(State.PromptList) do
                    if entry.Label == label then
                        State.Selected[entry.Prompt] = true
                        break
                    end
                end
            end
        end
    end,
})

-- inject refresh callback
OnListChanged = function()
    -- WindUI v2 supports :Refresh on dropdowns
    local ok = pcall(function()
        PromptDropdown:Refresh(GetLabelList(), {})
    end)
    if not ok then
        -- fallback: rebuild selected from surviving prompts
        local cleaned = {}
        for prompt, _ in pairs(State.Selected) do
            if prompt and prompt.Parent then
                cleaned[prompt] = true
            end
        end
        State.Selected = cleaned
    end
end

-- Refresh button (manual)
PromptSection:CreateButton({
    Title    = "↺  Atualizar Lista",
    Callback = function()
        -- re-scan in case of late-loaded content
        ScanDescendants(Workspace)
        OnListChanged()
    end,
})

-- ── Section: Controle ─────────────────────────────────────────────────────────
local ControlSection = MainTab:CreateSection({ Title = "Controle" })

ControlSection:CreateToggle({
    Title    = "Auto Farm",
    Default  = false,
    Callback = function(val)
        State.AutoFarm = val
        if val then
            StartFarm()
        else
            StopFarm()
        end
    end,
})

-- ── Tab: Info ────────────────────────────────────────────────────────────────
local InfoTab = Window:CreateTab({
    Title = "Info",
    Icon  = "info",
})

local InfoSection = InfoTab:CreateSection({ Title = "Focus-S  v1.0" })

InfoSection:CreateLabel({ Title = "Script por CoiledTom" })
InfoSection:CreateLabel({ Title = "ProximityPrompt Auto Farm" })
InfoSection:CreateLabel({ Title = "Suporte: Delta · KRNL · Synapse · Fluxus · Arceus · Hydrogen" })

InfoSection:CreateDivider()

InfoSection:CreateLabel({ Title = "Modos de Movimento" })
InfoSection:CreateLabel({ Title = "• Tween  — movimento suave até o botão" })
InfoSection:CreateLabel({ Title = "• Teleport  — teletransporte instantâneo" })

InfoSection:CreateDivider()

InfoSection:CreateLabel({ Title = "Como usar:" })
InfoSection:CreateLabel({ Title = "1. Selecione os botões no Multi-Select" })
InfoSection:CreateLabel({ Title = "2. Escolha o modo de movimento" })
InfoSection:CreateLabel({ Title = "3. (Tween) Defina a velocidade" })
InfoSection:CreateLabel({ Title = "4. Ative o Toggle  Auto Farm" })

-- ─── Finished ────────────────────────────────────────────────────────────────
print("[Focus-S] Carregado com sucesso | by CoiledTom")
