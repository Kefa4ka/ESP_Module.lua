-- ESP_Module.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Enabled = false,
    Boxes = true,
    Names = true,
    Health = true,
    Distance = true,
    TeamCheck = true,
    TeamColor = Color3.fromRGB(0, 255, 0), -- Колір для союзників
    EnemyColor = Color3.fromRGB(255, 0, 0), -- Колір для ворогів
    LineMode = "Bottom", -- "None", "Center", "Bottom"
    BoxStyle = "Corner", -- "Full", "Corner"
    BoxThickness = 2,
    TextSize = 14,
    VisibleOnly = false, -- Показувати ESP тільки для видимих гравців
    LinesToPlayer = false, -- Лінії від гравця до гравця
}

local ESP_UI = {}
local Connections = {}
local ViewportSize = workspace.CurrentCamera.ViewportSize
local FONT = Enum.Font.SourceSans
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)
local OUTLINE_THICKNESS = 1

-- Допоміжні функції
local function WorldToScreen(position)
    local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function GetPlayerHeadPosition(player)
    if player and player.Character and player.Character:FindFirstChild("Head") then
        return player.Character.Head.Position
    end
    return nil
end

local function GetPlayerBounds(player)
    local character = player.Character
    if not character then return nil end

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local hasVisiblePart = false

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Magnitude > 0 and part.CanCollide then
            local corners = {
                part.CFrame * Vector3.new(part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2),
                part.CFrame * Vector3.new(-part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2),
                part.CFrame * Vector3.new(part.Size.X / 2, -part.Size.Y / 2, part.Size.Z / 2),
                part.CFrame * Vector3.new(part.Size.X / 2, part.Size.Y / 2, -part.Size.Z / 2),
                part.CFrame * Vector3.new(-part.Size.X / 2, -part.Size.Y / 2, part.Size.Z / 2),
                part.CFrame * Vector3.new(part.Size.X / 2, -part.Size.Y / 2, -part.Size.Z / 2),
                part.CFrame * Vector3.new(-part.Size.X / 2, part.Size.Y / 2, -part.Size.Z / 2),
                part.CFrame * Vector3.new(-part.Size.X / 2, -part.Size.Y / 2, -part.Size.Z / 2),
            }
            
            for _, corner in ipairs(corners) do
                local screenPos, onScreen = WorldToScreen(corner)
                if onScreen then
                    minX = math.min(minX, screenPos.X)
                    minY = math.min(minY, screenPos.Y)
                    maxX = math.max(maxX, screenPos.X)
                    maxY = math.max(maxY, screenPos.Y)
                    hasVisiblePart = true
                end
            end
        end
    end

    if hasVisiblePart then
        local width = maxX - minX
        local height = maxY - minY
        return {
            Min = Vector2.new(minX, minY),
            Max = Vector2.new(maxX, maxY),
            Center = Vector2.new(minX + width / 2, minY + height / 2),
            Size = Vector2.new(width, height)
        }
    end
    return nil
end

local function GetPlayerColor(player)
    if ESP.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return ESP.TeamColor
    else
        return ESP.EnemyColor
    end
end

local function CreateUIElement(className, parent)
    local element = Instance.new(className)
    element.ZIndex = 10 -- Щоб було поверх усього
    element.Parent = parent
    return element
end

local function CreateTextLabel(parent, text, position, color, size, outlineColor, outlineThickness)
    local textLabel = CreateUIElement("TextLabel", parent)
    textLabel.Text = text
    textLabel.Size = UDim2.new(0, 200, 0, size * 1.5) -- Приблизний розмір
    textLabel.Position = UDim2.new(0, position.X, 0, position.Y)
    textLabel.TextColor3 = color
    textLabel.TextScaled = false
    textLabel.TextSize = size
    textLabel.Font = FONT
    textLabel.BackgroundTransparency = 1
    textLabel.TextStrokeColor3 = outlineColor
    textLabel.TextStrokeTransparency = outlineThickness and 0 or 1
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    return textLabel
end

