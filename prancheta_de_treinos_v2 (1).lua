local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PLAYER_NAME = LocalPlayer.Name

local ENV = getgenv and getgenv() or _G

if ENV.PranchataTreinos and ENV.PranchataTreinos.Destroy then
    pcall(ENV.PranchataTreinos.Destroy)
end

-- ===== Ícones (mesma técnica do RocketUI/Icons.lua) =====
-- Baixa um pacote de ícones (Lucide) e monta uma tabela nome -> rbxassetid,
-- lendo diretamente o padrão ["nome"] = "rbxassetid://ID" do arquivo fonte.
local Icons = {}

local function loadIconPack(url)
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or type(source) ~= "string" then
        return false
    end

    for name, id in source:gmatch(
        '%[%s*["\']([^"\']+)["\']%s*%]%s*=%s*["\'](rbxassetid://%d+)["\']'
    ) do
        if not Icons[name] then
            Icons[name] = id
        end
    end

    return true
end

-- Se não houver internet/HttpGet no executor, a GUI continua funcionando
-- normalmente só sem os ícones (os botões caem no texto como alternativa).
pcall(loadIconPack, "https://raw.githubusercontent.com/Footagesus/Icons/main/lucide/dist/Icons.lua")

-- Cria um ImageLabel com o ícone "name"; retorna nil se o ícone não existir
-- (o chamador deve manter o texto do botão como alternativa).
local function addIcon(parent, name, size, color)
    local id = Icons[name]
    if not id then return nil end

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(size, size)
    img.BackgroundTransparency = 1
    img.Image = id
    img.ImageColor3 = color
    img.ZIndex = (parent.ZIndex or 1) + 1
    img.Parent = parent
    return img
end

-- ===== Dados salvos (textos e comandos personalizados) =====
local FOLDER = "Prancheta_de_Treinos"
local FILE = FOLDER .. "/dados.json"

local customTexts = {}
local customCommands = {}

local function saveData()
    if not (writefile and makefolder) then return false end

    local ok = pcall(function()
        if not isfolder(FOLDER) then
            makefolder(FOLDER)
        end

        writefile(FILE, HttpService:JSONEncode({
            texts = customTexts,
            commands = customCommands
        }))
    end)

    return ok
end

local function loadData()
    if not (readfile and isfile) then return end

    local ok, data = pcall(function()
        if not isfile(FILE) then return nil end
        return HttpService:JSONDecode(readfile(FILE))
    end)

    if ok and type(data) == "table" then
        customTexts = type(data.texts) == "table" and data.texts or {}
        customCommands = type(data.commands) == "table" and data.commands or {}
    end
end

loadData()

-- ===== Textos prontos (aba TEXTOS) =====
local texts = {
    {
        category = "APRESENTAÇÃO",
        items = {
            ";hy Olá, meu nome é " .. PLAYER_NAME .. ", e serei o auxiliar de vocês. Boa sorte!",
            ";hy Olá, meu nome é " .. PLAYER_NAME .. ", e serei o instrutor de vocês. Boa sorte!"
        }
    },
    {
        category = "ORIENTAÇÕES",
        items = {
            ";hy Quem eu tocar deverá dirigir-se à linha verde.",
            ";hy Quando terminarem, aguardem até que eu dê o ponto. Logo após, dirijam-se ao meu clone, que estará na linha vermelha."
        }
    },
    {
        category = "APROVADOS",
        items = {
            ";hy Aprovados, dirijam-se à STS Central e permaneçam no portão, aguardando novas instruções.",
            ";hy Parabéns para os que passaram!"
        }
    },
    {
        category = "COMANDOS PP",
        items = {
            ";hy PPA!",
            ";hy PPF!",
            ";hy PPO!",
            ";hr Negado!",
            ";hg Concedida!",
            ";hy Diga.",
            ";hy Não.",
            ";hy Sim."
        }
    }
}

-- ===== Ordens de marcha (aba ORDENS) =====
local marchCommands = {
    ";hr PREPARAR PARA MARCHAR!",
    ";hr MARCHEM!",
    ";hr AUTO!",
    ";hy Quem eu tocar vai para a linha verde!",
    ";hy Ao timer!"
}

-- Comandos simples (copiar + enviar), sem parâmetros
local simpleCommands = {
    ";clone me",
    ";clr",
    ";clogs"
}

-- Comandos de título que precisam de seleção de player
local titleCommands = {
    {label = "TITLEG APROVADO", cmd = "titleg", suffix = "Aprovado!!"},
    {label = "TITLEY AUXILIAR", cmd = "titley", suffix = "AUXILIAR!!"},
    {label = "TITLER INSTRUTOR", cmd = "titler", suffix = "INSTRUTOR!!"},
    {label = "TITLER REPROVADO", cmd = "titler", suffix = "REPROVADO!!"},
    {label = "TITLEDB OBSERVADOR", cmd = "titledb", suffix = "Observador!!"},
    {label = "REMOVER TÍTULO", cmd = "titler", suffix = ""}
}

-- Valores de pontos, incluindo meios pontos
local pointValues = {0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5}

local purple = Color3.fromRGB(130, 85, 220)
local dark = Color3.fromRGB(10, 10, 14)
local panel = Color3.fromRGB(21, 21, 29)
local cardColor = Color3.fromRGB(29, 29, 39)
local white = Color3.fromRGB(240, 240, 245)
local green = Color3.fromRGB(38, 110, 75)
local red = Color3.fromRGB(125, 45, 55)
local gray = Color3.fromRGB(130, 130, 140)

