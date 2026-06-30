--[[
    HvH ARENA v8.1 - FULLY FIXED DROPDOWN + ALL FEATURES
    Key: UEONTOP
]]

-- Variables (from universal script)
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local lockOnRange = 50
local camera = workspace.CurrentCamera
local isLockedOn = false

-- ESP Variables
local espEnabled = true
local espColor = Color3.new(1, 0, 0)
local espThickness = 1
local espTransparency = 0.5
local espFontSize = 14
local espFont = Drawing.Fonts.UI

-- Shoot Through Walls
local shootThroughWallsEnabled = true
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = {}

-- Invisibility
local isInvisible = false

-- Fly
local isFlying = false
local flySpeed = 50
local bodyVelocity = nil
local userInputService = game:GetService("UserInputService")

-- NoClip
local isNoClip = false
local noClipConnection = nil

-- God Mode
local isGodMode = false

-- Silent Aim
local silentAimEnabled = false
local aimSmoothness = 0.3
local aimFOV = 120

-- Rage
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

-- ESP Drawings
local espDrawings = {}

-- UI
local screenGui = nil
local mainFrame = nil
local uiVisible = true
local currentTab = "Main"
local keyGui = nil

-- Dropdown references
local teleportDropdownBtn = nil
local teleportDropdownList = nil
local killDropdownBtn = nil
local killDropdownList = nil
local rageTargetBtn = nil
local rageTargetList = nil

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
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= player and isPlayerAlive(p.Character) then
            table.insert(list, p)
        end
    end
    return list
end

local function getAllPlayerNames()
    local names = {"Select Player"}
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    return names
end

local function clamp(v, low, high) return math.min(high, math.max(low, v)) end

-- ============================================================
-- ESP (from universal script)
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
            local headPosition, headVisible = camera:WorldToViewportPoint(head.Position)

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
-- AIMBOT (from universal script)
-- ============================================================
local function findNearestPlayerHead()
    local nearestPlayer = nil
    local nearestAngle = aimFOV
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, otherPlayer in pairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local head = otherPlayer.Character:FindFirstChild("Head")
            if head and isPlayerAlive(otherPlayer.Character) then
                local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    local angle = dist / camera.ViewportSize.X * 180
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
            local newCF = CFrame.lookAt(camera.CFrame.Position, nearestHead.Position)
            camera.CFrame = camera.CFrame:Lerp(newCF, 1 - aimSmoothness)
        else
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, nearestHead.Position)
        end
    end
end

