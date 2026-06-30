--[[
    Unnamed Enhancements - Full Suite
    Version 3.0 - Persistent Configs + Key System
    GitHub Ready - Raw Loadstring Compatible
]]

-- ============================================================
-- SERVICES & VARIABLES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- KEY GENERATION & VALIDATION
-- ============================================================
local function generateKey()
    local seed = LocalPlayer.UserId + 987654321
    math.randomseed(seed)
    local key = ""
    for i = 1, 16 do
        key = key .. string.char(math.random(65, 90))
    end
    return key
end

local GENERATED_KEY = generateKey()
local isUnlocked = false

local storedKey = LocalPlayer:GetAttribute("UnlockKey")
if storedKey and storedKey == GENERATED_KEY then
    isUnlocked = true
end

-- ============================================================
-- PERSISTENT CONFIG SYSTEM
-- ============================================================
local CONFIG_FILE = "UnnamedEnhancements_v3.json"

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then copy[k] = deepCopy(v) else copy[k] = v end
    end
    return copy
end

-- Default configuration
local defaultConfigData = {
    aimbot = false,
    silentAim = false,
    aimPart = "Head",
    fov = 80,
    smoothness = 0.25,
    aimRadius = 200,
    flight = false,
    flightSpeed = 2.0,
    noclip = false,
    noclipSpeed = 1.5,
    extraSpeed = false,
    extraSpeedMultiplier = 2.0,
    rapidFire = false,
    rapidMelee = false,
    menuColor = {0.2, 0.2, 0.25},
    bgColor = {0.1, 0.1, 0.12},
    textColor = {0.9, 0.9, 0.95},
    communityConfig = "None",
    customThemeName = "",
}

local configData = deepCopy(defaultConfigData)
local configs = {}
local currentConfigName = "Default"

-- Load from file
local function loadPersistentConfigs()
    local success, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    if success and data and data ~= "" then
        local decoded = HttpService:JSONDecode(data)
        if type(decoded) == "table" and next(decoded) then
            return decoded
        end
    end
    return { Default = { data = deepCopy(defaultConfigData) } }
end

-- Save to file
local function savePersistentConfigs()
    local encoded = HttpService:JSONEncode(configs)
    pcall(function()
        writefile(CONFIG_FILE, encoded)
    end)
end

-- Initialize
configs = loadPersistentConfigs()
if not configs.Default then
    configs.Default = { data = deepCopy(defaultConfigData) }
    savePersistentConfigs()
end

-- Load Default config into current settings
for k, v in pairs(configs.Default.data) do
    configData[k] = v
end

-- ============================================================
-- RAPID FIRE & RAPID MELEE STATE
-- ============================================================
local rapidFireActive = false
local rapidMeleeActive = false
local rapidFireCoroutine = nil
local rapidMeleeCoroutine = nil

local function startRapidFire()
    if rapidFireActive then return end
    rapidFireActive = true
    rapidFireCoroutine = coroutine.create(function()
        while rapidFireActive do
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    if tool:FindFirstChild("Cooldown") then
                        tool.Cooldown.Value = 0
                    end
                    pcall(function() tool:Activate() end)
                end
            end
            task.wait(0.001)
        end
    end)
    coroutine.resume(rapidFireCoroutine)
end

local function stopRapidFire()
    rapidFireActive = false
    if rapidFireCoroutine then
        coroutine.close(rapidFireCoroutine)
        rapidFireCoroutine = nil
    end
end

local function startRapidMelee()
    if rapidMeleeActive then return end
    rapidMeleeActive = true
    rapidMeleeCoroutine = coroutine.create(function()
        while rapidMeleeActive do
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and (tool.Name:match("[Ss]word") or tool.Name:match("[Kk]nife") or tool.Name:match("[Bb]lade") or tool.Name:match("[Mm]elee")) then
                    if tool:FindFirstChild("Cooldown") then
                        tool.Cooldown.Value = 0
                    end
                    pcall(function() tool:Activate() end)
                end
            end
            task.wait(0.001)
        end
    end)
    coroutine.resume(rapidMeleeCoroutine)
end