local function formatPoint(n)
    if n == math.floor(n) then
        return tostring(math.floor(n))
    end
    return tostring(n):gsub("%.", ",")
end

local gui = Instance.new("ScreenGui")
gui.Name = "PranchetaDeTreinos"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100

local parentGui = CoreGui
pcall(function()
    if gethui then
        parentGui = gethui()
    end
end)

gui.Parent = parentGui

-- ===== JANELA PRINCIPAL (mobile-friendly, mais larga) =====
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(310, 380)
main.Position = UDim2.new(0.5, -155, 0.5, -190)
main.BackgroundColor3 = dark
main.BorderSizePixel = 0
main.ClipsDescendants = false
main.Visible = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local outline = Instance.new("UIStroke")
outline.Color = purple
outline.Thickness = 1
outline.Parent = main

-- Frame que recorta só o cabeçalho/abas/conteúdo (não a janela toda),
-- assim o overlay do dropdown pode desenhar por cima sem ser cortado.
local clipFrame = Instance.new("Frame")
clipFrame.Size = UDim2.new(1, 0, 1, 0)
clipFrame.BackgroundTransparency = 1
clipFrame.ClipsDescendants = true
clipFrame.Parent = main

Instance.new("UICorner", clipFrame).CornerRadius = UDim.new(0, 10)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -62, 0, 32)
header.Position = UDim2.fromOffset(10, 0)
header.BackgroundTransparency = 1
header.Text = "PRANCHETA"
header.TextColor3 = white
header.Font = Enum.Font.GothamBold
header.TextSize = 12
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = clipFrame

-- Botão minimizar
local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(24, 24)
minimize.Position = UDim2.new(1, -58, 0, 4)
minimize.BackgroundColor3 = cardColor
minimize.Text = "-"
minimize.TextColor3 = white
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 16
minimize.ZIndex = 20
minimize.Parent = clipFrame
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)

do
    local icon = addIcon(minimize, "minus", 14, white)
    if icon then
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.ZIndex = 21
        minimize.Text = ""
    end
end

-- Botão fechar
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(24, 24)
close.Position = UDim2.new(1, -30, 0, 4)
close.BackgroundColor3 = cardColor
close.Text = "X"
close.TextColor3 = white
close.Font = Enum.Font.GothamBold
close.TextSize = 11
close.ZIndex = 20
close.Parent = clipFrame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

do
    local icon = addIcon(close, "x", 14, white)
    if icon then
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.ZIndex = 21
        close.Text = ""
    end
end

-- ===== Barra de abas (2 linhas, cabem 5 abas sem precisar rolar) =====
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -14, 0, 58)
tabs.Position = UDim2.fromOffset(7, 36)
tabs.BackgroundTransparency = 1
tabs.Parent = clipFrame

local tabGrid = Instance.new("UIGridLayout")
tabGrid.CellSize = UDim2.new(1 / 3, -4, 0, 26)
tabGrid.CellPadding = UDim2.new(0, 4, 0, 4)
tabGrid.SortOrder = Enum.SortOrder.LayoutOrder
tabGrid.Parent = tabs

-- Camada de overlay para os dropdowns abrirem por cima de tudo,
-- sem ser cortados pelo ScrollingFrame e sem empurrar outros elementos.
local overlayLayer = Instance.new("Frame")
overlayLayer.Name = "OverlayLayer"
overlayLayer.Size = UDim2.new(1, 0, 1, 0)
overlayLayer.BackgroundTransparency = 1
overlayLayer.ZIndex = 50
overlayLayer.Parent = main

-- ===== BUBBLE (ícone flutuante quando minimizado) =====
local bubble = Instance.new("TextButton")
bubble.Size = UDim2.fromOffset(52, 52)
bubble.Position = UDim2.new(0.5, -26, 0.5, -26)
bubble.BackgroundColor3 = dark
bubble.Text = ""
bubble.AutoButtonColor = false
bubble.Visible = false
bubble.Parent = gui
Instance.new("UICorner", bubble).CornerRadius = UDim.new(1, 0)

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Color = purple
bubbleStroke.Thickness = 2
bubbleStroke.Parent = bubble

local bubbleLabel = Instance.new("TextLabel")
bubbleLabel.Size = UDim2.new(1, 0, 1, 0)
bubbleLabel.BackgroundTransparency = 1
bubbleLabel.Text = "PT"
bubbleLabel.TextColor3 = white
bubbleLabel.Font = Enum.Font.GothamBold
bubbleLabel.TextSize = 14
bubbleLabel.Parent = bubble

do
    local icon = addIcon(bubble, "clipboard-list", 24, purple)
    if icon then
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        bubbleLabel.Text = ""
    end
end

-- ===== Helpers genéricos de UI =====
local function makeButton(parent, name, color, callback, iconName)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = color
    b.Text = name
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)

    if iconName then
        local icon = addIcon(b, iconName, 12, white)
        if icon then
            icon.AnchorPoint = Vector2.new(0, 0.5)
            icon.Position = UDim2.new(0, 8, 0.5, 0)

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 16)
            pad.Parent = b
        end
    end

    b.Activated:Connect(callback)
    return b
end

local function makeLabel(parent, nextOrder, value)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -5, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = value
    l.TextColor3 = purple
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = nextOrder()
    l.Parent = parent
end

