--[[
    HvH ARENA v7.0 - COMPLETE REBUILD FROM UNIVERSAL SCRIPT
    Key: UEONTOP
    Features: Aimbot (with Silent Aim), ESP, Fly (adjustable speed), NoClip, 
    God Mode, Invisibility, WalkSpeed/JumpPower/Health, Teleport/Kill/Respawn,
    Rage Teleport (Back-and-Forth), Rapid Fire, Rapid Melee
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
-- VARIABLES (from universal script)
-- ============================================================
local player = LocalPlayer
local lockOnRange = 500
local isLockedOn = false
local espEnabled = true
local espColor = Color3.new(1, 0, 0)
local espThickness = 1
local espTransparency = 0.5
local espFontSize = 14
local espFont = Drawing.Fonts.UI
local shootThroughWallsEnabled = false
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = {}

local isInvisible = false
local isFlying = false
local flySpeed = 50
local bodyVelocity = nil
local isNoClip = false
local noClipConnection = nil
local isGodMode = false
local espDrawings = {}
local silentAimEnabled = false
local aimSmoothness = 0.3
local aimFOV = 120

-- Rage variables
local rageTeleportEnabled = false
local rageTarget = nil
local rageOriginalPos = nil
local rageTimer = nil
local rapidFireEnabled = false
local rapidFireRate = 0.05
local rapidFireConnection = nil
local rapidMeleeEnabled = false
local rapidMeleeRate = 0.1
local rapidMeleeConnection = nil
local meleeKey = Enum.KeyCode.Q

-- UI
local screenGui = nil
local mainFrame = nil
local uiVisible = true
local currentTab = "Main"

-- ============================================================
-- HELPERS
-- ============================================================
local function getChar()
    local char = player.Character
    if char then
        return char, char:FindFirstChild("Humanoid"), char:FindFirstChild("HumanoidRootPart")
    end
    return nil, nil, nil
end

local function isPlayerAlive(character)
    local humanoid = character and character:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getPlayers()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and isPlayerAlive(p.Character) then
            table.insert(list, p)
        end
    end
    return list
end

local function clamp(v, low, high) return math.min(high, math.max(low, v)) end

-- ============================================================
-- ESP SYSTEM (from universal script)
-- ============================================================
local function createESP(otherPlayer)
    if not otherPlayer.Character then return end
    
    if espDrawings[otherPlayer] then
        for _, drawing in pairs(espDrawings[otherPlayer]) do
            drawing:Remove()
        end
        espDrawings[otherPlayer] = nil
    end
    
    local drawings = {}
    drawings.box = Drawing.new("Quad")
    drawings.box.Thickness = espThickness
    drawings.box.Color = espColor
    drawings.box.Transparency = espTransparency
    drawings.box.Filled = false
    
    drawings.name = Drawing.new("Text")
    drawings.name.Text = otherPlayer.Name
    drawings.name.Size = espFontSize
    drawings.name.Color = espColor
    drawings.name.Transparency = espTransparency
    drawings.name.Font = espFont
    drawings.name.Center = true
    drawings.name.Outline = true
    drawings.name.OutlineColor = Color3.new(0, 0, 0)
    
    drawings.health = Drawing.new("Line")
    drawings.health.Thickness = 3
    drawings.health.Color = Color3.new(0, 1, 0)
    drawings.health.Transparency = 0.5
    
    espDrawings[otherPlayer] = drawings
end

local function updateESP()
    if not espEnabled then
        for _, drawings in pairs(espDrawings) do
            for _, d in pairs(drawings) do d.Visible = false end
        end
        return
    end
    
    for otherPlayer, drawings in pairs(espDrawings) do
        if otherPlayer.Character and otherPlayer.Character:FindFirstChild("Head") then
            local head = otherPlayer.Character.Head
            local headPosition, headVisible = Camera:WorldToViewportPoint(head.Position)
            
            if headVisible and isPlayerAlive(otherPlayer.Character) then
                local size = Vector2.new(50, 80)
                drawings.box.PointA = Vector2.new(headPosition.X - size.X / 2, headPosition.Y - size.Y / 2)
                drawings.box.PointB = Vector2.new(headPosition.X + size.X / 2, headPosition.Y - size.Y / 2)
                drawings.box.PointC = Vector2.new(headPosition.X + size.X / 2, headPosition.Y + size.Y / 2)
                drawings.box.PointD = Vector2.new(headPosition.X - size.X / 2, headPosition.Y + size.Y / 2)
                drawings.box.Visible = true
                
                drawings.name.Position = Vector2.new(headPosition.X, headPosition.Y - size.Y / 2 - 20)
                drawings.name.Visible = true
                
                local humanoid = otherPlayer.Character:FindFirstChild("Humanoid")
                if humanoid then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    drawings.health.From = Vector2.new(headPosition.X - size.X / 2, headPosition.Y + size.Y / 2 + 5)
                    drawings.health.To = Vector2.new(headPosition.X - size.X / 2 + size.X * healthPercent, headPosition.Y + size.Y / 2 + 5)
                    drawings.health.Color = healthPercent > 0.5 and Color3.new(0, 1, 0) or 
                                             healthPercent > 0.25 and Color3.new(1, 1, 0) or 
                                             Color3.new(1, 0, 0)
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

-- ============================================================
-- AIMBOT SYSTEM (from universal script)
-- ============================================================
local function findNearestPlayerHead()
    local nearestPlayer = nil
    local nearestAngle = aimFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local head = otherPlayer.Character:FindFirstChild("Head")
            if head and isPlayerAlive(otherPlayer.Character) then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    local angle = dist / Camera.ViewportSize.X * 180
                    if angle < nearestAngle then
                        nearestPlayer = head
                        nearestAngle = angle
                    end
                end
            end
        end
    end
    
    return nearestPlayer
end

local function lockOntoNearestPlayer()
    if not isLockedOn then return end
    local nearestHead = findNearestPlayerHead()
    if nearestHead then
        if silentAimEnabled then
            local newCF = CFrame.lookAt(Camera.CFrame.Position, nearestHead.Position)
            Camera.CFrame = Camera.CFrame:Lerp(newCF, 1 - aimSmoothness)
        else
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, nearestHead.Position)
        end
    end
end

-- ============================================================
-- FLIGHT SYSTEM (from universal script)
-- ============================================================
local function handleFlying()
    if isFlying then
        local char, humanoid, rootPart = getChar()
        if rootPart then
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                bodyVelocity.Parent = rootPart
            end
            
            local direction = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction = direction + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction = direction - Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction = direction - Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction = direction + Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                direction = direction + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                direction = direction - Vector3.new(0, 1, 0)
            end
            
            if direction.Magnitude > 0 then
                bodyVelocity.Velocity = direction.Unit * flySpeed
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    else
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
end

-- ============================================================
-- RAGE TELEPORT
-- ============================================================
local function startRageTeleport()
    if rageTimer then rageTimer:Disconnect(); rageTimer = nil end
    if not rageTeleportEnabled or not rageTarget or not rageTarget.Character then return end
    
    local char, humanoid, rootPart = getChar()
    if not rootPart then return end
    
    local targetRoot = rageTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    rageOriginalPos = rootPart.Position
    local toggle = false
    
    rageTimer = RunService.Heartbeat:Connect(function()
        if not rageTeleportEnabled or not rageTarget or not rageTarget.Character then
            rageTimer:Disconnect()
            rageTimer = nil
            return
        end
        
        local char2, humanoid2, rootPart2 = getChar()
        if not rootPart2 then return end
        
        local newTargetRoot = rageTarget.Character:FindFirstChild("HumanoidRootPart")
        if not newTargetRoot then return end
        
        if toggle then
            rootPart2.CFrame = CFrame.new(rageOriginalPos)
        else
            rootPart2.CFrame = newTargetRoot.CFrame + Vector3.new(0, 3, 0)
        end
        toggle = not toggle
    end)
end

-- ============================================================
-- UI CREATION - CLEAN DEVELOPER UI
-- ============================================================
local function createMainUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HvH_Arena"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 550)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -275)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "◆ HvH Arena v7.0"
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 32)
    tabBar.Position = UDim2.new(0, 0, 0, 36)
    tabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local tabs = {"Main", "Combat", "Movement", "Visuals", "Rage"}
    local tabButtons = {}
    local tabScrolls = {}
    local tabContainers = {}

    for i, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.Position = UDim2.new(0, (i-1) * 80, 0, 0)
        btn.Text = tabName:upper()
        btn.TextColor3 = Color3.fromRGB(180, 180, 210)
        btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = tabBar
        tabButtons[tabName] = btn

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -10, 1, -78)
        scroll.Position = UDim2.new(0, 5, 0, 72)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5
        scroll.Visible = (i == 1)
        scroll.Parent = mainFrame
        
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 10)
        container.BackgroundTransparency = 1
        container.Parent = scroll
        
        scroll.CanvasSize = UDim2.new(0, 0, 0, 10)
        
        tabScrolls[tabName] = scroll
        tabContainers[tabName] = {
            container = container,
            yPos = 5,
            scroll = scroll
        }
    end

    local function switchTab(tabName)
        currentTab = tabName
        for name, scroll in pairs(tabScrolls) do
            scroll.Visible = (name == tabName)
            tabButtons[name].BackgroundColor3 = (name == tabName) and Color3.fromRGB(40, 40, 55) or Color3.fromRGB(24, 24, 34)
            tabButtons[name].TextColor3 = (name == tabName) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 210)
        end
    end

    for name, btn in pairs(tabButtons) do
        btn.MouseButton1Click:Connect(function() switchTab(name) end)
    end

    -- UI Builders
    local function addHeader(tabData, text)
        local h = Instance.new("TextLabel")
        h.Size = UDim2.new(1, -10, 0, 22)
        h.Position = UDim2.new(0, 5, 0, tabData.yPos)
        h.Text = text
        h.TextColor3 = Color3.fromRGB(200, 200, 230)
        h.BackgroundTransparency = 1
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.Font = Enum.Font.GothamBold
        h.TextSize = 13
        h.Parent = tabData.container
        tabData.yPos = tabData.yPos + 26
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return h
    end

    local function addToggle(tabData, labelText, defaultState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 28)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.25, 0, 0.7, 0)
        btn.Position = UDim2.new(0.7, 0, 0.15, 0)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(140, 40, 40)
        btn.Text = defaultState and "ON" or "OFF"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = container

        local state = defaultState
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = state and "ON" or "OFF"
            btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(140, 40, 40)
            callback(state)
        end)

        tabData.yPos = tabData.yPos + 32
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return btn
    end

    local function addSlider(tabData, labelText, minVal, maxVal, defaultVal, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 38)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0.5, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.15, 0, 0.5, 0)
        valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
        valueLabel.Text = tostring(defaultVal)
        valueLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.Parent = container

        local track = Instance.new("Frame")
        track.Size = UDim2.new(0.7, 0, 0.22, 0)
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

        tabData.yPos = tabData.yPos + 42
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return container
    end

    local function addDropdown(tabData, labelText, options, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 30)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.4, 0, 0.8, 0)
        btn.Position = UDim2.new(0.55, 0, 0.1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btn.Text = default
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = container

        local selected = default
        local list = Instance.new("Frame")
        list.Size = UDim2.new(0.4, 0, 0, #options * 24)
        list.Position = UDim2.new(0.55, 0, 1, 0)
        list.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 10
        list.Parent = container

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 24)
            optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(220, 220, 250)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 11
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

        tabData.yPos = tabData.yPos + 34
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return btn, list
    end

    local function addTextBox(tabData, labelText, placeholder, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 32)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.3, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(230, 230, 245)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = container

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.5, 0, 0.8, 0)
        box.Position = UDim2.new(0.35, 0, 0.1, 0)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.PlaceholderText = placeholder
        box.Font = Enum.Font.Gotham
        box.TextSize = 12
        box.BorderSizePixel = 0
        box.Parent = container

        box.FocusLost:Connect(function(enter)
            if enter then callback(box.Text) end
        end)

        tabData.yPos = tabData.yPos + 36
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return box
    end

    -- ============================================================
    -- POPULATE TABS
    -- ============================================================
    
    -- MAIN TAB
    local mainData = tabContainers["Main"]
    addHeader(mainData, "⚙ CONFIGURATION")
    addToggle(mainData, "ESP", espEnabled, function(v) espEnabled = v end)
    addToggle(mainData, "Aimbot", isLockedOn, function(v) isLockedOn = v end)
    addToggle(mainData, "Silent Aim", silentAimEnabled, function(v) silentAimEnabled = v end)
    addToggle(mainData, "Wall Hack", shootThroughWallsEnabled, function(v) shootThroughWallsEnabled = v end)
    addHeader(mainData, "🎯 AIMBOT SETTINGS")
    addSlider(mainData, "FOV", 10, 180, aimFOV, function(v) aimFOV = v end)
    addSlider(mainData, "Smoothness", 0, 1, aimSmoothness, function(v) aimSmoothness = v end)
    addSlider(mainData, "Range", 100, 1000, lockOnRange, function(v) lockOnRange = v end)

    -- COMBAT TAB
    local combatData = tabContainers["Combat"]
    addHeader(combatData, "⚔ COMBAT")
    addToggle(combatData, "God Mode", isGodMode, function(v) 
        isGodMode = v
        local char, humanoid = getChar()
        if humanoid then
            if v then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            else
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
    end)
    addToggle(combatData, "Invisibility", isInvisible, function(v)
        isInvisible = v
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = v and 1 or 0
                    part.CastShadow = not v
                end
            end
        end
    end)
    addHeader(combatData, "📊 STATS")
    addTextBox(combatData, "WalkSpeed", "Enter speed", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.WalkSpeed = val end
        end
    end)
    addTextBox(combatData, "JumpPower", "Enter jump power", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.JumpPower = val end
        end
    end)
    addTextBox(combatData, "Health", "Enter max health", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.MaxHealth = val; humanoid.Health = val end
        end
    end)
    addHeader(combatData, "👥 PLAYER ACTIONS")
    addToggle(combatData, "Respawn", false, function(v)
        if v then player:LoadCharacter() end
    end)

    -- MOVEMENT TAB
    local movementData = tabContainers["Movement"]
    addHeader(movementData, "🚀 FLIGHT")
    addToggle(movementData, "Fly", isFlying, function(v) 
        isFlying = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end)
    addSlider(movementData, "Fly Speed", 10, 200, flySpeed, function(v) flySpeed = v end)
    addHeader(movementData, "🔄 MOVEMENT")
    addToggle(movementData, "NoClip", isNoClip, function(v)
        isNoClip = v
        if v then
            if not noClipConnection then
                noClipConnection = RunService.Stepped:Connect(function()
                    local char = player.Character
                    if char then
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            end
        else
            if noClipConnection then
                noClipConnection:Disconnect()
                noClipConnection = nil
            end
            local char = player.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end)

    -- VISUALS TAB
    local visualsData = tabContainers["Visuals"]
    addHeader(visualsData, "🎨 ESP SETTINGS")
    addToggle(visualsData, "ESP Enabled", espEnabled, function(v) espEnabled = v end)
    addSlider(visualsData, "ESP Thickness", 1, 5, espThickness, function(v) espThickness = v end)
    addHeader(visualsData, "🎯 ESP COLOR")
    local colorPresets = {"Red", "Green", "Blue", "Yellow", "Purple", "Orange", "Cyan", "White"}
    local colorValues = {
        Red = Color3.new(1, 0, 0),
        Green = Color3.new(0, 1, 0),
        Blue = Color3.new(0, 0.4, 1),
        Yellow = Color3.new(1, 1, 0),
        Purple = Color3.new(0.7, 0, 1),
        Orange = Color3.new(1, 0.6, 0),
        Cyan = Color3.new(0, 1, 1),
        White = Color3.new(1, 1, 1)
    }
    local colorContainer = Instance.new("Frame")
    colorContainer.Size = UDim2.new(1, -10, 0, 36)
    colorContainer.Position = UDim2.new(0, 5, 0, visualsData.yPos)
    colorContainer.BackgroundTransparency = 1
    colorContainer.Parent = visualsData.container
    for i, colorName in ipairs(colorPresets) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.1, 0, 0.8, 0)
        btn.Position = UDim2.new(0.05 + (i-1) * 0.12, 0, 0.1, 0)
        btn.BackgroundColor3 = colorValues[colorName]
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.Parent = colorContainer
        btn.MouseButton1Click:Connect(function()
            espColor = colorValues[colorName]
        end)
    end
    visualsData.yPos = visualsData.yPos + 40
    visualsData.container.Size = UDim2.new(1, 0, 0, visualsData.yPos + 10)
    visualsData.scroll.CanvasSize = UDim2.new(0, 0, 0, visualsData.yPos + 20)

    -- RAGE TAB
    local rageData = tabContainers["Rage"]
    addHeader(rageData, "🔥 RAGE FEATURES")
    addToggle(rageData, "Rage Teleport (Back-and-Forth)", rageTeleportEnabled, function(v)
        rageTeleportEnabled = v
        if not v then
            if rageTimer then rageTimer:Disconnect(); rageTimer = nil end
            rageTarget = nil
            rageOriginalPos = nil
        elseif rageTarget then
            startRageTeleport()
        end
    end)
    
    local rageTargetBtn, rageTargetList = addDropdown(rageData, "Rage Target", {"Select Player"}, "Select Player", function(v)
        if v ~= "Select Player" then
            rageTarget = Players:FindFirstChild(v)
            if rageTeleportEnabled and rageTarget then startRageTeleport() end
        else
            rageTarget = nil
        end
    end)
    
    addHeader(rageData, "⚡ RAPID FIRE")
    addToggle(rageData, "Rapid Fire", rapidFireEnabled, function(v)
        rapidFireEnabled = v
        if v then
            if rapidFireConnection then rapidFireConnection:Disconnect() end
            rapidFireConnection = RunService.Heartbeat:Connect(function()
                if rapidFireEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, true, false, 0)
                    task.wait(rapidFireRate)
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, false, false, 0)
                end
            end)
        else
            if rapidFireConnection then rapidFireConnection:Disconnect(); rapidFireConnection = nil end
        end
    end)
    addSlider(rageData, "Rapid Fire Rate (s)", 0.01, 0.5, rapidFireRate, function(v) rapidFireRate = v end)
    
    addHeader(rageData, "🗡 RAPID MELEE")
    addToggle(rageData, "Rapid Melee", rapidMeleeEnabled, function(v)
        rapidMeleeEnabled = v
        if v then
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect() end
            rapidMeleeConnection = RunService.Heartbeat:Connect(function()
                if rapidMeleeEnabled and UserInputService:IsKeyDown(meleeKey) then
                    VirtualInputManager:SendKeyEvent(true, meleeKey, false, false, 0)
                    task.wait(rapidMeleeRate)
                    VirtualInputManager:SendKeyEvent(false, meleeKey, false, false, 0)
                end
            end)
        else
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect(); rapidMeleeConnection = nil end
        end
    end)
    addSlider(rageData, "Rapid Melee Rate (s)", 0.02, 0.5, rapidMeleeRate, function(v) rapidMeleeRate = v end)
    addTextBox(rageData, "Melee Key", "Q", function(v)
        if v and #v == 1 then
            meleeKey = Enum.KeyCode[v:upper()]
        end
    end)

    -- ============================================================
    -- UPDATE PLAYER LISTS
    -- ============================================================
    local function updatePlayerLists()
        local players = getPlayers()
        local names = {"Select Player"}
        for _, p in pairs(players) do table.insert(names, p.Name) end
        
        if rageTargetList then
            for _, child in pairs(rageTargetList:GetChildren()) do child:Destroy() end
            rageTargetList.Size = UDim2.new(0.4, 0, 0, #names * 24)
            for _, name in pairs(names) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 24)
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                btn.Text = name
                btn.TextColor3 = Color3.fromRGB(220, 220, 250)
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 11
                btn.BorderSizePixel = 0
                btn.Parent = rageTargetList
                btn.MouseButton1Click:Connect(function()
                    rageTargetBtn.Text = name
                    rageTargetList.Visible = false
                    if name ~= "Select Player" then
                        rageTarget = Players:FindFirstChild(name)
                        if rageTeleportEnabled and rageTarget then startRageTeleport() end
                    else
                        rageTarget = nil
                    end
                end)
            end
        end
    end

    -- ============================================================
    -- LOOPS & EVENTS
    -- ============================================================
    
    -- ESP Update
    RunService.RenderStepped:Connect(updateESP)
    
    -- Flight Update
    RunService.Heartbeat:Connect(handleFlying)
    
    -- Player list updates
    Players.PlayerAdded:Connect(function() task.wait(0.5); updatePlayerLists() end)
    Players.PlayerRemoved:Connect(function() task.wait(0.5); updatePlayerLists() end)
    task.wait(0.5)
    updatePlayerLists()
    
    -- Initialize ESP for existing players
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            createESP(otherPlayer)
        end
    end
    
    -- New player ESP
    Players.PlayerAdded:Connect(function(newPlayer)
        if newPlayer ~= player then
            task.wait(0.5)
            createESP(newPlayer)
        end
    end)

    -- Aimbot - Mouse events
    Mouse.Button1Down:Connect(function()
        isLockedOn = true
        lockOntoNearestPlayer()
    end)
    
    Mouse.Button1Up:Connect(function()
        isLockedOn = false
    end)
    
    -- Continuous aimbot while held
    RunService.RenderStepped:Connect(function()
        if isLockedOn then
            lockOntoNearestPlayer()
        end
    end)

    -- ============================================================
    -- RIGHT SHIFT TOGGLE
    -- ============================================================
    UserInputService.InputBegan:Connect(function(input)
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
        if bodyVelocity then bodyVelocity:Destroy() end
        if noClipConnection then noClipConnection:Disconnect() end
        if rageTimer then rageTimer:Disconnect() end
        if rapidFireConnection then rapidFireConnection:Disconnect() end
        if rapidMeleeConnection then rapidMeleeConnection:Disconnect() end
        for _, drawings in pairs(espDrawings) do
            for _, d in pairs(drawings) do d:Remove() end
        end
        espDrawings = {}
    end)

    print("✅ HvH Arena v7.0 loaded!")
    print("🔑 Press RightShift to toggle UI")