local function stopRapidMelee()
    rapidMeleeActive = false
    if rapidMeleeCoroutine then
        coroutine.close(rapidMeleeCoroutine)
        rapidMeleeCoroutine = nil
    end
end

-- ============================================================
-- FLIGHT & NOCLIP
-- ============================================================
local flightBodyVelocity = nil

local function toggleFlight(enable)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if enable then
        humanoid.PlatformStand = true
        flightBodyVelocity = Instance.new("BodyVelocity")
        flightBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if root then
            flightBodyVelocity.Parent = root
        end
    else
        humanoid.PlatformStand = false
        if flightBodyVelocity then
            flightBodyVelocity:Destroy()
            flightBodyVelocity = nil
        end
    end
end

local function toggleNoclip(enable)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end

    if enable then
        root.CanCollide = false
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        if not configData.flight then
            toggleFlight(true)
        end
    else
        root.CanCollide = true
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        if not configData.flight then
            toggleFlight(false)
        end
    end
end

-- ============================================================
-- AIMBOT & SILENT AIM
-- ============================================================
local function getClosestTarget(radius, fovDeg)
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso")
    if not localRoot then return nil end
    local localPos = localRoot.Position
    local lookVector = localRoot.CFrame.LookVector

    local closest = nil
    local closestDist = radius

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetChar = player.Character
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
            if targetRoot then
                local targetPos = targetRoot.Position
                local dist = (targetPos - localPos).Magnitude
                if dist < closestDist then
                    local dirToTarget = (targetPos - localPos).unit
                    local angle = math.deg(math.acos(lookVector:Dot(dirToTarget)))
                    if angle <= fovDeg then
                        closestDist = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function getAimPosition(player, partName)
    local char = player.Character
    if not char then return nil end
    local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
    return part and part.Position
end

local function silentAimFix()
    if not isUnlocked then return end
    if not configData.silentAim then return end

    local target = getClosestTarget(configData.aimRadius, configData.fov)
    if not target then return end

    local aimPos = getAimPosition(target, configData.aimPart)
    if not aimPos then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local tool = localChar:FindFirstChildOfClass("Tool")
    if not tool then return end

    local handle = tool:FindFirstChild("Handle")
    if handle then
        local oldCF = handle.CFrame
        local newCF = CFrame.new(handle.Position, aimPos)
        handle.CFrame = newCF
        task.wait(0.01)
        handle.CFrame = oldCF
    end
end

local function aimbotLoop()
    if not isUnlocked then return end
    if not configData.aimbot then return end

    local target = getClosestTarget(configData.aimRadius, configData.fov)
    if not target then return end

    local aimPos = getAimPosition(target, configData.aimPart)
    if not aimPos then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local root = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso")
    if not root then return end

    local currentCF = root.CFrame
    local targetCF = CFrame.new(root.Position, aimPos)
    local smooth = configData.smoothness
    if smooth > 0 then
        root.CFrame = currentCF:Lerp(targetCF, smooth)
    else
        root.CFrame = targetCF
    end
end