local function sendMessage(message)
    local channels = TextChatService:FindFirstChild("TextChannels")
    if not channels then return end

    local channel = channels:FindFirstChild("RBXGeneral")

    if not channel then
        for _, v in ipairs(channels:GetChildren()) do
            if v:IsA("TextChannel") then
                channel = v
                break
            end
        end
    end

    if channel and channel:IsA("TextChannel") then
        local ok, err = pcall(function()
            channel:SendAsync(message)
        end)

        if not ok then
            warn("[Prancheta] Erro ao enviar:", err)
        end
    end
end

local function copyText(value)
    if setclipboard then
        local ok = pcall(setclipboard, value)
        if ok then return end
    end

    local popup = Instance.new("Frame")
    popup.Size = UDim2.fromOffset(260, 105)
    popup.Position = UDim2.new(0.5, -130, 0.5, -52)
    popup.BackgroundColor3 = panel
    popup.ZIndex = 60
    popup.Parent = main
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -16, 0, 58)
    box.Position = UDim2.fromOffset(8, 8)
    box.BackgroundColor3 = dark
    box.TextColor3 = white
    box.Text = value
    box.TextWrapped = true
    box.MultiLine = true
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.ZIndex = 61
    box.Parent = popup
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local closePopup = makeButton(popup, "FECHAR", purple, function()
        popup:Destroy()
    end, "x")
    closePopup.Size = UDim2.new(1, -16, 0, 25)
    closePopup.Position = UDim2.fromOffset(8, 72)
    closePopup.ZIndex = 61

    box:CaptureFocus()
end

local function makeCard(parent, nextOrder, value, removable, removeCallback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -5, 0, removable and 72 or 66)
    card.BackgroundColor3 = cardColor
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -14, 0, 30)
    txt.Position = UDim2.fromOffset(7, 3)
    txt.BackgroundTransparency = 1
    txt.Text = value
    txt.TextColor3 = white
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 9
    txt.TextWrapped = true
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = card

    local btnWidth = removable and 68 or 103

    local copy = makeButton(card, "COPIAR", purple, function()
        copyText(value)
    end, "copy")
    copy.Size = UDim2.fromOffset(btnWidth, 25)
    copy.Position = UDim2.fromOffset(7, 36)

    local send = makeButton(card, "ENVIAR", green, function()
        sendMessage(value)
    end, "send")
    send.Size = UDim2.fromOffset(btnWidth, 25)
    send.Position = UDim2.fromOffset(7 + btnWidth + 4, 36)

    if removable then
        local remove = makeButton(card, "DEL", red, removeCallback, "trash-2")
        remove.Size = UDim2.fromOffset(50, 25)
        remove.Position = UDim2.new(1, -57, 0, 36)
    end

    return card
end

-- ===== Dropdown via overlay =====
-- Desenha a lista de opções em overlayLayer (fora do ScrollingFrame),
-- posicionada por coordenadas absolutas, então nada corta e nada
-- empurra o layout do conteúdo.
local activeDropdownClose = nil

local function closeActiveDropdown()
    if activeDropdownClose then
        activeDropdownClose()
        activeDropdownClose = nil
    end
end