-- ============================================================
-- FLIGHT (from universal script)
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
            if userInputService:IsKeyDown(Enum.KeyCode.W) then
                direction = direction + camera.CFrame.LookVector
            end
            if userInputService:IsKeyDown(Enum.KeyCode.S) then
                direction = direction - camera.CFrame.LookVector
            end
            if userInputService:IsKeyDown(Enum.KeyCode.A) then
                direction = direction - camera.CFrame.RightVector
            end
            if userInputService:IsKeyDown(Enum.KeyCode.D) then
                direction = direction + camera.CFrame.RightVector
            end
            if userInputService:IsKeyDown(Enum.KeyCode.Space) then
                direction = direction + Vector3.new(0, 1, 0)
            end
            if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
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
    
    rageTimer = game:GetService("RunService").Heartbeat:Connect(function()
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
-- UI CREATION (using universal script style)
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
    mainFrame.BackgroundColor3 = Color3.new(0.08, 0.08, 0.12)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "HvH Arena v8.1"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = header

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0.5, -10)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.BackgroundColor3 = Color3.new(0.5, 0, 0)
    closeButton.BorderSizePixel = 0
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 14
    closeButton.Parent = header
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 30)
    tabBar.Position = UDim2.new(0, 0, 0, 30)
    tabBar.BackgroundColor3 = Color3.new(0.12, 0.12, 0.16)
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
        btn.TextColor3 = (i == 1) and Color3.new(1, 1, 1) or Color3.new(0.6, 0.6, 0.7)
        btn.BackgroundColor3 = (i == 1) and Color3.new(0.25, 0.25, 0.3) or Color3.new(0.12, 0.12, 0.16)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 12
        btn.Parent = tabBar
        tabButtons[tabName] = btn

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -10, 1, -75)
        scroll.Position = UDim2.new(0, 5, 0, 65)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 5
        scroll.CanvasSize = UDim2.new(0, 0, 0, 10)
        scroll.Visible = (i == 1)
        scroll.Parent = mainFrame
        
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 10)
        container.BackgroundTransparency = 1
        container.Parent = scroll
        
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
            tabButtons[name].BackgroundColor3 = (name == tabName) and Color3.new(0.25, 0.25, 0.3) or Color3.new(0.12, 0.12, 0.16)
            tabButtons[name].TextColor3 = (name == tabName) and Color3.new(1, 1, 1) or Color3.new(0.6, 0.6, 0.7)
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
        h.TextColor3 = Color3.new(1, 1, 1)
        h.BackgroundTransparency = 1
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.Font = Enum.Font.SourceSansBold
        h.TextSize = 14
        h.Parent = tabData.container
        tabData.yPos = tabData.yPos + 26
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return h
    end

    local function addToggle(tabData, labelText, defaultState, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 30)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 13
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.25, 0, 0.7, 0)
        btn.Position = UDim2.new(0.7, 0, 0.15, 0)
        btn.BackgroundColor3 = defaultState and Color3.new(0, 0.7, 0.3) or Color3.new(0.5, 0, 0)
        btn.Text = defaultState and "ON" or "OFF"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = container

        local state = defaultState
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = state and "ON" or "OFF"
            btn.BackgroundColor3 = state and Color3.new(0, 0.7, 0.3) or Color3.new(0.5, 0, 0)
            callback(state)
        end)

        tabData.yPos = tabData.yPos + 34
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
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 13
        lbl.Parent = container

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.15, 0, 0.5, 0)
        valueLabel.Position = UDim2.new(0.85, 0, 0, 0)
        valueLabel.Text = tostring(defaultVal)
        valueLabel.TextColor3 = Color3.new(0, 0.7, 1)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.SourceSansBold
        valueLabel.TextSize = 13
        valueLabel.Parent = container

        local track = Instance.new("Frame")
        track.Size = UDim2.new(0.7, 0, 0.2, 0)
        track.Position = UDim2.new(0, 0, 0.6, 0)
        track.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        track.BorderSizePixel = 0
        track.Parent = container

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.new(0, 0.7, 1)
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
        userInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSlider(input.Position.X)
            end
        end)

        tabData.yPos = tabData.yPos + 42
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        return container
    end

    -- ============================================================
    -- DROPDOWN WITH PROPER PLAYER LIST
    -- ============================================================
    local function createDropdown(tabData, labelText, options, default, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 32)
        container.Position = UDim2.new(0, 5, 0, tabData.yPos)
        container.BackgroundTransparency = 1
        container.Parent = tabData.container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.Text = labelText
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 13
        lbl.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.4, 0, 0.75, 0)
        btn.Position = UDim2.new(0.55, 0, 0.12, 0)
        btn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
        btn.Text = default
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = container

        local list = Instance.new("Frame")
        list.Size = UDim2.new(0.4, 0, 0, 10)
        list.Position = UDim2.new(0.55, 0, 1, 2)
        list.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
        list.BorderSizePixel = 0
        list.Visible = false
        list.ZIndex = 10
        list.ClipsDescendants = true
        list.Parent = container

        -- Create list items
        local listItems = {}
        local function rebuildList()
            -- Clear existing items
            for _, child in pairs(list:GetChildren()) do child:Destroy() end
            listItems = {}
            
            -- Get fresh player list
            local currentOptions = getAllPlayerNames()
            
            -- Set list height based on number of options
            local itemHeight = 24
            local maxItems = math.min(#currentOptions, 8)
            list.Size = UDim2.new(0.4, 0, 0, maxItems * itemHeight)
            
            for i, opt in ipairs(currentOptions) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, itemHeight)
                optBtn.BackgroundColor3 = (i % 2 == 0) and Color3.new(0.18, 0.18, 0.22) or Color3.new(0.15, 0.15, 0.2)
                optBtn.Text = opt
                optBtn.TextColor3 = Color3.new(1, 1, 1)
                optBtn.Font = Enum.Font.SourceSans
                optBtn.TextSize = 12
                optBtn.BorderSizePixel = 0
                optBtn.Parent = list
                optBtn.MouseButton1Click:Connect(function()
                    btn.Text = opt
                    list.Visible = false
                    callback(opt)
                end)
                listItems[opt] = optBtn
            end
        end
        
        rebuildList()

        btn.MouseButton1Click:Connect(function()
            rebuildList() -- Refresh list before showing
            list.Visible = not list.Visible
        end)

        tabData.yPos = tabData.yPos + 36
        tabData.container.Size = UDim2.new(1, 0, 0, tabData.yPos + 10)
        tabData.scroll.CanvasSize = UDim2.new(0, 0, 0, tabData.yPos + 20)
        
        -- Return the button and list for later updating
        return btn, list, rebuildList
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
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 13
        lbl.Parent = container

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.5, 0, 0.8, 0)
        box.Position = UDim2.new(0.35, 0, 0.1, 0)
        box.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
        box.TextColor3 = Color3.new(1, 1, 1)
        box.PlaceholderText = placeholder
        box.Font = Enum.Font.SourceSans
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
    addHeader(mainData, "CONFIGURATION")
    addToggle(mainData, "ESP", espEnabled, function(v) espEnabled = v end)
    addToggle(mainData, "Aimbot", isLockedOn, function(v) isLockedOn = v end)
    addToggle(mainData, "Silent Aim", silentAimEnabled, function(v) silentAimEnabled = v end)
    addToggle(mainData, "Wall Hacks", shootThroughWallsEnabled, function(v) shootThroughWallsEnabled = v end)
    addHeader(mainData, "AIMBOT SETTINGS")
    addSlider(mainData, "FOV", 10, 180, aimFOV, function(v) aimFOV = v end)
    addSlider(mainData, "Smoothness", 0, 1, aimSmoothness, function(v) aimSmoothness = v end)
    addSlider(mainData, "Range", 10, 500, lockOnRange, function(v) lockOnRange = v end)

    -- COMBAT TAB
    local combatData = tabContainers["Combat"]
    addHeader(combatData, "COMBAT")
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
    addHeader(combatData, "STATS")
    addTextBox(combatData, "WalkSpeed", "Enter WalkSpeed", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.WalkSpeed = val end
        end
    end)
    addTextBox(combatData, "JumpPower", "Enter JumpPower", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.JumpPower = val end
        end
    end)
    addTextBox(combatData, "Health", "Enter Health", function(v)
        local val = tonumber(v)
        if val then
            local char, humanoid = getChar()
            if humanoid then humanoid.MaxHealth = val; humanoid.Health = val end
        end
    end)
    addHeader(combatData, "PLAYER ACTIONS")
    addToggle(combatData, "Respawn", false, function(v)
        if v then player:LoadCharacter() end
    end)

    -- MOVEMENT TAB
    local movementData = tabContainers["Movement"]
    addHeader(movementData, "FLIGHT")
    addToggle(movementData, "Fly", isFlying, function(v)
        isFlying = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end)
    addSlider(movementData, "Fly Speed", 10, 200, flySpeed, function(v) flySpeed = v end)
    addHeader(movementData, "MOVEMENT")
    addToggle(movementData, "NoClip", isNoClip, function(v)
        isNoClip = v
        if v then
            if not noClipConnection then
                noClipConnection = game:GetService("RunService").Stepped:Connect(function()
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
    addHeader(visualsData, "ESP SETTINGS")
    addToggle(visualsData, "ESP Enabled", espEnabled, function(v) espEnabled = v end)
    addSlider(visualsData, "ESP Thickness", 1, 5, espThickness, function(v) espThickness = v end)
    addHeader(visualsData, "ESP COLOR")
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
    addHeader(rageData, "RAGE FEATURES")
    addToggle(rageData, "Rage Teleport", rageTeleportEnabled, function(v)
        rageTeleportEnabled = v
        if not v then
            if rageTimer then rageTimer:Disconnect(); rageTimer = nil end
            rageTarget = nil
            rageOriginalPos = nil
        elseif rageTarget then
            startRageTeleport()
        end
    end)
    
    -- Rage Target Dropdown
    rageTargetBtn, rageTargetList, rageRebuild = createDropdown(rageData, "Rage Target", getAllPlayerNames(), "Select Player", function(v)
        if v ~= "Select Player" then
            rageTarget = game.Players:FindFirstChild(v)
            if rageTeleportEnabled and rageTarget then startRageTeleport() end
        else
            rageTarget = nil
        end
    end)
    
    addHeader(rageData, "RAPID FIRE")
    addToggle(rageData, "Rapid Fire", rapidFireEnabled, function(v)
        rapidFireEnabled = v
        if v then
            if rapidFireConnection then rapidFireConnection:Disconnect() end
            rapidFireConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if rapidFireEnabled and userInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    local VirtualInputManager = game:GetService("VirtualInputManager")
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, true, false, 0)
                    task.wait(rapidFireRate)
                    VirtualInputManager:SendMouseButtonEvent(Vector2.new(0, 0), 0, false, false, 0)
                end
            end)
        else
            if rapidFireConnection then rapidFireConnection:Disconnect(); rapidFireConnection = nil end
        end
    end)
    addSlider(rageData, "Rapid Fire Rate", 0.01, 0.5, rapidFireRate, function(v) rapidFireRate = v end)
    
    addHeader(rageData, "RAPID MELEE")
    addToggle(rageData, "Rapid Melee", rapidMeleeEnabled, function(v)
        rapidMeleeEnabled = v
        if v then
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect() end
            rapidMeleeConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if rapidMeleeEnabled and userInputService:IsKeyDown(meleeKey) then
                    local VirtualInputManager = game:GetService("VirtualInputManager")
                    VirtualInputManager:SendKeyEvent(true, meleeKey, false, false, 0)
                    task.wait(rapidMeleeRate)
                    VirtualInputManager:SendKeyEvent(false, meleeKey, false, false, 0)
                end
            end)
        else
            if rapidMeleeConnection then rapidMeleeConnection:Disconnect(); rapidMeleeConnection = nil end
        end
    end)
    addSlider(rageData, "Rapid Melee Rate", 0.02, 0.5, rapidMeleeRate, function(v) rapidMeleeRate = v end)
    addTextBox(rageData, "Melee Key", "Q", function(v)
        if v and #v == 1 then
            meleeKey = Enum.KeyCode[v:upper()]
        end
    end)

    -- ============================================================
    -- PLAYER LIST UPDATE FUNCTION
    -- ============================================================
    local function updateAllPlayerLists()
        if rageRebuild then rageRebuild() end
    end

    -- ============================================================
    -- INITIALIZE ESP
    -- ============================================================
    for _, otherPlayer in pairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player then
            createESP(otherPlayer)
        end
    end

    game.Players.PlayerAdded:Connect(function(newPlayer)
        if newPlayer ~= player then
            task.wait(0.5)
            createESP(newPlayer)
            updateAllPlayerLists()
        end
    end)

    game.Players.PlayerRemoved:Connect(function()
        task.wait(0.5)
        updateAllPlayerLists()
    end)

    -- ============================================================
    -- LOOPS & EVENTS (from universal script)
    -- ============================================================
    
    -- ESP Update
    game:GetService("RunService").RenderStepped:Connect(updateESP)
    
    -- Flight Update
    game:GetService("RunService").RenderStepped:Connect(handleFlying)
    
    -- Update player lists periodically
    task.wait(1)
    updateAllPlayerLists()

    -- Aimbot (from universal script)
    mouse.Button1Down:Connect(function()
        isLockedOn = true
        lockOntoNearestPlayer()
    end)

    mouse.Button1Up:Connect(function()
        isLockedOn = false
    end)

    -- Continuous aimbot
    game:GetService("RunService").RenderStepped:Connect(function()
        if isLockedOn then
            lockOntoNearestPlayer()
        end
    end)

    -- ============================================================
    -- RIGHT SHIFT TOGGLE
    -- ============================================================
    userInputService.InputBegan:Connect(function(input, gameProcessed)
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
    player.OnTeleport:Connect(function()
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

    print("✅ HvH Arena v8.1 loaded!")
    print("🔑 Press RightShift to toggle UI")
end

-- ============================================================
-- KEY SYSTEM
-- ============================================================
local function createKeySystem()
    keyGui = Instance.new("ScreenGui")
    keyGui.Name = "KeySystem"
    keyGui.ResetOnSpawn = false
    keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    keyGui.Parent = player.PlayerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    overlay.Parent = keyGui

    local unlockFrame = Instance.new("Frame")
    unlockFrame.Size = UDim2.new(0, 360, 0, 200)
    unlockFrame.Position = UDim2.new(0.5, -180, 0.5, -100)
    unlockFrame.BackgroundColor3 = Color3.new(0.07, 0.07, 0.1)
    unlockFrame.BorderSizePixel = 0
    unlockFrame.ClipsDescendants = true
    unlockFrame.Parent = keyGui

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 3)
    accent.BackgroundColor3 = Color3.new(0, 0.7, 1)
    accent.BorderSizePixel = 0
    accent.Parent = unlockFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 36)
    title.Position = UDim2.new(0, 20, 0, 12)
    title.Text = "🔐 Enter License Key"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = unlockFrame

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 18)
    subtitle.Position = UDim2.new(0, 20, 0, 48)
    subtitle.Text = "Enter the activation key to access HvH Arena"
    subtitle.TextColor3 = Color3.new(0.6, 0.6, 0.7)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.SourceSans
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = unlockFrame

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.8, 0, 0, 36)
    keyInput.Position = UDim2.new(0.1, 0, 0, 76)
    keyInput.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
    keyInput.TextColor3 = Color3.new(1, 1, 1)
    keyInput.PlaceholderText = "Enter key..."
    keyInput.PlaceholderColor3 = Color3.new(0.5, 0.5, 0.6)
    keyInput.Font = Enum.Font.SourceSans
    keyInput.TextSize = 15
    keyInput.BorderSizePixel = 0
    keyInput.Parent = unlockFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 18)
    statusLabel.Position = UDim2.new(0, 20, 0, 118)
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.new(1, 0.4, 0.4)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = unlockFrame

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0.4, 0, 0, 34)
    unlockBtn.Position = UDim2.new(0.3, 0, 0, 145)
    unlockBtn.BackgroundColor3 = Color3.new(0, 0.7, 1)
    unlockBtn.Text = "UNLOCK"
    unlockBtn.TextColor3 = Color3.new(1, 1, 1)
    unlockBtn.Font = Enum.Font.SourceSansBold
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
            statusLabel.TextColor3 = Color3.new(0, 1, 0.4)
            
            keyInput.Visible = false
            unlockBtn.Visible = false
            title.Text = "✅ Unlocked!"
            subtitle.Text = "You now have access to HvH Arena v8.1"
            
            print("Key accepted! Creating main UI...")
            
            -- Create main UI
            createMainUI()
            
            -- Destroy key GUI completely
            keyGui:Destroy()
        else
            statusLabel.Text = "❌ Invalid key. Please try again."
            statusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
            keyInput.Text = ""
        end
    end)

    return keyGui
end

-- ============================================================
-- START
-- ============================================================
print("🔐 HvH Arena v8.1 - Key system active")
print("📝 Enter key: UEONTOP")
createKeySystem()