end

-- ============================================================
-- KEY SYSTEM
-- ============================================================
local function createKeySystem()
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "KeySystem"
    keyGui.ResetOnSpawn = false
    keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    keyGui.Parent = player.PlayerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    overlay.Parent = keyGui

    local unlockFrame = Instance.new("Frame")
    unlockFrame.Size = UDim2.new(0, 360, 0, 200)
    unlockFrame.Position = UDim2.new(0.5, -180, 0.5, -100)
    unlockFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    unlockFrame.BorderSizePixel = 0
    unlockFrame.ClipsDescendants = true
    unlockFrame.Parent = keyGui

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 3)
    accent.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    accent.BorderSizePixel = 0
    accent.Parent = unlockFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 36)
    title.Position = UDim2.new(0, 20, 0, 12)
    title.Text = "🔐 Enter License Key"
    title.TextColor3 = Color3.fromRGB(230, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = unlockFrame

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 18)
    subtitle.Position = UDim2.new(0, 20, 0, 48)
    subtitle.Text = "Enter the activation key to access HvH Arena"
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 180)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = unlockFrame

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.8, 0, 0, 36)
    keyInput.Position = UDim2.new(0.1, 0, 0, 76)
    keyInput.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.PlaceholderText = "Enter key..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 150)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 15
    keyInput.BorderSizePixel = 0
    keyInput.Parent = unlockFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 18)
    statusLabel.Position = UDim2.new(0, 20, 0, 118)
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = unlockFrame

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0.4, 0, 0, 34)
    unlockBtn.Position = UDim2.new(0.3, 0, 0, 145)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    unlockBtn.Text = "UNLOCK"
    unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 15
    unlockBtn.BorderSizePixel = 0
    unlockBtn.Parent = unlockFrame

    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then unlockBtn.MouseButton1Click:Fire() end
    end)

    unlockBtn.MouseButton1Click:Connect(function()
        local entered = keyInput.Text:upper()
        if entered == "UEONTOP" then
            statusLabel.Text = "✅ Key accepted! Loading..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            
            keyInput.Visible = false
            unlockBtn.Visible = false
            title.Text = "✅ Unlocked!"
            subtitle.Text = "You now have access to HvH Arena v7.0"
            
            print("Key accepted! Creating main UI...")
            task.wait(0.3)
            createMainUI()
            
            -- Destroy key GUI completely
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
-- START
-- ============================================================
print("🔐 HvH Arena v7.0 - Key system active")
print("📝 Enter key: UEONTOP")
createKeySystem()