local function dropdown(parent, options, callback, formatFn)
    formatFn = formatFn or tostring

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 30)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local current = options[1]

    local select = Instance.new("TextButton")
    select.Size = UDim2.new(1, 0, 0, 28)
    select.BackgroundColor3 = cardColor
    select.AutoButtonColor = false
    select.Text = ""
    select.Parent = holder
    select.ClipsDescendants = true

    Instance.new("UICorner", select).CornerRadius = UDim.new(0, 6)
    local selStroke = Instance.new("UIStroke")
    selStroke.Color = purple
    selStroke.Transparency = 0.45
    selStroke.Thickness = 1
    selStroke.Parent = select

    local selLabel = Instance.new("TextLabel")
    selLabel.Size = UDim2.new(1, -34, 1, 0)
    selLabel.Position = UDim2.fromOffset(10, 0)
    selLabel.BackgroundTransparency = 1
    selLabel.Text = formatFn(current)
    selLabel.TextColor3 = white
    selLabel.Font = Enum.Font.Gotham
    selLabel.TextSize = 10
    selLabel.TextXAlignment = Enum.TextXAlignment.Left
    selLabel.TextTruncate = Enum.TextTruncate.AtEnd
    selLabel.Parent = select

    local selArrow = Instance.new("TextLabel")
    selArrow.Size = UDim2.fromOffset(20, 28)
    selArrow.Position = UDim2.new(1, -24, 0, 0)
    selArrow.BackgroundTransparency = 1
    selArrow.Text = "▾"
    selArrow.TextColor3 = purple
    selArrow.Font = Enum.Font.GothamBold
    selArrow.TextSize = 11
    selArrow.Parent = select

    select.MouseEnter:Connect(function()
        selStroke.Transparency = 0
    end)
    select.MouseLeave:Connect(function()
        if not select:GetAttribute("DropdownOpen") then
            selStroke.Transparency = 0.45
        end
    end)

    local function getSelected()
        return current
    end

    select.Activated:Connect(function()
        -- Se já existe um overlay aberto para este mesmo select, fecha e sai (toggle)
        if activeDropdownClose and select:GetAttribute("DropdownOpen") then
            closeActiveDropdown()
            return
        end

        closeActiveDropdown()

        local absPos = select.AbsolutePosition
        local absSize = select.AbsoluteSize
        local mainAbsPos = main.AbsolutePosition

        local relX = absPos.X - mainAbsPos.X
        local relY = absPos.Y - mainAbsPos.Y

        local maxVisible = 5
        local rowHeight = 26
        local rowGap = 3
        local innerPad = 4
        local shown = math.min(#options, maxVisible)
        local listHeight = shown * rowHeight + math.max(shown - 1, 0) * rowGap + innerPad * 2
        local fullHeight = #options * rowHeight + math.max(#options - 1, 0) * rowGap + innerPad * 2

        -- Decide abrir para baixo ou para cima dependendo do espaço disponível
        local spaceBelow = main.AbsoluteSize.Y - (relY + absSize.Y)
        local openUpwards = spaceBelow < (listHeight + 6) and relY > listHeight

        local overlay = Instance.new("Frame")
        overlay.Size = UDim2.fromOffset(absSize.X, listHeight)
        overlay.Position = openUpwards
            and UDim2.fromOffset(relX, relY - listHeight - 4)
            or UDim2.fromOffset(relX, relY + absSize.Y + 4)
        overlay.BackgroundColor3 = panel
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 50
        overlay.Parent = overlayLayer
        Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 8)

        local overlayStroke = Instance.new("UIStroke")
        overlayStroke.Color = purple
        overlayStroke.Transparency = 0.2
        overlayStroke.Thickness = 1
        overlayStroke.Parent = overlay

        local optList = Instance.new("ScrollingFrame")
        optList.Size = UDim2.new(1, 0, 1, 0)
        optList.BackgroundTransparency = 1
        optList.BorderSizePixel = 0
        optList.ScrollBarThickness = 3
        optList.ScrollBarImageColor3 = purple
        optList.CanvasSize = UDim2.new(0, 0, 0, fullHeight)
        optList.ZIndex = 51
        optList.Parent = overlay

        local optPadding = Instance.new("UIPadding")
        optPadding.PaddingLeft = UDim.new(0, innerPad)
        optPadding.PaddingRight = UDim.new(0, innerPad)
        optPadding.PaddingTop = UDim.new(0, innerPad)
        optPadding.PaddingBottom = UDim.new(0, innerPad)
        optPadding.Parent = optList

        local optListLayout = Instance.new("UIListLayout")
        optListLayout.Padding = UDim.new(0, rowGap)
        optListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        optListLayout.Parent = optList

        local blocker = Instance.new("TextButton")
        blocker.Size = UDim2.new(1, 0, 1, 0)
        blocker.BackgroundTransparency = 1
        blocker.Text = ""
        blocker.ZIndex = 1
        blocker.Parent = overlayLayer
        blocker:SetAttribute("IsBlocker", true)
        overlay.ZIndex = 50
        blocker.Parent = overlayLayer

        local function closeThis()
            select:SetAttribute("DropdownOpen", false)
            selArrow.Text = "▾"
            selStroke.Transparency = 0.45
            if overlay then overlay:Destroy() end
            if blocker then blocker:Destroy() end
        end

        blocker.Activated:Connect(closeThis)
        activeDropdownClose = closeThis
        select:SetAttribute("DropdownOpen", true)
        selArrow.Text = "▴"
        selStroke.Transparency = 0

        for i, option in ipairs(options) do
            local isSelected = option == current

            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, rowHeight)
            opt.LayoutOrder = i
            opt.BackgroundColor3 = isSelected and purple or cardColor
            opt.BackgroundTransparency = isSelected and 0.35 or 0
            opt.AutoButtonColor = false
            opt.Text = ""
            opt.ZIndex = 52
            opt.Parent = optList
            Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 5)

            local optLabel = Instance.new("TextLabel")
            optLabel.Size = UDim2.new(1, -16, 1, 0)
            optLabel.Position = UDim2.fromOffset(8, 0)
            optLabel.BackgroundTransparency = 1
            optLabel.Text = formatFn(option)
            optLabel.TextColor3 = white
            optLabel.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
            optLabel.TextSize = 9
            optLabel.TextXAlignment = Enum.TextXAlignment.Left
            optLabel.TextTruncate = Enum.TextTruncate.AtEnd
            optLabel.ZIndex = 52
            optLabel.Parent = opt

            if isSelected then
                local check = Instance.new("TextLabel")
                check.Size = UDim2.fromOffset(16, rowHeight)
                check.Position = UDim2.new(1, -16, 0, 0)
                check.BackgroundTransparency = 1
                check.Text = "✓"
                check.TextColor3 = white
                check.Font = Enum.Font.GothamBold
                check.TextSize = 10
                check.ZIndex = 52
                check.Parent = opt
            end

            opt.MouseEnter:Connect(function()
                if not isSelected then
                    opt.BackgroundColor3 = purple
                    opt.BackgroundTransparency = 0.75
                end
            end)
            opt.MouseLeave:Connect(function()
                if not isSelected then
                    opt.BackgroundColor3 = cardColor
                    opt.BackgroundTransparency = 0
                end
            end)

            opt.Activated:Connect(function()
                current = option
                selLabel.Text = formatFn(option)
                closeThis()
                activeDropdownClose = nil
                callback(option)
            end)
        end
    end)

    callback(current)

    return holder, getSelected
end

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(names, p.Name)
    end
    table.sort(names)
    if #names == 0 then
        table.insert(names, LocalPlayer.Name)
    end
    return names
end

-- Cria um pequeno botão "↻" de atualizar lista de players, já com ícone
local function makeRefreshButton(parent, x, y, onRefresh)
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.fromOffset(28, 28)
    refreshBtn.Position = UDim2.new(1, -35, 0, y)
    refreshBtn.BackgroundColor3 = dark
    refreshBtn.Text = "↻"
    refreshBtn.TextColor3 = purple
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 14
    refreshBtn.Parent = parent
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 5)

    do
        local icon = addIcon(refreshBtn, "refresh-cw", 14, purple)
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.new(0.5, 0, 0.5, 0)
            refreshBtn.Text = ""
        end
    end

    refreshBtn.Activated:Connect(onRefresh)
    return refreshBtn