local function CreateBox(parent, position, size, color, thickness, style)
    if style == "Full" then
        local boxFrame = CreateUIElement("Frame", parent)
        boxFrame.Position = UDim2.new(0, position.X, 0, position.Y)
        boxFrame.Size = UDim2.new(0, size.X, 0, size.Y)
        boxFrame.BackgroundColor3 = color
        boxFrame.BackgroundTransparency = 1
        boxFrame.BorderColor3 = color
        boxFrame.BorderSizePixel = thickness
        return {boxFrame}
    elseif style == "Corner" then
        local corners = {}
        local cornerSize = size.X * 0.2 -- Довжина кута

        -- Верхній лівий
        local tlH = CreateUIElement("Frame", parent)
        tlH.Position = UDim2.new(0, position.X - thickness, 0, position.Y - thickness)
        tlH.Size = UDim2.new(0, cornerSize + thickness, 0, thickness)
        tlH.BackgroundColor3 = color
        table.insert(corners, tlH)

        local tlV = CreateUIElement("Frame", parent)
        tlV.Position = UDim2.new(0, position.X - thickness, 0, position.Y - thickness)
        tlV.Size = UDim2.new(0, thickness, 0, cornerSize + thickness)
        tlV.BackgroundColor3 = color
        table.insert(corners, tlV)

        -- Верхній правий
        local trH = CreateUIElement("Frame", parent)
        trH.Position = UDim2.new(0, position.X + size.X - cornerSize, 0, position.Y - thickness)
        trH.Size = UDim2.new(0, cornerSize + thickness, 0, thickness)
        trH.BackgroundColor3 = color
        table.insert(corners, trH)

        local trV = CreateUIElement("Frame", parent)
        trV.Position = UDim2.new(0, position.X + size.X, 0, position.Y - thickness)
        trV.Size = UDim2.new(0, thickness, 0, cornerSize + thickness)
        trV.BackgroundColor3 = color
        table.insert(corners, trV)

        -- Нижній лівий
        local blH = CreateUIElement("Frame", parent)
        blH.Position = UDim2.new(0, position.X - thickness, 0, position.Y + size.Y - thickness)
        blH.Size = UDim2.new(0, cornerSize + thickness, 0, thickness)
        blH.BackgroundColor3 = color
        table.insert(corners, blH)

        local blV = CreateUIElement("Frame", parent)
        blV.Position = UDim2.new(0, position.X - thickness, 0, position.Y + size.Y - cornerSize)
        blV.Size = UDim2.new(0, thickness, 0, cornerSize + thickness)
        blV.BackgroundColor3 = color
        table.insert(corners, blV)

        -- Нижній правий
        local brH = CreateUIElement("Frame", parent)
        brH.Position = UDim2.new(0, position.X + size.X - cornerSize, 0, position.Y + size.Y - thickness)
        brH.Size = UDim2.new(0, cornerSize + thickness, 0, thickness)
        brH.BackgroundColor3 = color
        table.insert(corners, brH)

        local brV = CreateUIElement("Frame", parent)
        brV.Position = UDim2.new(0, position.X + size.X, 0, position.Y + size.Y - cornerSize)
        brV.Size = UDim2.new(0, thickness, 0, cornerSize + thickness)
        brV.BackgroundColor3 = color
        table.insert(corners, brV)

        return corners
    end
    return {}
end

local function CreateLine(parent, p1, p2, color, thickness)
    local line = CreateUIElement("Frame", parent)
    local distance = (p1 - p2).Magnitude
    local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))

    line.Size = UDim2.new(0, distance, 0, thickness)
    line.Position = UDim2.new(0, p1.X, 0, p1.Y)
    line.Rotation = angle
    line.BackgroundColor3 = color
    return line
end

local function CreateHealthBar(parent, position, size, healthRatio)
    local bg = CreateUIElement("Frame", parent)
    bg.Position = UDim2.new(0, position.X - 5, 0, position.Y)
    bg.Size = UDim2.new(0, 3, 0, size.Y)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    
    local fill = CreateUIElement("Frame", parent)
    fill.Position = UDim2.new(0, position.X - 5, 0, position.Y + size.Y * (1 - healthRatio))
    fill.Size = UDim2.new(0, 3, 0, size.Y * healthRatio)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0):Lerp(Color3.fromRGB(255, 0, 0), 1 - healthRatio)

    return {bg, fill}
end

