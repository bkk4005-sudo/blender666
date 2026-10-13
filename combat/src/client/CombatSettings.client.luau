local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local root = ReplicatedStorage:WaitForChild("CombatFoundation")
local Bindings = require(root.Shared:WaitForChild("InputBindings"))
local player = Players.LocalPlayer
local remote = root:WaitForChild("CombatSettingsRemote")
local gui = Instance.new("ScreenGui")
gui.Name = "CombatSettings"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")
local function button(parent, text, size, position)
    local item = Instance.new("TextButton")
    item.Size, item.Position = size, position
    item.Text, item.Font, item.TextSize = text, Enum.Font.GothamMedium, 16
    item.BackgroundColor3, item.TextColor3 = Color3.fromRGB(39, 38, 42), Color3.fromRGB(231, 224, 205)
    item.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = item
    item.Parent = parent
    return item
end
local open = button(gui, "Управление", UDim2.fromOffset(130, 36), UDim2.new(1, -146, 0, 18))
open.Name = "OpenSettings"
local panel = Instance.new("Frame")
panel.Size, panel.Position, panel.AnchorPoint = UDim2.fromOffset(430, 452), UDim2.fromScale(.5, .5), Vector2.new(.5, .5)
panel.BackgroundColor3, panel.BorderSizePixel, panel.Visible = Color3.fromRGB(22, 22, 26), 0, false
panel.Parent = gui
panel.Name = "Panel"
local scale = Instance.new("UIScale")
scale.Parent = panel
local function resize()
    local size = gui.AbsoluteSize
    scale.Scale = math.max(.2, math.min(1, (size.X - 24) / 430, (size.Y - 24) / 452))
end
resize()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
local title = button(panel, "Настройки управления   ×", UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 12))
title.Name = "CloseSettings"
local status = Instance.new("TextLabel")
status.Size, status.Position = UDim2.new(1, -28, 0, 54), UDim2.fromOffset(14, 345)
status.BackgroundTransparency, status.TextWrapped = 1, true
status.Font, status.TextSize, status.TextColor3 = Enum.Font.Gotham, 14, Color3.fromRGB(201, 193, 171)
status.Text = "Выберите действие, затем нажмите клавишу. Esc — отмена. WASD зарезервированы для движения."
status.Parent = panel
local current, rows, capturing = table.clone(Bindings.Defaults), {}, nil
local hasLocalEdits = false
local readable = {MouseButton1 = "ЛКМ", MouseButton2 = "ПКМ", MouseButton3 = "Средняя кнопка", Space = "Пробел", LeftShift = "Shift"}
local function render()
    for _, action in Bindings.Order do rows[action].Text = Bindings.Labels[action] .. "    [ " .. (readable[current[action]] or current[action]) .. " ]" end
end
local function apply(values)
    current = values
    for action, name in values do player:SetAttribute("Binding_" .. action, name) end
    render()
end
local saveVersion = 0
local function scheduleSave()
    saveVersion += 1
    local version = saveVersion
    task.delay(.35, function()
        if version == saveVersion then remote:FireServer("Save", current) end
    end)
end
for index, action in Bindings.Order do
    local row = button(panel, "", UDim2.new(1, -28, 0, 35), UDim2.fromOffset(14, 62 + (index - 1) * 40))
    rows[action] = row
    row.Name = action
    row.Activated:Connect(function()
        capturing = action
        status.Text = "Нажмите новую клавишу для «" .. Bindings.Labels[action] .. "». Esc — отмена."
    end)
end
local function setOpen(value)
    capturing = nil
    panel.Visible = value
    player:SetAttribute("CombatSettingsOpen", value)
    resize()
end
open.Activated:Connect(function() setOpen(not panel.Visible) end)
title.Activated:Connect(function() setOpen(false) end)
local reset = button(panel, "Вернуть по умолчанию", UDim2.new(1, -28, 0, 36), UDim2.fromOffset(14, 402))
reset.Name = "ResetBindings"
reset.Activated:Connect(function()
    capturing = nil
    hasLocalEdits = true
    apply(table.clone(Bindings.Defaults))
    scheduleSave()
end)
UserInputService.InputBegan:Connect(function(input)
    if not panel.Visible then return end
    if input.KeyCode == Enum.KeyCode.Escape then setOpen(false); return end
    if not capturing then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
        local mouse = UserInputService:GetMouseLocation()
        for _, object in player.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
            if object:IsA("GuiButton") then return end
        end
    end
    local name = if input.KeyCode ~= Enum.KeyCode.Unknown then input.KeyCode.Name else input.UserInputType.Name
    if not Bindings.resolve(name) then status.Text = "Эта клавиша недоступна. Выберите другую."; return end
    for action, existing in current do
        if action ~= capturing and name == existing then status.Text = "Клавиша уже назначена: " .. Bindings.Labels[action]; return end
    end
    local values = table.clone(current)
    values[capturing] = name
    capturing = nil
    hasLocalEdits = true
    apply(values)
    status.Text = "Назначение применено. Сохранение…"
    scheduleSave()
end)
remote.OnClientEvent:Connect(function(kind, values)
    if kind == "Loaded" then
        local valid = Bindings.validate(values)
        if valid and not hasLocalEdits then apply(valid) end
    elseif kind == "Saved" then status.Text = "Настройки сохранены."
    elseif kind == "Unavailable" then status.Text = "Назначения работают в этой сессии. Постоянное сохранение сейчас недоступно." end
end)
apply(current)
remote:FireServer("Load")