end

-- Monta a mensagem ";cmd nome [sufixo]" sem nunca grudar nome com o que vem depois
local function buildPlayerMessage(cmd, player, suffix)
    if suffix and suffix ~= "" then
        return string.format(";%s %s %s", cmd, tostring(player), suffix)
    end
    return string.format(";%s %s", cmd, tostring(player))
end

-- Card de comando de título com dropdown de player embutido
local function makeTitleCommandCard(parent, nextOrder, def)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -5, 0, 108)
    card.BackgroundColor3 = cardColor
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -14, 0, 18)
    txt.Position = UDim2.fromOffset(7, 5)
    txt.BackgroundTransparency = 1
    txt.Text = def.label
    txt.TextColor3 = white
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 10
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = card

    local ddHolder = Instance.new("Frame")
    ddHolder.Size = UDim2.new(1, -46, 0, 28)
    ddHolder.Position = UDim2.fromOffset(7, 26)
    ddHolder.BackgroundTransparency = 1
    ddHolder.Parent = card

    local _, getSelected = dropdown(ddHolder, getPlayerNames(), function() end)

    makeRefreshButton(card, 0, 26, function()
        closeActiveDropdown()
        for _, c in ipairs(ddHolder:GetChildren()) do
            c:Destroy()
        end
        local _, newGetter = dropdown(ddHolder, getPlayerNames(), function() end)
        getSelected = newGetter
    end)

    local send = makeButton(card, "ENVIAR ;" .. def.cmd, green, function()
        local player = getSelected and getSelected() or LocalPlayer.Name
        sendMessage(buildPlayerMessage(def.cmd, player, def.suffix))
    end, "send")
    send.Size = UDim2.new(1, -14, 0, 28)
    send.Position = UDim2.fromOffset(7, 72)
end

-- Card do ;kick: dropdown de player + caixa de texto com o motivo
local function makeKickCard(parent, nextOrder)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -5, 0, 150)
    card.BackgroundColor3 = cardColor
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)

    local plLabel = Instance.new("TextLabel")
    plLabel.Size = UDim2.new(1, -46, 0, 14)
    plLabel.Position = UDim2.fromOffset(7, 6)
    plLabel.BackgroundTransparency = 1
    plLabel.Text = "JOGADOR"
    plLabel.TextColor3 = gray
    plLabel.Font = Enum.Font.GothamBold
    plLabel.TextSize = 8
    plLabel.TextXAlignment = Enum.TextXAlignment.Left
    plLabel.Parent = card

    local ddHolder = Instance.new("Frame")
    ddHolder.Size = UDim2.new(1, -46, 0, 28)
    ddHolder.Position = UDim2.fromOffset(7, 22)
    ddHolder.BackgroundTransparency = 1
    ddHolder.Parent = card

    local _, getPlayer = dropdown(ddHolder, getPlayerNames(), function() end)

    makeRefreshButton(card, 0, 22, function()
        closeActiveDropdown()
        for _, c in ipairs(ddHolder:GetChildren()) do
            c:Destroy()
        end
        local _, newGetter = dropdown(ddHolder, getPlayerNames(), function() end)
        getPlayer = newGetter
    end)

    local reasonLabel = Instance.new("TextLabel")
    reasonLabel.Size = UDim2.new(1, -14, 0, 14)
    reasonLabel.Position = UDim2.fromOffset(7, 56)
    reasonLabel.BackgroundTransparency = 1
    reasonLabel.Text = "MOTIVO"
    reasonLabel.TextColor3 = gray
    reasonLabel.Font = Enum.Font.GothamBold
    reasonLabel.TextSize = 8
    reasonLabel.TextXAlignment = Enum.TextXAlignment.Left
    reasonLabel.Parent = card

    local reasonBox = Instance.new("TextBox")
    reasonBox.Size = UDim2.new(1, -14, 0, 28)
    reasonBox.Position = UDim2.fromOffset(7, 72)
    reasonBox.BackgroundColor3 = dark
    reasonBox.TextColor3 = white
    reasonBox.PlaceholderColor3 = gray
    reasonBox.PlaceholderText = "Digite o motivo do kick..."
    reasonBox.Text = ""
    reasonBox.ClearTextOnFocus = false
    reasonBox.Font = Enum.Font.Gotham
    reasonBox.TextSize = 10
    reasonBox.Parent = card
    Instance.new("UICorner", reasonBox).CornerRadius = UDim.new(0, 6)

    local reasonPad = Instance.new("UIPadding")
    reasonPad.PaddingLeft = UDim.new(0, 6)
    reasonPad.PaddingRight = UDim.new(0, 6)
    reasonPad.Parent = reasonBox

    local sendKick = makeButton(card, "ENVIAR ;kick", red, function()
        local player = getPlayer and getPlayer() or LocalPlayer.Name
        local reason = reasonBox.Text
        if reason == "" then
            reason = "Sem motivo informado."
        end
        sendMessage(buildPlayerMessage("kick", player, reason))
    end, "user-x")
    sendKick.Size = UDim2.new(1, -14, 0, 28)
    sendKick.Position = UDim2.fromOffset(7, 108)
end

-- ===== Painéis (um ScrollingFrame por aba, cada um com rolagem própria) =====
local allPanels = {}

