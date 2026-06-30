--[[
    HvH ARENA v5.1 - FIXED KEY SYSTEM
    Key: UEONTOP
    Features: Aimbot, ESP, Flight, NoClip, God Mode, Invisibility,
    Speed/Jump/Health, Teleport/Kill/Respawn, Rage Teleport,
    Rapid Fire, Rapid Melee, Clean Developer UI
]]

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- STATE VARIABLES
-- ============================================================
local state = {
    aimbot = false,
    silentAim = false,
    esp = true,
    wallHack = false,
    fly = false,
    flySpeed = 50,
    noclip = false,
    godMode = false,
    invisibility = false,
    aimFOV = 120,
    aimSmoothness = 0.3,
    lockOnRange = 500,
    rageTeleport = false,
    rapidFire = false,
    rapidFireRate = 0.05,
    rapidMelee = false,
    rapidMeleeRate = 0.1,
    meleeKey = "Q",
    espColor = Color3.fromRGB(255, 50, 50),
    espThickness = 2,
}

-- Character refs
local playerChar, humanoid, rootPart
local function getChar()
    playerChar = LocalPlayer.Character
    if playerChar then
        humanoid = playerChar:FindFirstChild("Humanoid")
        rootPart = playerChar:FindFirstChild("HumanoidRootPart")
    end
    return playerChar, humanoid, rootPart
end

-- ESP storage
local espObjects = {}

-- Flight
local bodyVel = nil
local noclipConnection = nil

-- Rage state
local rageTarget = nil
local rageOriginalPos = nil
local rageTimer = nil
local rapidFireConnection = nil
local rapidMeleeConnection = nil

-- UI
local screenGui = nil
local mainFrame = nil
local uiVisible = true
local currentTab = "Main"
local isUnlocked = false

-- UI element references for dropdown updates
local teleportBtn, teleportList, killBtn, killList, rageTargetBtn, rageTargetList

-- ============================================================
-- HELPERS
-- ============================================================
local function clamp(v, low, high) return math.min(high, math.max(low, v)) end

local function isAlive(char)
    local h = char and char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

local function getPlayers()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p.Character) then
            table.insert(list, p)
        end
    end
    return list
end

-- ============================================================
-- CORE FEATURE IMPLEMENTATIONS (defined BEFORE UI)
-- ============================================================

-- ESP System
local function createESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    if espObjects[player] then
        for _, obj in pairs(espObjects[player]) do obj:Remove() end
        espObjects[player] = nil
    end
    
    local drawings = {}
    drawings.box = Drawing.new("Quad")
    drawings.box.Thickness = state.espThickness
    drawings.box.Color = state.espColor
    drawings.box.Transparency = 0.3
    drawings.box.Filled = false
    
    drawings.name = Drawing.new("Text")
    drawings.name.Text = player.Name
    drawings.name.Size = 14
    drawings.name.Color = state.espColor
    drawings.name.Center = true
    drawings.name.Outline = true
    drawings.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    
    drawings.health = Drawing.new("Line")
    drawings.health.Thickness = 3
    drawings.health.Color = Color3.fromRGB(0, 255, 0)
    
    espObjects[player] = drawings
    return drawings
end

local function updateESP()
    if not state.esp then
        for _, drawings in pairs(espObjects) do
            for _, d in pairs(drawings) do d.Visible = false end
        end
        return
    end
    
    for player, drawings in pairs(espObjects) do
        if player.Character and player.Character:FindFirstChild("Head") and isAlive(player.Character) then
            local head = player.Character.Head
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local size = 60
                drawings.box.PointA = Vector2.new(pos.X - size/2, pos.Y - size)
                drawings.box.PointB = Vector2.new(pos.X + size/2, pos.Y - size)
                drawings.box.PointC = Vector2.new(pos.X + size/2, pos.Y + size/2)
                drawings.box.PointD = Vector2.new(pos.X - size/2, pos.Y + size/2)
                drawings.box.Visible = true
                
                drawings.name.Position = Vector2.new(pos.X, pos.Y - size - 20)
                drawings.name.Visible = true
                
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    drawings.health.From = Vector2.new(pos.X - size/2, pos.Y + size/2 + 5)
                    drawings.health.To = Vector2.new(pos.X - size/2 + size * healthPercent, pos.Y + size/2 + 5)
                    drawings.health.Color = healthPercent > 0.5 and Color3.fromRGB(0, 255, 0) or 
                                             healthPercent > 0.25 and Color3.fromRGB(255, 255, 0) or 
                                             Color3.fromRGB(255, 0, 0)
                    drawings.health.Visible = true
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
                drawings.health.Visible = false
            end
        else
            for _, d in pairs(drawings) do d.Visible = false end
        end
    end