local function RenderESP()
    if not ESP.Enabled then return end

    -- Очищаємо старі елементи
    for _, uiElement in pairs(ESP_UI) do
        if uiElement.Parent then
            uiElement:Destroy()
        end
    end
    ESP_UI = {}

    local screenGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ESP_Overlay")
    if not screenGui then
        screenGui = CreateUIElement("ScreenGui", LocalPlayer.PlayerGui)
        screenGui.Name = "ESP_Overlay"
        screenGui.DisplayOrder = 100 -- Гарантує, що він буде вище за інші GUI
        screenGui.IgnoreGuiInset = true -- Щоб не враховував верхній бар Roblox
    end

    local localPlayerHeadPos = GetPlayerHeadPosition(LocalPlayer)
    if not localPlayerHeadPos then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            local head = character:FindFirstChild("Head")
            local root = character:FindFirstChild("HumanoidRootPart")

            if not head or not root or humanoid.Health <= 0 then continue end
            
            local playerColor = GetPlayerColor(player)
            local headPos, headOnScreen = WorldToScreen(head.Position)
            local rootPos, rootOnScreen = WorldToScreen(root.Position)

            if ESP.VisibleOnly then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude

                local result = workspace:Raycast(LocalPlayer.Character.Head.Position, head.Position - LocalPlayer.Character.Head.Position, raycastParams)
                if result and result.Instance:IsDescendantOf(character) then
                    -- Частина гравця видима
                else
                    continue
                end
            end

            local bounds = GetPlayerBounds(player)
            if not bounds then continue end

            local boxWidth = bounds.Size.X
            local boxHeight = bounds.Size.Y
            local boxX = bounds.Min.X
            local boxY = bounds.Min.Y

            -- Box ESP
            if ESP.Boxes then
                local boxElements = CreateBox(screenGui, Vector2.new(boxX, boxY), Vector2.new(boxWidth, boxHeight), playerColor, ESP.BoxThickness, ESP.BoxStyle)
                for _, el in pairs(boxElements) do
                    table.insert(ESP_UI, el)
                end
            end

            local textYOffset = boxY - ESP.TextSize - 5 -- Початкова позиція тексту над головою
            local textX = boxX + boxWidth / 2

            -- Name ESP
            if ESP.Names then
                local nameLabel = CreateTextLabel(screenGui, player.DisplayName, Vector2.new(textX, textYOffset), TEXT_COLOR, ESP.TextSize, OUTLINE_COLOR, OUTLINE_THICKNESS)
                table.insert(ESP_UI, nameLabel)
                textYOffset = textYOffset + ESP.TextSize
            end

            -- Health Bar & Health Text
            if ESP.Health then
                local healthRatio = humanoid.Health / humanoid.MaxHealth
                local healthBarElements = CreateHealthBar(screenGui, Vector2.new(boxX - 5, boxY), Vector2.new(boxWidth, boxHeight), healthRatio)
                 for _, el in pairs(healthBarElements) do
                    table.insert(ESP_UI, el)
                end

                local healthLabel = CreateTextLabel(screenGui, string.format("HP: %d", math.round(humanoid.Health)), Vector2.new(textX, textYOffset), TEXT_COLOR, ESP.TextSize - 2, OUTLINE_COLOR, OUTLINE_THICKNESS)
                table.insert(ESP_UI, healthLabel)
                textYOffset = textYOffset + ESP.TextSize - 2
            end

            -- Distance ESP
            if ESP.Distance then
                local distance = math.floor((root.Position - localPlayerHeadPos).Magnitude)
                local distanceLabel = CreateTextLabel(screenGui, string.format("%dm", distance), Vector2.new(textX, textYOffset), TEXT_COLOR, ESP.TextSize - 2, OUTLINE_COLOR, OUTLINE_THICKNESS)
                table.insert(ESP_UI, distanceLabel)
            end

            -- Lines to Player
            if ESP.LineMode ~= "None" then
                local startPoint
                if ESP.LineMode == "Center" then
                    startPoint = Vector2.new(ViewportSize.X / 2, ViewportSize.Y / 2)
                elseif ESP.LineMode == "Bottom" then
                    startPoint = Vector2.new(ViewportSize.X / 2, ViewportSize.Y)
                end
                
                local line = CreateLine(screenGui, startPoint, bounds.Center, playerColor, ESP.BoxThickness)
                table.insert(ESP_UI, line)
            end
        end
    end
end

-- Функція увімкнення/вимкнення ESP
function ESP.Enable()
    if ESP.Enabled then return end
    ESP.Enabled = true
    Connections.RenderStepped = RunService.RenderStepped:Connect(RenderESP)
end

function ESP.Disable()
    if not ESP.Enabled then return end
    ESP.Enabled = false
    if Connections.RenderStepped then
        Connections.RenderStepped:Disconnect()
        Connections.RenderStepped = nil
    end
    -- Очищаємо всі UI елементи ESP
    for _, uiElement in pairs(ESP_UI) do
        if uiElement.Parent then
            uiElement:Destroy()
        end
    end
    ESP_UI = {}
    local screenGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ESP_Overlay")
    if screenGui then
        screenGui:Destroy()
    end
end

-- Публічні методи для налаштування
function ESP.ToggleBoxes(value) ESP.Boxes = value end
function ESP.ToggleNames(value) ESP.Names = value end
function ESP.ToggleHealth(value) ESP.Health = value end
function ESP.ToggleDistance(value) ESP.Distance = value end
function ESP.ToggleTeamCheck(value) ESP.TeamCheck = value end
function ESP.SetTeamColor(color) ESP.TeamColor = color end
function ESP.SetEnemyColor(color) ESP.EnemyColor = color end
function ESP.SetLineMode(mode) ESP.LineMode = mode end
function ESP.SetBoxStyle(style) ESP.BoxStyle = style end
function ESP.SetBoxThickness(thickness) ESP.BoxThickness = thickness end
function ESP.SetTextSize(size) ESP.TextSize = size end
function ESP.ToggleVisibleOnly(value) ESP.VisibleOnly = value end

return ESP