local function createPanel()
    local scrollPanel = Instance.new("ScrollingFrame")
    scrollPanel.Size = UDim2.new(1, -14, 1, -104)
    scrollPanel.Position = UDim2.fromOffset(7, 100)
    scrollPanel.BackgroundTransparency = 1
    scrollPanel.BorderSizePixel = 0
    scrollPanel.ScrollBarThickness = 3
    scrollPanel.ScrollBarImageColor3 = purple
    scrollPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollPanel.CanvasSize = UDim2.new()
    scrollPanel.Visible = false
    scrollPanel.Parent = clipFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollPanel

    local orderCounter = 0
    local function nextOrder()
        orderCounter = orderCounter + 1
        return orderCounter
    end

    local function clearPanel()
        orderCounter = 0
        for _, v in ipairs(scrollPanel:GetChildren()) do
            if v:IsA("GuiObject") then
                v:Destroy()
            end
        end
    end

    table.insert(allPanels, scrollPanel)
    return scrollPanel, nextOrder, clearPanel
end

-- ===== Aba TEXTOS =====
local textsPanel, textsOrder, clearTexts = createPanel()

local function buildTexts()
    clearTexts()
    for _, category in ipairs(texts) do
        makeLabel(textsPanel, textsOrder, category.category)
        for _, message in ipairs(category.items) do
            makeCard(textsPanel, textsOrder, message)
        end
    end
end

-- ===== Aba ORDENS (comandos militares de marcha) =====
local ordersPanel, ordersOrder, clearOrders = createPanel()

local function buildOrders()
    clearOrders()
    makeLabel(ordersPanel, ordersOrder, "ORDENS DE MARCHA")
    for _, cmdText in ipairs(marchCommands) do
        makeCard(ordersPanel, ordersOrder, cmdText)
    end
end

-- ===== Aba COMANDOS =====
local commandsPanel, commandsOrder, clearCommands = createPanel()

local function buildCommands()
    clearCommands()

    makeLabel(commandsPanel, commandsOrder, "COMANDOS")
    for _, cmdText in ipairs(simpleCommands) do
        makeCard(commandsPanel, commandsOrder, cmdText)
    end

    makeLabel(commandsPanel, commandsOrder, "KICK")
    makeKickCard(commandsPanel, commandsOrder)

    makeLabel(commandsPanel, commandsOrder, "TÍTULOS COM PLAYER")
    for _, def in ipairs(titleCommands) do
        makeTitleCommandCard(commandsPanel, commandsOrder, def)
    end

    makeLabel(commandsPanel, commandsOrder, "PONTOS")

    local pointsCard = Instance.new("Frame")
    pointsCard.Size = UDim2.new(1, -5, 0, 142)
    pointsCard.BackgroundColor3 = cardColor
    pointsCard.LayoutOrder = commandsOrder()
    pointsCard.Parent = commandsPanel
    Instance.new("UICorner", pointsCard).CornerRadius = UDim.new(0, 7)

    local ptPlayerLabel = Instance.new("TextLabel")
    ptPlayerLabel.Size = UDim2.new(1, -46, 0, 14)
    ptPlayerLabel.Position = UDim2.fromOffset(7, 6)
    ptPlayerLabel.BackgroundTransparency = 1
    ptPlayerLabel.Text = "JOGADOR"
    ptPlayerLabel.TextColor3 = gray
    ptPlayerLabel.Font = Enum.Font.GothamBold
    ptPlayerLabel.TextSize = 8
    ptPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
    ptPlayerLabel.Parent = pointsCard

    local ptHolder = Instance.new("Frame")
    ptHolder.Size = UDim2.new(1, -46, 0, 28)
    ptHolder.Position = UDim2.fromOffset(7, 22)
    ptHolder.BackgroundTransparency = 1
    ptHolder.Parent = pointsCard

    local _, getPointPlayer = dropdown(ptHolder, getPlayerNames(), function() end)

    makeRefreshButton(pointsCard, 0, 22, function()
        closeActiveDropdown()
        for _, c in ipairs(ptHolder:GetChildren()) do
            c:Destroy()
        end
        local _, newGetter = dropdown(ptHolder, getPlayerNames(), function() end)
        getPointPlayer = newGetter
    end)

    local ptValueLabel = Instance.new("TextLabel")
    ptValueLabel.Size = UDim2.new(1, -14, 0, 14)
    ptValueLabel.Position = UDim2.fromOffset(7, 56)
    ptValueLabel.BackgroundTransparency = 1
    ptValueLabel.Text = "QUANTIDADE DE PONTOS"
    ptValueLabel.TextColor3 = gray
    ptValueLabel.Font = Enum.Font.GothamBold
    ptValueLabel.TextSize = 8
    ptValueLabel.TextXAlignment = Enum.TextXAlignment.Left
    ptValueLabel.Parent = pointsCard

    local ptValueHolder = Instance.new("Frame")
    ptValueHolder.Size = UDim2.new(1, -14, 0, 28)
    ptValueHolder.Position = UDim2.fromOffset(7, 72)
    ptValueHolder.BackgroundTransparency = 1
    ptValueHolder.Parent = pointsCard

    local currentPoint = pointValues[1]
    local _, getPoint = dropdown(ptValueHolder, pointValues, function(value)
        currentPoint = value
    end, formatPoint)

    local sendPoint = makeButton(pointsCard, "ENVIAR ;titler", purple, function()
        local player = getPointPlayer and getPointPlayer() or LocalPlayer.Name
        local value = getPoint and getPoint() or currentPoint
        -- string.format garante o espaço entre o nome e a quantidade,
        -- nunca gruda "nomequantidade" num token só.
        sendMessage(string.format(";titler %s %s", tostring(player), formatPoint(value)))
    end, "send")
    sendPoint.Size = UDim2.new(1, -14, 0, 28)
    sendPoint.Position = UDim2.fromOffset(7, 106)

    makeLabel(commandsPanel, commandsOrder, "DISTÂNCIA DO CD")

    local cdCard = Instance.new("Frame")
    cdCard.Size = UDim2.new(1, -5, 0, 68)
    cdCard.BackgroundColor3 = cardColor
    cdCard.LayoutOrder = commandsOrder()
    cdCard.Parent = commandsPanel
    Instance.new("UICorner", cdCard).CornerRadius = UDim.new(0, 7)

    local cdHolder = Instance.new("Frame")
    cdHolder.Size = UDim2.new(1, -14, 0, 28)
    cdHolder.Position = UDim2.fromOffset(7, 7)
    cdHolder.BackgroundTransparency = 1
    cdHolder.Parent = cdCard

    local cdValue = 10
    local _, getCd = dropdown(cdHolder, {10, 15, 20, 25, 30, 35, 40, 45, 50}, function(value)
        cdValue = value
    end)

    local sendCd = makeButton(cdCard, "ENVIAR ;cd", purple, function()
        local value = getCd and getCd() or cdValue
        sendMessage(";cd " .. tostring(value))
    end, "send")
    sendCd.Size = UDim2.new(1, -14, 0, 28)
    sendCd.Position = UDim2.fromOffset(7, 39)