end

-- Aimbot
local function findTarget()
    local closest = nil
    local closestAngle = state.aimFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and isAlive(player.Character) then
            local head = player.Character.Head
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                local angle = dist / Camera.ViewportSize.X * 180
                if angle < closestAngle then
                    closestAngle = angle
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Flight
local function updateFlight()
    if state.fly then
        if not bodyVel then
            getChar()
            if rootPart then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                bodyVel.Parent = rootPart
            end
        end
        if bodyVel then
            local direction = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction = direction - Vector3.new(0, 1, 0) end
            
            if direction.Magnitude > 0 then
                bodyVel.Velocity = direction.Unit * state.flySpeed
            else
                bodyVel.Velocity = Vector3.new(0, 0, 0)
            end
        end
    else
        if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    end
end

-- NoClip
local function updateNoClip()
    if state.noclip then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                getChar()
                if playerChar then
                    for _, part in pairs(playerChar:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        getChar()
        if playerChar then
            for _, part in pairs(playerChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- God Mode
local function updateGodMode()
    getChar()
    if humanoid then
        if state.godMode then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        else
            humanoid.MaxHealth = 100
            humanoid.Health = 100
        end
    end
end

-- Invisibility
local function updateInvisibility()
    getChar()
    if playerChar then
        for _, part in pairs(playerChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = state.invisibility and 1 or 0
                part.CastShadow = not state.invisibility
            end
        end
    end
end

-- Rage Teleport (Back-and-Forth)
local function startRageTeleport()
    if rageTimer then rageTimer:Disconnect(); rageTimer = nil end
    if not state.rageTeleport or not rageTarget or not rageTarget.Character then return end
    
    getChar()
    if not rootPart then return end
    
    local targetRoot = rageTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    rageOriginalPos = rootPart.Position
    local toggle = false
    
    rageTimer = RunService.Heartbeat:Connect(function()
        if not state.rageTeleport or not rageTarget or not rageTarget.Character then
            rageTimer:Disconnect()
            rageTimer = nil
            return
        end
        
        getChar()
        if not rootPart then return end
        
        local newTargetRoot = rageTarget.Character:FindFirstChild("HumanoidRootPart")
        if not newTargetRoot then return end
        
        if toggle then
            rootPart.CFrame = CFrame.new(rageOriginalPos)
        else
            rootPart.CFrame = newTargetRoot.CFrame + Vector3.new(0, 3, 0)
        end
        toggle = not toggle
    end)
end

-- ============================================================
-- MAIN UI CREATION - CLEAN DEVELOPER DESIGN
-- ============================================================
local function createMainUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HvH_Arena"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer.PlayerGui

    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 420, 0, 580)
    mainFrame.Position = UDim2.new(0.5, -210, 0.5, -290)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.Position = UDim2.new(0, 0, 1, -2)
    accentLine.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    accentLine.BorderSizePixel = 0
    accentLine.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "◆ HvH Arena v4.0"
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 34)
    tabBar.Position = UDim2.new(0, 0, 0, 40)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    -- Tab buttons
    local tabs = {"Main", "Combat", "Movement", "Visuals", "Rage"}
    local tabButtons = {}
    local tabContents = {}

    for i, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 84, 1, -2)
        btn.Position = UDim2.new(0, (i-1) * 84, 0, 1)
        btn.Text = tabName:upper()
        btn.TextColor3 = Color3.fromRGB(180, 180, 210)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = tabBar
        tabButtons[tabName] = btn

        local content = Instance.new("ScrollingFrame")
        content.Size = UDim2.new(1, -10, 1, -80)
        content.Position = UDim2.new(0, 5, 0, 78)
        content.BackgroundTransparency = 1
        content.BorderSizePixel = 0
        content.ScrollBarThickness = 5
        content.CanvasSize = UDim2.new(0, 0, 0, 800)
        content.Visible = (i == 1)
        content.Parent = mainFrame
        tabContents[tabName] = content
    end

    -- Tab switching
    local function switchTab(tabName)
        currentTab = tabName
        for name, content in pairs(tabContents) do
            content.Visible = (name == tabName)
            tabButtons[name].BackgroundColor3 = (name == tabName) and Color3.fromRGB(40, 40, 55) or Color3.fromRGB(25, 25, 35)
            tabButtons[name].TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 210)
        end
    end

    for name, btn in pairs(tabButtons) do
        btn.MouseButton1Click:Connect(function()
            switchTab(name)
        end)
    end

    -- ============================================================
    -- UI BUILDERS
    -- ============================================================
    local function addHeader(parent, text)
        local h = Instance.new("TextLabel")
        h.Size = UDim2.new(1, -10, 0, 24)
        h.Position = UDim2.new(0, 5, 0, parent.yPos or 5)
        h.Text = text
        h.TextColor3 = Color3.fromRGB(200, 200, 230)
        h.BackgroundTransparency = 1
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.Font = Enum.Font.GothamBold
        h.TextSize = 14
        h.Parent = parent
        parent.yPos = (parent.yPos or 5) + 28
        return h
    end

    local function addToggle(parent, labelText, defaultState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 30)
        container.Position = UDim2.new(0, 5, 0, parent.yPos or 5)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, 0, 0.7, 0)
        btn.Position = UDim2.new(0.65, 0, 0.15, 0)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(140, 40, 40)
        btn.Text = defaultState and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = container

        local state = defaultState
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = state and "ON" or "OFF"
            btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(140, 40, 40)
            callback(state)
        end)

        parent.yPos = (parent.yPos or 5) + 34
        return btn, function() return state end
    end

    local function addSlider(parent, labelText, minVal, maxVal, defaultVal, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 40)
        container.Position = UDim2.new(0, 5, 0, parent.yPos or 5)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0.5, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.15, 0, 0.5, 0)
        valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
        valueLabel.Text = tostring(defaultVal)
        valueLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 13
        valueLabel.Parent = container

        local track = Instance.new("Frame")
        track.Size = UDim2.new(0.7, 0, 0.25, 0)
        track.Position = UDim2.new(0, 0, 0.6, 0)
        track.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        track.BorderSizePixel = 0
        track.Parent = container

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track

        local dragging = false
        local function updateSlider(mouseX)
            local absX = mouseX - track.AbsolutePosition.X
            local relX = clamp(absX / track.AbsoluteSize.X, 0, 1)
            local value = minVal + relX * (maxVal - minVal)
            fill.Size = UDim2.new(relX, 0, 1, 0)
            valueLabel.Text = string.format("%.1f", value)
            callback(value)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateSlider(input.Position.X)
            end
        end)
        track.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSlider(input.Position.X)
            end
        end)

        parent.yPos = (parent.yPos or 5) + 44
        return container
    end

    local function addDropdown(parent, labelText, options, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 32)
        container.Position = UDim2.new(0, 5, 0, parent.yPos or 5)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.4, 0, 0.8, 0)
        btn.Position = UDim2.new(0.55, 0, 0.1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btn.Text = default
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = container

        local selected = default
        local list = Instance.new("Frame")
        list.Size = UDim2.new(0.4, 0, 0, #options * 26)
        list.Position = UDim2.new(0.55, 0, 1, 0)
        list.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 10
        list.Parent = container

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 26)
            optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(220, 220, 250)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.BorderSizePixel = 0
            optBtn.Parent = list
            optBtn.MouseButton1Click:Connect(function()
                selected = opt
                btn.Text = opt
                list.Visible = false
                callback(opt)
            end)
        end

        btn.MouseButton1Click:Connect(function()
            list.Visible = not list.Visible
        end)

        parent.yPos = (parent.yPos or 5) + 36
        return btn, list
    end

    local function addTextBox(parent, labelText, placeholder, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 35)
        container.Position = UDim2.new(0, 5, 0, parent.yPos or 5)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.3, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.Parent = container

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.5, 0, 0.8, 0)
        box.Position = UDim2.new(0.35, 0, 0.1, 0)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.PlaceholderText = placeholder
        box.Font = Enum.Font.Gotham
        box.TextSize = 13
        box.BorderSizePixel = 0
        box.Parent = container

        box.FocusLost:Connect(function(enter)
            if enter then
                callback(box.Text)
            end
        end)

        parent.yPos = (parent.yPos or 5) + 39
        return box
    end

    -- ============================================================
    -- POPULATE TABS
    -- ============================================================
    
    -- === MAIN TAB ===
    local mainContent = tabContents["Main"]
    mainContent.yPos = 5
    
    addHeader(mainContent, "⚙ CONFIGURATION")
    addToggle(mainContent, "ESP", state.esp, function(v) state.esp = v end)
    addToggle(mainContent, "Aimbot", state.aimbot, function(v) state.aimbot = v end)
    addToggle(mainContent, "Silent Aim", state.silentAim, function(v) state.silentAim = v end)
    addToggle(mainContent, "Wall Hack", state.wallHack, function(v) state.wallHack = v end)
    
    addHeader(mainContent, "🎯 AIMBOT SETTINGS")
    addSlider(mainContent, "FOV", 10, 180, state.aimFOV, function(v) state.aimFOV = v end)
    addSlider(mainContent, "Smoothness", 0, 1, state.aimSmoothness, function(v) state.aimSmoothness = v end)
    addSlider(mainContent, "Range", 100, 1000, state.lockOnRange, function(v) state.lockOnRange = v end)

    -- === COMBAT TAB ===
    local combatContent = tabContents["Combat"]
    combatContent.yPos = 5
    
    addHeader(combatContent, "⚔ COMBAT")
    addToggle(combatContent, "God Mode", state.godMode, function(v) state.godMode = v end)
    addToggle(combatContent, "Invisibility", state.invisibility, function(v) state.invisibility = v end)
    
    addHeader(combatContent, "📊 STATS")
    addTextBox(combatContent, "WalkSpeed", "Enter speed", function(v)
        local val = tonumber(v)
        if val then getChar(); if humanoid then humanoid.WalkSpeed = val end end
    end)
    addTextBox(combatContent, "JumpPower", "Enter jump power", function(v)
        local val = tonumber(v)
        if val then getChar(); if humanoid then humanoid.JumpPower = val end end
    end)
    addTextBox(combatContent, "Health", "Enter max health", function(v)
        local val = tonumber(v)
        if val then getChar(); if humanoid then humanoid.MaxHealth = val; humanoid.Health = val end end
    end)
    
    addHeader(combatContent, "👥 PLAYER ACTIONS")
    
    teleportBtn, teleportList = addDropdown(combatContent, "Teleport to", {"Select Player"}, "Select Player", function(v)
        local target = Players:FindFirstChild(v)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            getChar()
            if rootPart then
                rootPart.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end)
    
    killBtn, killList = addDropdown(combatContent, "Kill Player", {"Select Player"}, "Select Player", function(v)
        local target = Players:FindFirstChild(v)
        if target and target.Character and target.Character:FindFirstChild("Humanoid") then
            target.Character.Humanoid.Health = 0
        end
    end)
    
    addToggle(combatContent, "Respawn", false, function(v)
        if v then
            LocalPlayer:LoadCharacter()
        end
    end)

    -- === MOVEMENT TAB ===
    local movementContent = tabContents["Movement"]
    movementContent.yPos = 5
    
    addHeader(movementContent, "🚀 FLIGHT")
    addToggle(movementContent, "Fly", state.fly, function(v) state.fly = v end)
    addSlider(movementContent, "Fly Speed", 10, 200, state.flySpeed, function(v) state.flySpeed = v end)
    
    addHeader(movementContent, "🔄 MOVEMENT")
    addToggle(movementContent, "NoClip", state.noclip, function(v) state.noclip = v end)

    -- === VISUALS TAB ===
    local visualsContent = tabContents["Visuals"]
    visualsContent.yPos = 5
    
    addHeader(visualsContent, "🎨 ESP SETTINGS")
    addToggle(visualsContent, "ESP Enabled", state.esp, function(v) state.esp = v end)
    addSlider(visualsContent, "ESP Thickness", 1, 5, state.espThickness, function(v) state.espThickness = v end)
    
    addHeader(visualsContent, "🎯 ESP COLOR")
    local colorPresets = {"Red", "Green", "Blue", "Yellow", "Purple", "Orange", "Cyan", "White"}
    local colorValues = {
        Red = Color3.fromRGB(255, 0, 0),
        Green = Color3.fromRGB(0, 255, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Yellow = Color3.fromRGB(255, 255, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        Orange = Color3.fromRGB(255, 150, 0),
        Cyan = Color3.fromRGB(0, 255, 255),
        White = Color3.fromRGB(255, 255, 255)
    }
    
    local colorContainer = Instance.new("Frame")
    colorContainer.Size = UDim2.new(1, -10, 0, 40)
    colorContainer.Position = UDim2.new(0, 5, 0, visualsContent.yPos or 5)
    colorContainer.BackgroundTransparency = 1
    colorContainer.Parent = visualsContent
    
    for i, colorName in ipairs(colorPresets) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.1, 0, 0.8, 0)
        btn.Position = UDim2.new(0.05 + (i-1) * 0.12, 0, 0.1, 0)
        btn.BackgroundColor3 = colorValues[colorName]
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.Parent = colorContainer
        btn.MouseButton1Click:Connect(function()
            state.espColor = colorValues[colorName]
        end)
    end
    visualsContent.yPos = (visualsContent.yPos or 5) + 44

    -- === RAGE TAB ===
    local rageContent = tabContents["Rage"]
    rageContent.yPos = 5
    
    addHeader(rageContent, "🔥 RAGE FEATURES")
    
    addToggle(rageContent, "Rage Teleport (Back-and-Forth)", state.rageTeleport, function(v) 
        state.rageTeleport = v
        if not v then
            if rageTimer then rageTimer:Disconnect(); rageTimer = nil end
            rageTarget = nil
            rageOriginalPos = nil
        elseif rageTarget then
            startRageTeleport()
        end
    end)
    
    rageTargetBtn, rageTargetList = addDropdown(rageContent, "Rage Target", {"Select Player"}, "Select Player", function(v)
        if v ~= "Select Player" then
            rageTarget = Players:FindFirstChild(v)
            if state.rageTeleport and rageTarget then
                startRageTeleport()
            end
        else
            rageTarget = nil
        end
    end)
    
    addHeader(rageContent, "⚡ RAPID FIRE")
    addToggle(rageContent, "Rapid Fire", state.rapidFire, function(v) 
        state.rapidFire = v
        if v then
            if rapidFireConnection then rapidFireConnection:Disconnect() end
            rapidFireConnection = RunService.Heartbeat:Connect(function()
                if state.rapidFire and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, true, false, 0)
                    task.wait(state.rapidFireRate)
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, false, false, 0)
                end
            end)
        else
            if rapidFireConnection then rapidFireConnection:Disconnect(); rapidFireConnection = nil end
        end
    end)
    addSlider(rageContent, "Rapid Fire Rate (s)", 0.01, 0.5, state.rapidFireRate, function(v) state.rapidFireRate = v end)
    
    addHeader(rageContent, "🗡 RAPID MELEE")
    addToggle(rageContent, "Rapid Melee", state.rapidMelee, function(v)
        state.rapidMelee = v
        if v then
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect() end
            rapidMeleeConnection = RunService.Heartbeat:Connect(function()
                if state.rapidMelee and UserInputService:IsKeyDown(Enum.KeyCode[state.meleeKey] or Enum.KeyCode.Q) then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[state.meleeKey] or Enum.KeyCode.Q, false, false, 0)
                    task.wait(state.rapidMeleeRate)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[state.meleeKey] or Enum.KeyCode.Q, false, false, 0)
                end
            end)
        else
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect(); rapidMeleeConnection = nil end
        end
    end)
    addSlider(rageContent, "Rapid Melee Rate (s)", 0.02, 0.5, state.rapidMeleeRate, function(v) state.rapidMeleeRate = v end)
    addTextBox(rageContent, "Melee Key", "Q", function(v)
        if v and #v == 1 then
            state.meleeKey = v:upper()
        end
    end)

    -- Update Canvas sizes
    for name, content in pairs(tabContents) do
        content.CanvasSize = UDim2.new(0, 0, 0, (content.yPos or 5) + 50)
    end

    -- ============================================================
    -- UPDATE PLAYER LISTS FUNCTION
    -- ============================================================
    local function updatePlayerLists()
        local players = getPlayers()
        local names = {"Select Player"}
        for _, p in pairs(players) do
            table.insert(names, p.Name)
        end
        
        -- Update teleport dropdown
        if teleportList then
            for _, child in pairs(teleportList:GetChildren()) do child:Destroy() end
            teleportList.Size = UDim2.new(0.4, 0, 0, #names * 26)
            for _, name in pairs(names) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                btn.Text = name
                btn.TextColor3 = Color3.fromRGB(220, 220, 250)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.BorderSizePixel = 0
                btn.Parent = teleportList
                btn.MouseButton1Click:Connect(function()
                    teleportBtn.Text = name
                    teleportList.Visible = false
                    if name ~= "Select Player" then
                        local target = Players:FindFirstChild(name)
                        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            getChar()
                            if rootPart then
                                rootPart.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                            end
                        end
                    end
                end)
            end
        end
        
        -- Update kill dropdown
        if killList then
            for _, child in pairs(killList:GetChildren()) do child:Destroy() end
            killList.Size = UDim2.new(0.4, 0, 0, #names * 26)
            for _, name in pairs(names) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                btn.Text = name
                btn.TextColor3 = Color3.fromRGB(220, 220, 250)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.BorderSizePixel = 0
                btn.Parent = killList
                btn.MouseButton1Click:Connect(function()
                    killBtn.Text = name
                    killList.Visible = false
                    if name ~= "Select Player" then
                        local target = Players:FindFirstChild(name)
                        if target and target.Character and target.Character:FindFirstChild("Humanoid") then
                            target.Character.Humanoid.Health = 0
                        end
                    end
                end)
            end
        end
        
        -- Update rage target dropdown
        if rageTargetList then
            for _, child in pairs(rageTargetList:GetChildren()) do child:Destroy() end
            rageTargetList.Size = UDim2.new(0.4, 0, 0, #names * 26)
            for _, name in pairs(names) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                btn.Text = name
                btn.TextColor3 = Color3.fromRGB(220, 220, 250)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 12
                btn.BorderSizePixel = 0
                btn.Parent = rageTargetList
                btn.MouseButton1Click:Connect(function()
                    rageTargetBtn.Text = name
                    rageTargetList.Visible = false
                    if name ~= "Select Player" then
                        rageTarget = Players:FindFirstChild(name)
                        if state.rageTeleport and rageTarget then
                            startRageTeleport()
                        end
                    else
                        rageTarget = nil
                    end
                end)
            end
        end
    end

    -- ============================================================
    -- MAIN LOOPS
    -- ============================================================
    
    -- ESP update loop
    RunService.RenderStepped:Connect(updateESP)
    
    -- Flight update loop
    RunService.Heartbeat:Connect(updateFlight)
    
    -- NoClip update
    RunService.Stepped:Connect(function()
        updateNoClip()
        updateGodMode()
        updateInvisibility()
    end)
    
    -- Player list updates
    Players.PlayerAdded:Connect(function() 
        task.wait(1) 
        updatePlayerLists() 
    end)
    Players.PlayerRemoved:Connect(function() 
        task.wait(1) 
        updatePlayerLists() 
    end)
    
    -- Initial player list population
    task.wait(0.5)
    updatePlayerLists()
    
    -- Aimbot mouse events
    Mouse.Button1Down:Connect(function()
        if state.aimbot then
            local target = findTarget()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                local head = target.Character.Head
                local targetPos = head.Position
                if state.silentAim then
                    local newCF = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, 1 - state.aimSmoothness)
                else
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                end
            end
        end
    end)

    -- ============================================================
    -- RIGHT SHIFT TOGGLE
    -- ============================================================
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            uiVisible = not uiVisible
            if screenGui then
                screenGui.Enabled = uiVisible
            end
        end
    end)

    -- ============================================================
    -- CLEANUP
    -- ============================================================
    LocalPlayer.OnTeleport:Connect(function()
        if screenGui then screenGui:Destroy() end
        if bodyVel then bodyVel:Destroy() end
        if noclipConnection then noclipConnection:Disconnect() end
        if rageTimer then rageTimer:Disconnect() end
        if rapidFireConnection then rapidFireConnection:Disconnect() end
        if rapidMeleeConnection then rapidMeleeConnection:Disconnect() end
    end)

    print("✅ HvH Arena v4.0 unlocked and loaded!")
    print("🔑 Press RightShift to toggle UI")
end

-- ============================================================
-- KEY SYSTEM UI
-- ============================================================
local function createKeySystem()
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "KeySystem"
    keyGui.ResetOnSpawn = false
    keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    keyGui.Parent = LocalPlayer.PlayerGui

    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.6
    overlay.BorderSizePixel = 0
    overlay.Parent = keyGui

    -- Key entry frame
    local unlockFrame = Instance.new("Frame")
    unlockFrame.Size = UDim2.new(0, 380, 0, 220)
    unlockFrame.Position = UDim2.new(0.5, -190, 0.5, -110)
    unlockFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    unlockFrame.BorderSizePixel = 0
    unlockFrame.ClipsDescendants = true
    unlockFrame.Parent = keyGui

    -- Accent line
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 3)
    accent.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    accent.BorderSizePixel = 0
    accent.Parent = unlockFrame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 20, 0, 15)
    title.Text = "🔐 Enter License Key"
    title.TextColor3 = Color3.fromRGB(230, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = unlockFrame

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 20)
    subtitle.Position = UDim2.new(0, 20, 0, 55)
    subtitle.Text = "Enter the activation key to access HvH Arena"
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 180)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 13
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = unlockFrame

    -- Key input box
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.8, 0, 0, 40)
    keyInput.Position = UDim2.new(0.1, 0, 0, 85)
    keyInput.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.PlaceholderText = "Enter key..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 150)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 16
    keyInput.BorderSizePixel = 0
    keyInput.Parent = unlockFrame

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 20)
    statusLabel.Position = UDim2.new(0, 20, 0, 130)
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = unlockFrame

    -- Unlock button
    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0.4, 0, 0, 38)
    unlockBtn.Position = UDim2.new(0.3, 0, 0, 158)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    unlockBtn.Text = "UNLOCK"
    unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 16
    unlockBtn.BorderSizePixel = 0
    unlockBtn.Parent = unlockFrame

    -- Hover effect
    unlockBtn.MouseEnter:Connect(function()
        TweenService:Create(unlockBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 200, 255)}):Play()
    end)
    unlockBtn.MouseLeave:Connect(function()
        TweenService:Create(unlockBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}):Play()
    end)

    -- Enter key support
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            unlockBtn.MouseButton1Click:Fire()
        end
    end)

    -- Unlock logic
    unlockBtn.MouseButton1Click:Connect(function()
        local entered = keyInput.Text:upper()
        if entered == "UEONTOP" then
            isUnlocked = true
            statusLabel.Text = "✅ Key accepted! Loading..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            keyInput.Text = ""
            keyInput.Visible = false
            unlockBtn.Visible = false
            title.Text = "✅ Unlocked!"
            subtitle.Text = "You now have access to HvH Arena v4.0"
            
            -- Create main UI and destroy key GUI
            task.wait(0.5)
            createMainUI()
            keyGui:Destroy()
        else
            statusLabel.Text = "❌ Invalid key. Please try again."
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            keyInput.Text = ""
        end
    end)

    return keyGui
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
-- Start with key system
createKeySystem()

print("🔐 HvH Arena v4.0 - Key system active")
print("📝 Enter key: UEONTOP")