-- ============================================================
-- UI CREATION
-- ============================================================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UnnamedEnhancements"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer.PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 450, 0, 520)
    mainFrame.Position = UDim2.new(0.5, -225, 0.5, -260)
    mainFrame.BackgroundColor3 = Color3.fromRGB(
        configData.bgColor[1]*255,
        configData.bgColor[2]*255,
        configData.bgColor[3]*255
    )
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.Text = "Unnamed Enhancements - 4dboard.org/enhancements/1.5"
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- Tabs
    local tabsFrame = Instance.new("Frame")
    tabsFrame.Size = UDim2.new(1, 0, 0, 30)
    tabsFrame.Position = UDim2.new(0, 0, 0, 30)
    tabsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    tabsFrame.BorderSizePixel = 0
    tabsFrame.Parent = mainFrame

    local mainTabBtn = Instance.new("TextButton")
    mainTabBtn.Size = UDim2.new(0, 60, 1, 0)
    mainTabBtn.Position = UDim2.new(0, 10, 0, 0)
    mainTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    mainTabBtn.Text = "main"
    mainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainTabBtn.Font = Enum.Font.GothamBold
    mainTabBtn.TextSize = 14
    mainTabBtn.BorderSizePixel = 0
    mainTabBtn.Parent = tabsFrame

    local settingsTabBtn = Instance.new("TextButton")
    settingsTabBtn.Size = UDim2.new(0, 70, 1, 0)
    settingsTabBtn.Position = UDim2.new(0, 80, 0, 0)
    settingsTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    settingsTabBtn.Text = "settings"
    settingsTabBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
    settingsTabBtn.Font = Enum.Font.GothamBold
    settingsTabBtn.TextSize = 14
    settingsTabBtn.BorderSizePixel = 0
    settingsTabBtn.Parent = tabsFrame

    -- Content Frames
    local mainContent = Instance.new("ScrollingFrame")
    mainContent.Size = UDim2.new(1, 0, 1, -60)
    mainContent.Position = UDim2.new(0, 0, 0, 60)
    mainContent.BackgroundTransparency = 1
    mainContent.BorderSizePixel = 0
    mainContent.CanvasSize = UDim2.new(0, 0, 0, 700)
    mainContent.ScrollBarThickness = 6
    mainContent.Parent = mainFrame

    local settingsContent = Instance.new("ScrollingFrame")
    settingsContent.Size = UDim2.new(1, 0, 1, -60)
    settingsContent.Position = UDim2.new(0, 0, 0, 60)
    settingsContent.BackgroundTransparency = 1
    settingsContent.BorderSizePixel = 0
    settingsContent.CanvasSize = UDim2.new(0, 0, 0, 550)
    settingsContent.ScrollBarThickness = 6
    settingsContent.Visible = false
    settingsContent.Parent = mainFrame

    -- Helper functions for UI elements
    local yPos = 10

    local function addLabel(parent, text, fontSize)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 0, 25)
        lbl.Position = UDim2.new(0, 10, 0, yPos)
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(
            configData.textColor[1]*255,
            configData.textColor[2]*255,
            configData.textColor[3]*255
        )
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = fontSize or 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        yPos = yPos + 30
        return lbl
    end

    local function addButton(parent, text, callback, width)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, width or 120, 0, 25)
        btn.Position = UDim2.new(0, 10, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = parent
        yPos = yPos + 30
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local function addToggle(parent, labelText, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 0, 25)
        container.Position = UDim2.new(0, 10, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(
            configData.textColor[1]*255,
            configData.textColor[2]*255,
            configData.textColor[3]*255
        )
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 50, 0, 20)
        toggleBtn.Position = UDim2.new(0.7, 0, 0.1, 0)
        toggleBtn.BackgroundColor3 = default and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 80, 90)
        toggleBtn.Text = default and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.Font = Enum.Font.Gotham
        toggleBtn.TextSize = 11
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Parent = container

        local state = default
        toggleBtn.MouseButton1Click:Connect(function()
            state = not state
            toggleBtn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 80, 90)
            toggleBtn.Text = state and "ON" or "OFF"
            callback(state)
        end)

        yPos = yPos + 30
        return toggleBtn
    end

    local function addSlider(parent, labelText, min, max, default, suffix, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 0, 35)
        container.Position = UDim2.new(0, 10, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0.4, 0)
        lbl.Text = labelText .. " (" .. tostring(default) .. suffix .. ")"
        lbl.TextColor3 = Color3.fromRGB(
            configData.textColor[1]*255,
            configData.textColor[2]*255,
            configData.textColor[3]*255
        )
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local sliderBar = Instance.new("Frame")
        sliderBar.Size = UDim2.new(0.5, 0, 0.2, 0)
        sliderBar.Position = UDim2.new(0.45, 0, 0.4, 0)
        sliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        sliderBar.BorderSizePixel = 0
        sliderBar.Parent = container

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
        fill.BorderSizePixel = 0
        fill.Parent = sliderBar

        local value = default
        local dragging = false
        sliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
            end
        end)
        sliderBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        sliderBar.MouseMoved:Connect(function(x, y)
            if dragging then
                local percent = math.clamp((x - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
                value = min + (max - min) * percent
                value = math.round(value * 100) / 100
                fill.Size = UDim2.new(percent, 0, 1, 0)
                lbl.Text = labelText .. " (" .. tostring(value) .. suffix .. ")"
                callback(value)
            end
        end)

        yPos = yPos + 40
        return fill
    end

    local function addDropdown(parent, labelText, options, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 0, 30)
        container.Position = UDim2.new(0, 10, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(
            configData.textColor[1]*255,
            configData.textColor[2]*255,
            configData.textColor[3]*255
        )
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local dropdownBtn = Instance.new("TextButton")
        dropdownBtn.Size = UDim2.new(0.4, 0, 1, 0)
        dropdownBtn.Position = UDim2.new(0.55, 0, 0, 0)
        dropdownBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        dropdownBtn.Text = default
        dropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        dropdownBtn.Font = Enum.Font.Gotham
        dropdownBtn.TextSize = 12
        dropdownBtn.BorderSizePixel = 0
        dropdownBtn.Parent = container

        local selected = default
        local dropdownList = Instance.new("Frame")
        dropdownList.Size = UDim2.new(0.4, 0, 0, #options * 25)
        dropdownList.Position = UDim2.new(0.55, 0, 1, 0)
        dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        dropdownList.BorderSizePixel = 0
        dropdownList.Visible = false
        dropdownList.ZIndex = 10
        dropdownList.Parent = container

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 25)
            optBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(220, 220, 250)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.BorderSizePixel = 0
            optBtn.Parent = dropdownList
            optBtn.MouseButton1Click:Connect(function()
                selected = opt
                dropdownBtn.Text = opt
                dropdownList.Visible = false
                callback(opt)
            end)
        end

        dropdownBtn.MouseButton1Click:Connect(function()
            dropdownList.Visible = not dropdownList.Visible
        end)

        yPos = yPos + 35
        return dropdownBtn, dropdownList
    end

    local function addColorPicker(parent, labelText, defaultColor, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 0, 35)
        container.Position = UDim2.new(0, 10, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(
            configData.textColor[1]*255,
            configData.textColor[2]*255,
            configData.textColor[3]*255
        )
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local rBox = Instance.new("TextBox")
        rBox.Size = UDim2.new(0.1, 0, 0.6, 0)
        rBox.Position = UDim2.new(0.5, 0, 0.2, 0)
        rBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        rBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        rBox.Text = tostring(defaultColor[1]*255)
        rBox.Font = Enum.Font.Gotham
        rBox.TextSize = 11
        rBox.Parent = container

        local gBox = Instance.new("TextBox")
        gBox.Size = UDim2.new(0.1, 0, 0.6, 0)
        gBox.Position = UDim2.new(0.65, 0, 0.2, 0)
        gBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        gBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        gBox.Text = tostring(defaultColor[2]*255)
        gBox.Font = Enum.Font.Gotham
        gBox.TextSize = 11
        gBox.Parent = container

        local bBox = Instance.new("TextBox")
        bBox.Size = UDim2.new(0.1, 0, 0.6, 0)
        bBox.Position = UDim2.new(0.8, 0, 0.2, 0)
        bBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        bBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        bBox.Text = tostring(defaultColor[3]*255)
        bBox.Font = Enum.Font.Gotham
        bBox.TextSize = 11
        bBox.Parent = container

        local function updateColor()
            local r = tonumber(rBox.Text) or 0
            local g = tonumber(gBox.Text) or 0
            local b = tonumber(bBox.Text) or 0
            r = math.clamp(r, 0, 255)
            g = math.clamp(g, 0, 255)
            b = math.clamp(b, 0, 255)
            callback({r/255, g/255, b/255})
        end

        rBox.FocusLost:Connect(updateColor)
        gBox.FocusLost:Connect(updateColor)
        bBox.FocusLost:Connect(updateColor)

        yPos = yPos + 40
        return container
    end

    -- ============================================================
    -- MAIN TAB
    -- ============================================================
    addLabel(mainContent, "Configuration", 15)

    local configDropdown, configDropdownList = addDropdown(mainContent, "Config List", {"Default"}, "Default", function(v)
        currentConfigName = v
    end)

    -- Refresh dropdown with actual configs
    local function refreshConfigDropdown()
        local keys = {}
        for k in pairs(configs) do table.insert(keys, k) end
        table.sort(keys)
        -- Clear old options
        for _, child in ipairs(configDropdownList:GetChildren()) do
            child:Destroy()
        end
        for _, opt in ipairs(keys) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 25)
            optBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(220, 220, 250)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.BorderSizePixel = 0
            optBtn.Parent = configDropdownList
            optBtn.MouseButton1Click:Connect(function()
                currentConfigName = opt
                configDropdown.Text = opt
                configDropdownList.Visible = false
                -- Load config immediately
                if configs[opt] then
                    for k, v in pairs(configs[opt].data) do
                        configData[k] = v
                    end
                    autoloadLabel.Text = "Current autoload config: " .. opt
                    print("Loaded config: " .. opt)
                end
            end)
        end
        configDropdownList.Size = UDim2.new(0.4, 0, 0, #keys * 25)
    end
    refreshConfigDropdown()

    local createBtn = addButton(mainContent, "Create config", function()
        local name = "Config" .. tostring(#configs + 1)
        if not configs[name] then
            configs[name] = { data = deepCopy(configData) }
            savePersistentConfigs()
            refreshConfigDropdown()
            configDropdown.Text = name
            currentConfigName = name
            print("Config created and saved: " .. name)
        end
    end, 120)
    createBtn.Position = UDim2.new(0, 10, 0, yPos - 30)

    local loadBtn = addButton(mainContent, "Load config", function()
        if configs[currentConfigName] then
            for k, v in pairs(configs[currentConfigName].data) do
                configData[k] = v
            end
            autoloadLabel.Text = "Current autoload config: " .. currentConfigName
            print("Loaded config: " .. currentConfigName)
        end
    end, 120)
    loadBtn.Position = UDim2.new(0, 140, 0, yPos - 30)

    local overwriteBtn = addButton(mainContent, "Overwrite config", function()
        if configs[currentConfigName] then
            configs[currentConfigName].data = deepCopy(configData)
            savePersistentConfigs()
            print("Overwrote config: " .. currentConfigName)
        end
    end, 130)
    overwriteBtn.Position = UDim2.new(0, 270, 0, yPos - 30)

    local deleteBtn = addButton(mainContent, "Delete config", function()
        if currentConfigName ~= "Default" and configs[currentConfigName] then
            configs[currentConfigName] = nil
            savePersistentConfigs()
            refreshConfigDropdown()
            configDropdown.Text = "Default"
            currentConfigName = "Default"
            print("Deleted config")
        end
    end, 120)
    deleteBtn.Position = UDim2.new(0, 10, 0, yPos + 5)

    yPos = yPos + 40
    local autoloadLabel = Instance.new("TextLabel")
    autoloadLabel.Size = UDim2.new(1, -20, 0, 25)
    autoloadLabel.Position = UDim2.new(0, 10, 0, yPos)
    autoloadLabel.Text = "Current autoload config: " .. currentConfigName
    autoloadLabel.TextColor3 = Color3.fromRGB(
        configData.textColor[1]*255,
        configData.textColor[2]*255,
        configData.textColor[3]*255
    )
    autoloadLabel.BackgroundTransparency = 1
    autoloadLabel.Font = Enum.Font.Gotham
    autoloadLabel.TextSize = 13
    autoloadLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoloadLabel.Parent = mainContent
    yPos = yPos + 35

    -- Toggles and features
    addToggle(mainContent, "Rapid Fire", configData.rapidFire, function(v)
        configData.rapidFire = v
        if v then startRapidFire() else stopRapidFire() end
    end)

    addToggle(mainContent, "Rapid Melee", configData.rapidMelee, function(v)
        configData.rapidMelee = v
        if v then startRapidMelee() else stopRapidMelee() end
    end)

    addToggle(mainContent, "Aimbot", configData.aimbot, function(v)
        configData.aimbot = v
    end)

    addToggle(mainContent, "Silent Aim", configData.silentAim, function(v)
        configData.silentAim = v
    end)

    addDropdown(mainContent, "Aim Part", {"Head", "UpperTorso", "LowerTorso"}, configData.aimPart, function(v)
        configData.aimPart = v
    end)

    addSlider(mainContent, "FOV", 0, 180, configData.fov, "°", function(v)
        configData.fov = v
    end)

    addSlider(mainContent, "Smoothness", 0.0, 1.0, configData.smoothness, "", function(v)
        configData.smoothness = v
    end)

    addSlider(mainContent, "Aim Radius", 50, 500, configData.aimRadius, " studs", function(v)
        configData.aimRadius = v
    end)

    addToggle(mainContent, "Flight", configData.flight, function(v)
        configData.flight = v
        toggleFlight(v)
    end)

    addSlider(mainContent, "Flight Speed", 0.1, 10.0, configData.flightSpeed, "x", function(v)
        configData.flightSpeed = v
    end)

    addToggle(mainContent, "Noclip", configData.noclip, function(v)
        configData.noclip = v
        toggleNoclip(v)
    end)

    addSlider(mainContent, "Noclip Speed", 0.1, 10.0, configData.noclipSpeed, "x", function(v)
        configData.noclipSpeed = v
    end)

    addToggle(mainContent, "Extra Speed", configData.extraSpeed, function(v)
        configData.extraSpeed = v
    end)

    addSlider(mainContent, "Extra Speed Multiplier", 1.0, 5.0, configData.extraSpeedMultiplier, "x", function(v)
        configData.extraSpeedMultiplier = v
    end)

    -- ============================================================
    -- SETTINGS TAB
    -- ============================================================
    yPos = 10

    addColorPicker(settingsContent, "Menu Color", configData.menuColor, function(v)
        configData.menuColor = v
        mainFrame.BackgroundColor3 = Color3.fromRGB(v[1]*255, v[2]*255, v[3]*255)
    end)

    addColorPicker(settingsContent, "Background Color", configData.bgColor, function(v)
        configData.bgColor = v
        mainFrame.BackgroundColor3 = Color3.fromRGB(v[1]*255, v[2]*255, v[3]*255)
    end)

    addColorPicker(settingsContent, "Text Color", configData.textColor, function(v)
        configData.textColor = v
    end)

    addDropdown(settingsContent, "Community config", {"None", "Community1", "Community2"}, configData.communityConfig or "None", function(v)
        configData.communityConfig = v
    end)

    local themeNameBox = Instance.new("TextBox")
    themeNameBox.Size = UDim2.new(0.8, 0, 0, 25)
    themeNameBox.Position = UDim2.new(0.1, 0, 0, yPos)
    themeNameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    themeNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    themeNameBox.PlaceholderText = "Custom theme name"
    themeNameBox.Font = Enum.Font.Gotham
    themeNameBox.TextSize = 12
    themeNameBox.Parent = settingsContent
    yPos = yPos + 35

    addButton(settingsContent, "Custom theme", function()
        configData.customThemeName = themeNameBox.Text
        print("Custom theme set to: " .. themeNameBox.Text)
    end, 150)
    yPos = yPos - 30

    local loadThemeBtn = addButton(settingsContent, "Load theme", function()
        print("Loading theme: " .. (configData.customThemeName or "None"))
    end, 150)
    loadThemeBtn.Position = UDim2.new(0, 160, 0, yPos - 30)

    addButton(settingsContent, "Overwrite Theme", function()
        print("Overwriting theme: " .. (configData.customThemeName or "None"))
    end, 150)
    local overwriteThemeBtn = addButton(settingsContent, "Overwrite Theme", function() end, 150)
    overwriteThemeBtn.Position = UDim2.new(0, 10, 0, yPos + 5)

    addButton(settingsContent, "Set Defa", function()
        print("Set to default theme")
    end, 150)
    local setDefaBtn = addButton(settingsContent, "Set Defa", function() end, 150)
    setDefaBtn.Position = UDim2.new(0, 160, 0, yPos + 5)

    addButton(settingsContent, "Refresh", function()
        print("Refreshing UI")
        refreshConfigDropdown()
    end, 150)
    local refreshBtn = addButton(settingsContent, "Refresh", function() end, 150)
    refreshBtn.Position = UDim2.new(0, 10, 0, yPos + 40)

    yPos = yPos + 80
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(1, -20, 0, 25)
    keyLabel.Position = UDim2.new(0, 10, 0, yPos)
    keyLabel.Text = "Your Key: " .. GENERATED_KEY
    keyLabel.TextColor3 = Color3.fromRGB(200, 255, 150)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.TextSize = 14
    keyLabel.Parent = settingsContent

    yPos = yPos + 35
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.6, 0, 0, 25)
    keyInput.Position = UDim2.new(0.1, 0, 0, yPos)
    keyInput.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.PlaceholderText = "Enter key to unlock"
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 12
    keyInput.Parent = settingsContent

    local validateBtn = Instance.new("TextButton")
    validateBtn.Size = UDim2.new(0.2, 0, 0, 25)
    validateBtn.Position = UDim2.new(0.75, 0, 0, yPos)
    validateBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
    validateBtn.Text = "Unlock"
    validateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    validateBtn.Font = Enum.Font.Gotham
    validateBtn.TextSize = 12
    validateBtn.BorderSizePixel = 0
    validateBtn.Parent = settingsContent

    local unlockStatus = Instance.new("TextLabel")
    unlockStatus.Size = UDim2.new(1, -20, 0, 25)
    unlockStatus.Position = UDim2.new(0, 10, 0, yPos + 35)
    unlockStatus.Text = isUnlocked and "✅ Unlocked" or "🔒 Locked - Enter key above"
    unlockStatus.TextColor3 = isUnlocked and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
    unlockStatus.BackgroundTransparency = 1
    unlockStatus.Font = Enum.Font.Gotham
    unlockStatus.TextSize = 13
    unlockStatus.Parent = settingsContent

    validateBtn.MouseButton1Click:Connect(function()
        local entered = keyInput.Text
        if entered == GENERATED_KEY then
            isUnlocked = true
            LocalPlayer:SetAttribute("UnlockKey", entered)
            unlockStatus.Text = "✅ Unlocked"
            unlockStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
        else
            unlockStatus.Text = "❌ Invalid key"
            unlockStatus.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
    end)

    -- Tab switching
    mainTabBtn.MouseButton1Click:Connect(function()
        mainContent.Visible = true
        settingsContent.Visible = false
        mainTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        settingsTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    end)

    settingsTabBtn.MouseButton1Click:Connect(function()
        mainContent.Visible = false
        settingsContent.Visible = true
        mainTabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        settingsTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    end)

    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, 0, 0, 20)
    footer.Position = UDim2.new(0, 0, 1, -20)
    footer.Text = "Unnamed Enhancements"
    footer.TextColor3 = Color3.fromRGB(120, 120, 150)
    footer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 11
    footer.Parent = mainFrame

    return {
        mainFrame = mainFrame,
        mainContent = mainContent,
        settingsContent = settingsContent,
        configDropdown = configDropdown,
        autoloadLabel = autoloadLabel,
        refreshConfigDropdown = refreshConfigDropdown
    }
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local ui = createUI()

local function mainLoop()
    if not isUnlocked then return end

    -- Flight update
    if configData.flight and flightBodyVelocity then
        local char = LocalPlayer.Character
        if char then
            local cam = Workspace.CurrentCamera
            local moveDirection = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.unit * configData.flightSpeed * 50
            end
            flightBodyVelocity.Velocity = moveDirection
        end
    end

    -- Noclip update
    if configData.noclip then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if root then
                local cam = Workspace.CurrentCamera
                local moveDirection = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
                if moveDirection.Magnitude > 0 then
                    moveDirection = moveDirection.unit * configData.noclipSpeed * 30
                    root.Position = root.Position + moveDirection
                end
            end
        end
    end

    -- Extra Speed
    if configData.extraSpeed then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16 * configData.extraSpeedMultiplier
            end
        end
    end

    -- Aimbot
    aimbotLoop()

    -- Silent Aim hook (we use a separate connection)
end

RunService.RenderStepped:Connect(mainLoop)

-- Silent Aim: hook into tool activation
LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            child.Activated:Connect(function()
                if isUnlocked and configData.silentAim then
                    silentAimFix()
                end
            end)
        end
    end)
end)

-- Cleanup
LocalPlayer.OnTeleport:Connect(function()
    if flightBodyVelocity then flightBodyVelocity:Destroy() end
    stopRapidFire()
    stopRapidMelee()
end)

print("Unnamed Enhancements loaded. Your key: " .. GENERATED_KEY)
print("Configs saved to: " .. CONFIG_FILE)