end

-- ===== Aba CMD/TXT PP (textos e comandos personalizados) =====
local customPanel, customOrder, clearCustom = createPanel()

local function buildCustom()
    clearCustom()

    if #customTexts == 0 and #customCommands == 0 then
        makeLabel(customPanel, customOrder, "CMD/TXT PP")

        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -5, 0, 50)
        empty.BackgroundTransparency = 1
        empty.Text = "Nenhum texto ou comando personalizado ainda. Adicione um na aba CONFIG."
        empty.TextColor3 = gray
        empty.TextWrapped = true
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 9
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.LayoutOrder = customOrder()
        empty.Parent = customPanel
        return
    end

    if #customTexts > 0 then
        makeLabel(customPanel, customOrder, "TEXTOS PERSONALIZADOS")

        for i, message in ipairs(customTexts) do
            local index = i
            makeCard(customPanel, customOrder, message, true, function()
                table.remove(customTexts, index)
                saveData()
                buildCustom()
            end)
        end
    end

    if #customCommands > 0 then
        makeLabel(customPanel, customOrder, "COMANDOS PERSONALIZADOS")

        for i, command in ipairs(customCommands) do
            local index = i
            makeCard(customPanel, customOrder, command, true, function()
                table.remove(customCommands, index)
                saveData()
                buildCustom()
            end)
        end
    end
end

-- ===== Aba CONFIG. =====
local settingsPanel, settingsOrder, clearSettings = createPanel()

local function buildSettings()
    clearSettings()

    -- ===== Bloco: adicionar texto =====
    local addTextCard = Instance.new("Frame")
    addTextCard.Size = UDim2.new(1, -5, 0, 108)
    addTextCard.BackgroundColor3 = cardColor
    addTextCard.LayoutOrder = settingsOrder()
    addTextCard.Parent = settingsPanel
    Instance.new("UICorner", addTextCard).CornerRadius = UDim.new(0, 7)

    local addTextLabel = Instance.new("TextLabel")
    addTextLabel.Size = UDim2.new(1, -14, 0, 20)
    addTextLabel.Position = UDim2.fromOffset(7, 6)
    addTextLabel.BackgroundTransparency = 1
    addTextLabel.Text = "ADICIONAR TEXTO"
    addTextLabel.TextColor3 = purple
    addTextLabel.Font = Enum.Font.GothamBold
    addTextLabel.TextSize = 10
    addTextLabel.TextXAlignment = Enum.TextXAlignment.Left
    addTextLabel.Parent = addTextCard

    local textInput = Instance.new("TextBox")
    textInput.Size = UDim2.new(1, -14, 0, 42)
    textInput.Position = UDim2.fromOffset(7, 28)
    textInput.BackgroundColor3 = dark
    textInput.TextColor3 = white
    textInput.PlaceholderColor3 = gray
    textInput.PlaceholderText = "Digite seu novo texto..."
    textInput.Text = ""
    textInput.TextWrapped = true
    textInput.MultiLine = true
    textInput.ClearTextOnFocus = false
    textInput.Font = Enum.Font.Gotham
    textInput.TextSize = 10
    textInput.Parent = addTextCard
    Instance.new("UICorner", textInput).CornerRadius = UDim.new(0, 6)
    local textPad = Instance.new("UIPadding")
    textPad.PaddingLeft = UDim.new(0, 6)
    textPad.PaddingRight = UDim.new(0, 6)
    textPad.PaddingTop = UDim.new(0, 4)
    textPad.Parent = textInput

    local saveText = makeButton(addTextCard, "SALVAR TEXTO", purple, function()
        local value = textInput.Text

        if value ~= "" then
            table.insert(customTexts, value)
            textInput.Text = ""
            saveData()
            buildCustom()
            buildSettings()
        end
    end, "plus")
    saveText.Size = UDim2.new(1, -14, 0, 28)
    saveText.Position = UDim2.fromOffset(7, 74)

    -- ===== Bloco: adicionar comando =====
    local addCmdCard = Instance.new("Frame")
    addCmdCard.Size = UDim2.new(1, -5, 0, 108)
    addCmdCard.BackgroundColor3 = cardColor
    addCmdCard.LayoutOrder = settingsOrder()
    addCmdCard.Parent = settingsPanel
    Instance.new("UICorner", addCmdCard).CornerRadius = UDim.new(0, 7)

    local addCmdLabel = Instance.new("TextLabel")
    addCmdLabel.Size = UDim2.new(1, -14, 0, 20)
    addCmdLabel.Position = UDim2.fromOffset(7, 6)
    addCmdLabel.BackgroundTransparency = 1
    addCmdLabel.Text = "ADICIONAR COMANDO"
    addCmdLabel.TextColor3 = purple
    addCmdLabel.Font = Enum.Font.GothamBold
    addCmdLabel.TextSize = 10
    addCmdLabel.TextXAlignment = Enum.TextXAlignment.Left
    addCmdLabel.Parent = addCmdCard

    local commandInput = Instance.new("TextBox")
    commandInput.Size = UDim2.new(1, -14, 0, 42)
    commandInput.Position = UDim2.fromOffset(7, 28)
    commandInput.BackgroundColor3 = dark
    commandInput.TextColor3 = white
    commandInput.PlaceholderColor3 = gray
    commandInput.PlaceholderText = "Digite seu novo comando..."
    commandInput.Text = ""
    commandInput.TextWrapped = true
    commandInput.MultiLine = true
    commandInput.ClearTextOnFocus = false
    commandInput.Font = Enum.Font.Gotham
    commandInput.TextSize = 10
    commandInput.Parent = addCmdCard
    Instance.new("UICorner", commandInput).CornerRadius = UDim.new(0, 6)
    local cmdPad = Instance.new("UIPadding")
    cmdPad.PaddingLeft = UDim.new(0, 6)
    cmdPad.PaddingRight = UDim.new(0, 6)
    cmdPad.PaddingTop = UDim.new(0, 4)
    cmdPad.Parent = commandInput

    local saveCommand = makeButton(addCmdCard, "SALVAR COMANDO", purple, function()
        local value = commandInput.Text

        if value ~= "" then
            table.insert(customCommands, value)
            commandInput.Text = ""
            saveData()
            buildCustom()
            buildSettings()
        end
    end, "plus")
    saveCommand.Size = UDim2.new(1, -14, 0, 28)
    saveCommand.Position = UDim2.fromOffset(7, 74)

    -- ===== Status de salvamento =====
    makeLabel(settingsPanel, settingsOrder, "SALVAMENTO")

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -5, 0, 40)
    status.BackgroundColor3 = cardColor
    status.TextColor3 = white
    status.TextWrapped = true
    status.Font = Enum.Font.Gotham
    status.TextSize = 9
    status.LayoutOrder = settingsOrder()

    if writefile and readfile and isfile and makefolder then
        status.Text = "Salvamento em arquivos disponível. Os dados são carregados automaticamente."
    else
        status.Text = "As funções de arquivos não foram detectadas. Os dados não poderão ser salvos permanentemente."
    end

    status.Parent = settingsPanel
    Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

    local saveNow = makeButton(settingsPanel, "SALVAR AGORA", green, function()
        status.Text = saveData() and "Dados salvos com sucesso!" or "Não foi possível salvar os dados."
    end, "save")
    saveNow.Size = UDim2.new(1, -5, 0, 30)
    saveNow.LayoutOrder = settingsOrder()
end

-- ===== Constrói todas as abas uma única vez. Trocar de aba só alterna =====
-- ===== Visible, então a rolagem de cada uma fica totalmente independente =====
buildTexts()
buildOrders()
buildCommands()
buildCustom()
buildSettings()

local function createTab(name, targetPanel)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = cardColor
    b.Text = name
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextScaled = true
    b.Parent = tabs
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 9
    constraint.MinTextSize = 6
    constraint.Parent = b

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 3)
    pad.PaddingRight = UDim.new(0, 3)
    pad.Parent = b

    b.Activated:Connect(function()
        closeActiveDropdown()

        for _, child in ipairs(tabs:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = cardColor
            end
        end

        b.BackgroundColor3 = purple

        for _, p in ipairs(allPanels) do
            p.Visible = (p == targetPanel)
        end
    end)

    return b
end

createTab("TEXTOS", textsPanel).BackgroundColor3 = purple
createTab("ORDENS", ordersPanel)
createTab("COMANDOS", commandsPanel)
createTab("CMD/TXT PP", customPanel)
createTab("CONFIG.", settingsPanel)

textsPanel.Visible = true

-- ===== Minimizar / Restaurar (bubble) =====
local minimized = false

local function setMinimized(state)
    closeActiveDropdown()
    minimized = state
    main.Visible = not state
    bubble.Visible = state
end

minimize.Activated:Connect(function()
    setMinimized(true)
end)

bubble.Activated:Connect(function()
    setMinimized(false)
end)

-- ===== Arrastar (janela principal e bubble) =====
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragStart
    local startPosition
    local moved = false

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            moved = false
            dragStart = input.Position
            startPosition = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 3 then moved = true end

            frame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    return function() return moved end
end

makeDraggable(main, header)
makeDraggable(bubble, bubble)

local API = {}

function API.Destroy()
    saveData()
    gui:Destroy()
    ENV.PranchataTreinos = nil
end

ENV.PranchataTreinos = API

close.Activated:Connect(function()
    API.Destroy()
end)

saveData()
