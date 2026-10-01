--// Prevent duplicate execution & Cleanup previous instance if exists
if _G.azerty098890Loaded then
    if _G.azerty098890Cleanup then pcall(_G.azerty098890Cleanup) end
end
_G.azerty098890Loaded = true

--// Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

--// Player & Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

--// Connection Tracker for Clean Unload (Anti-Memory Leak)
local connections = {}

--// Configuration & Persistence
local configFileName = "azerty098890_Config.json"
local flySpeed = 1
local flyTransparency = 0.75
local FLYING = false
local isFlyToggledOn = false
local useCFrameFly = false
local espEnabled = false
local wallCheckEnabled = true
local predictionEnabled = true
local CFloop, noclipConnection, espLoop, flyLoopConnection

-- Load settings safely
if pcall(function() return readfile and readfile(configFileName) end) then
    local success, decoded = pcall(function() 
        return HttpService:JSONDecode(readfile(configFileName)) 
    end)
    if success and decoded then
        flySpeed = decoded.flySpeed or 1
        flyTransparency = decoded.flyTransparency or 0.75
    end
end

local function saveConfig()
    if writefile then
        local data = {flySpeed = flySpeed, flyTransparency = flyTransparency}
        pcall(function()
            writefile(configFileName, HttpService:JSONEncode(data))
        end)
    end
end

--// Physics Instances
local attachment, linearVelocity, alignOrientation
local currentVelocity = Vector3.new(0, 0, 0)
local acceleration = 25
local boostMultiplier = 2.5
local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}

--// GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "azerty098890_Gui"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 260, 0, 290)
mainFrame.Position = UDim2.new(0.5, -130, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Thickness = 2
uiStroke.Color = Color3.fromRGB(88, 101, 242)

local headerFrame = Instance.new("Frame", mainFrame)
headerFrame.Size = UDim2.new(1, 0, 0, 42)
headerFrame.BackgroundColor3 = Color3.fromRGB(24, 27, 32)
headerFrame.BorderSizePixel = 0
Instance.new("UICorner", headerFrame).CornerRadius = UDim.new(0, 10)

-- Fix corner clipping on header bottom
local headerFix = Instance.new("Frame", headerFrame)
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Color3.fromRGB(24, 27, 32)
headerFix.BorderSizePixel = 0

local titleLabel = Instance.new("TextLabel", headerFrame)
titleLabel.Size = UDim2.new(1, -95, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "azerty098890"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Center

local closeButton = Instance.new("TextButton", headerFrame)
closeButton.Size = UDim2.new(0, 12, 0, 12); closeButton.Position = UDim2.new(1, -22, 0.5, -6)
closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60); closeButton.Text = ""
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(1, 0)

local minimizeButton = Instance.new("TextButton", headerFrame)
minimizeButton.Size = UDim2.new(0, 12, 0, 12); minimizeButton.Position = UDim2.new(1, -40, 0.5, -6)
minimizeButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15); minimizeButton.Text = ""
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(1, 0)

local cframeToggle = Instance.new("TextButton", headerFrame)
cframeToggle.Size = UDim2.new(0, 24, 0, 20); cframeToggle.Position = UDim2.new(1, -68, 0.5, -10)
cframeToggle.BackgroundColor3 = Color3.fromRGB(35, 38, 45); cframeToggle.Font = Enum.Font.GothamBold
cframeToggle.Text = "CF"; cframeToggle.TextColor3 = Color3.fromRGB(200, 200, 200); cframeToggle.TextSize = 11
Instance.new("UICorner", cframeToggle).CornerRadius = UDim.new(0, 4)
local cframeStroke = Instance.new("UIStroke", cframeToggle); cframeStroke.Color = Color3.fromRGB(55, 58, 65)

local bodyFrame = Instance.new("Frame", mainFrame)
bodyFrame.Size = UDim2.new(1, 0, 1, -42); bodyFrame.Position = UDim2.new(0, 0, 0, 42)
bodyFrame.BackgroundTransparency = 1

local flyButton = Instance.new("TextButton", bodyFrame)
flyButton.Size = UDim2.new(1, -20, 0, 36); flyButton.Position = UDim2.new(0, 10, 0, 10)
flyButton.BackgroundColor3 = Color3.fromRGB(30, 33, 40); flyButton.Font = Enum.Font.GothamMedium
flyButton.Text = "Fly (X) : OFF"; flyButton.TextColor3 = Color3.fromRGB(240, 240, 240); flyButton.TextSize = 14
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 6)
local flyStroke = Instance.new("UIStroke", flyButton); flyStroke.Color = Color3.fromRGB(50, 53, 60)

local espButton = Instance.new("TextButton", bodyFrame)
espButton.Size = UDim2.new(0.48, -5, 0, 32); espButton.Position = UDim2.new(0, 10, 0, 54)
espButton.BackgroundColor3 = Color3.fromRGB(30, 33, 40); espButton.Font = Enum.Font.GothamMedium
espButton.Text = "ESP: OFF"; espButton.TextColor3 = Color3.fromRGB(240, 240, 240); espButton.TextSize = 12
Instance.new("UICorner", espButton).CornerRadius = UDim.new(0, 6)
local espStroke = Instance.new("UIStroke", espButton); espStroke.Color = Color3.fromRGB(50, 53, 60)

local wallCheckButton = Instance.new("TextButton", bodyFrame)
wallCheckButton.Size = UDim2.new(0.48, -5, 0, 32); wallCheckButton.Position = UDim2.new(0.52, 0, 0, 54)
wallCheckButton.BackgroundColor3 = Color3.fromRGB(30, 33, 40); wallCheckButton.Font = Enum.Font.GothamMedium
wallCheckButton.Text = "WallCheck: ON"; wallCheckButton.TextColor3 = Color3.fromRGB(88, 101, 242); wallCheckButton.TextSize = 11
Instance.new("UICorner", wallCheckButton).CornerRadius = UDim.new(0, 6)
local wallCheckStroke = Instance.new("UIStroke", wallCheckButton); wallCheckStroke.Color = Color3.fromRGB(88, 101, 242)

local predictionButton = Instance.new("TextButton", bodyFrame)
predictionButton.Size = UDim2.new(1, -20, 0, 30); predictionButton.Position = UDim2.new(0, 10, 0, 94)
predictionButton.BackgroundColor3 = Color3.fromRGB(30, 33, 40); predictionButton.Font = Enum.Font.GothamMedium
predictionButton.Text = "Ballistic Prediction: ON"; predictionButton.TextColor3 = Color3.fromRGB(88, 101, 242); predictionButton.TextSize = 12
Instance.new("UICorner", predictionButton).CornerRadius = UDim.new(0, 6)
local predictionStroke = Instance.new("UIStroke", predictionButton); predictionStroke.Color = Color3.fromRGB(88, 101, 242)

local speedSliderLabel = Instance.new("TextLabel", bodyFrame)
speedSliderLabel.Size = UDim2.new(1, -20, 0, 20); speedSliderLabel.Position = UDim2.new(0, 10, 0, 132)
speedSliderLabel.BackgroundTransparency = 1; speedSliderLabel.Font = Enum.Font.Gotham
speedSliderLabel.Text = string.format("Speed: %.0f", flySpeed); speedSliderLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
speedSliderLabel.TextSize = 12; speedSliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local speedSlider = Instance.new("Frame", bodyFrame)
speedSlider.Size = UDim2.new(1, -20, 0, 6); speedSlider.Position = UDim2.new(0, 10, 0, 156)
speedSlider.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(0, 3)

local sliderBar = Instance.new("Frame", speedSlider)
local initialPercentage = math.clamp((flySpeed - 1) / 499, 0, 1)
sliderBar.Size = UDim2.new(initialPercentage, 0, 1, 0); sliderBar.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 3)

local sliderHandle = Instance.new("Frame", speedSlider)
sliderHandle.Size = UDim2.new(0, 16, 0, 16); sliderHandle.Position = UDim2.new(initialPercentage, -8, 0.5, -8)
sliderHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", sliderHandle).CornerRadius = UDim.new(1, 0)

local transparencyLabel = Instance.new("TextLabel", bodyFrame)
transparencyLabel.Size = UDim2.new(0.5, -15, 0, 30); transparencyLabel.Position = UDim2.new(0, 10, 0, 175)
transparencyLabel.BackgroundTransparency = 1; transparencyLabel.Font = Enum.Font.Gotham
transparencyLabel.Text = "Transparency:"; transparencyLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
transparencyLabel.TextSize = 12; transparencyLabel.TextXAlignment = Enum.TextXAlignment.Left

local transparencyBox = Instance.new("TextBox", bodyFrame)
transparencyBox.Size = UDim2.new(0.5, -15, 0, 28); transparencyBox.Position = UDim2.new(0.5, 5, 0, 176)
transparencyBox.BackgroundColor3 = Color3.fromRGB(12, 14, 18); transparencyBox.Font = Enum.Font.Gotham
transparencyBox.Text = tostring(flyTransparency); transparencyBox.TextColor3 = Color3.fromRGB(240, 240, 240)
transparencyBox.TextSize = 12; transparencyBox.ClearTextOnFocus = false
Instance.new("UICorner", transparencyBox).CornerRadius = UDim.new(0, 4)

--// Draggable Window System
local function makeDraggable(guiObject, dragHandle)
    local dragging, dragStart, startPos = false, nil, nil
    table.insert(connections, dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, guiObject.Position
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end 
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end
makeDraggable(mainFrame, headerFrame)

--// ESP System (Optimized, Safe Cache & Drawing Protection)
local espCache = {}

local function removeEsp(plr)
    if espCache[plr] then
        for _, obj in pairs(espCache[plr]) do
            if obj then pcall(function() obj:Remove() end) end
        end
        espCache[plr] = nil
    end
end

local function createEsp(plr)
    if espCache[plr] or plr == player then return end
    
    local success, box, name, healthBg, healthBar, predictionDot = pcall(function()
        local b = Drawing.new("Square")
        b.Visible = false; b.Thickness = 1.2; b.Filled = false

        local n = Drawing.new("Text")
        n.Visible = false; n.Color = Color3.fromRGB(255, 255, 255); n.Size = 12; n.Center = true; n.Outline = true

        local hBg = Drawing.new("Square")
        hBg.Visible = false; hBg.Color = Color3.fromRGB(0, 0, 0); hBg.Thickness = 1; hBg.Filled = true

        local hBar = Drawing.new("Square")
        hBar.Visible = false; hBar.Thickness = 1; hBar.Filled = true

        local pDot = Drawing.new("Circle")
        pDot.Visible = false; pDot.Radius = 3; pDot.Color = Color3.fromRGB(255, 50, 50); pDot.Filled = true

        return b, n, hBg, hBar, pDot
    end)

    if success and box then
        espCache[plr] = {Box = box, Name = name, HealthBg = healthBg, HealthBar = healthBar, Dot = predictionDot}
    end
end

for _, plr in ipairs(Players:GetPlayers()) do createEsp(plr) end
table.insert(connections, Players.PlayerAdded:Connect(createEsp))
table.insert(connections, Players.PlayerRemoving:Connect(removeEsp))

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function isVisible(targetPart)
    if not wallCheckEnabled then return true end
    local filterParts = {targetPart.Parent}
    if character and character.Parent then
        table.insert(filterParts, character)
    end
    raycastParams.FilterDescendantsInstances = filterParts
    local result = workspace:Raycast(Camera.CFrame.Position, targetPart.Position - Camera.CFrame.Position, raycastParams)
    return result == nil
end

local function toggleEsp(state)
    espEnabled = state
    espButton.TextColor3 = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(240, 240, 240)
    espStroke.Color = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(50, 53, 60)
    espButton.Text = state and "ESP: ON" or "ESP: OFF"

    if state then
        espLoop = RunService.RenderStepped:Connect(function()
            for plr, drawings in pairs(espCache) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                
                if hrp and hum and hum.Health > 0 then
                    local targetPos = hrp.Position
                    if predictionEnabled and hrp.AssemblyLinearVelocity.Magnitude > 0 then
                        local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
                        targetPos = hrp.Position + (hrp.AssemblyLinearVelocity * (distance / 600))
                    end

                    local vector, onScreen = Camera:WorldToViewportPoint(targetPos)
                    if onScreen then
                        local size = Vector2.new(2300 / vector.Z, 3200 / vector.Z)
                        local pos = Vector2.new(vector.X - size.X / 2, vector.Y - size.Y / 2)
                        
                        local visible = isVisible(hrp)
                        local boxColor = visible and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(88, 101, 242)

                        drawings.Box.Size = size; drawings.Box.Position = pos; drawings.Box.Color = boxColor; drawings.Box.Visible = true

                        local dist = rootPart and rootPart.Parent and math.floor((hrp.Position - rootPart.Position).Magnitude) or 0
                        drawings.Name.Text = string.format("%s [%dm]", plr.Name, dist)
                        drawings.Name.Position = Vector2.new(vector.X, pos.Y - 18)
                        drawings.Name.Visible = true

                        local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        local barHeight = size.Y * healthPercent
                        
                        drawings.HealthBg.Size = Vector2.new(3, size.Y)
                        drawings.HealthBg.Position = Vector2.new(pos.X - 6, pos.Y)
                        drawings.HealthBg.Visible = true

                        drawings.HealthBar.Size = Vector2.new(1, barHeight)
                        drawings.HealthBar.Position = Vector2.new(pos.X - 5, pos.Y + (size.Y - barHeight))
                        drawings.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                        drawings.HealthBar.Visible = true

                        if predictionEnabled then
                            local predVector, predOnScreen = Camera:WorldToViewportPoint(targetPos)
                            drawings.Dot.Position = Vector2.new(predVector.X, predVector.Y)
                            drawings.Dot.Visible = predOnScreen
                        else
                            drawings.Dot.Visible = false
                        end
                    else
                        for _, obj in pairs(drawings) do obj.Visible = false end
                    end
                else
                    for _, obj in pairs(drawings) do obj.Visible = false end
                end
            end
        end)
    else
        if espLoop then espLoop:Disconnect(); espLoop = nil end
        for _, drawings in pairs(espCache) do
            for _, obj in pairs(drawings) do obj.Visible = false end
        end
    end
end

--// Physics & Noclip loops
local function NoclipLoop()
    if character and character.Parent then
        for _, child in pairs(character:GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide then child.CanCollide = false end
        end
    end
end

local function startModernFlyLoop()
    if not character or not rootPart or not humanoid then return end
    FLYING = true
    noclipConnection = RunService.Heartbeat:Connect(NoclipLoop)
    
    attachment = Instance.new("Attachment", rootPart)
    linearVelocity = Instance.new("LinearVelocity", rootPart)
    linearVelocity.Attachment0 = attachment; linearVelocity.MaxForce = 9e9
    linearVelocity.VectorVelocity = Vector3.new(0, 0, 0); linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World

    alignOrientation = Instance.new("AlignOrientation", rootPart)
    alignOrientation.Attachment0 = attachment; alignOrientation.MaxTorque = 9e9
    alignOrientation.Responsiveness = 250; alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment

    humanoid.PlatformStand = true
    currentVelocity = Vector3.new(0, 0, 0)

    flyLoopConnection = RunService.Heartbeat:Connect(function(dt)
        if not FLYING or not rootPart.Parent then return end
        local moveVector = ((Camera.CFrame.LookVector * (CONTROL.F + CONTROL.B)) + ((Camera.CFrame * CFrame.new((CONTROL.L + CONTROL.R), (CONTROL.Q + CONTROL.E) * 0.2, 0).p) - Camera.CFrame.p))
        local currentFlySpeed = flySpeed * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and boostMultiplier or 1)
        local targetVelocity = moveVector.Magnitude > 0 and moveVector.Unit * currentFlySpeed or Vector3.new(0,0,0)
        
        currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
        linearVelocity.VectorVelocity = currentVelocity
        alignOrientation.CFrame = Camera.CFrame
    end)
end

local function startCFrameFlyLoop()
    if not character or not character:FindFirstChild("Head") then return end
    FLYING = true
    local Head = character.Head; Head.Anchored = true
    CFloop = RunService.Heartbeat:Connect(function(deltaTime)
        if not FLYING or not Head.Parent then return end
        local currentFlySpeed = flySpeed * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and boostMultiplier or 1)
        local effectiveSpeed = currentFlySpeed * 10
        local moveDirection = humanoid.MoveDirection * (effectiveSpeed * deltaTime)
        local headCFrame, camera = Head.CFrame, workspace.CurrentCamera
        local cameraCFrame = camera.CFrame
        local cameraOffset = headCFrame:ToObjectSpace(cameraCFrame).Position
        cameraCFrame = cameraCFrame * CFrame.new(-cameraOffset.X, -cameraOffset.Y, -cameraOffset.Z + 1)
        local cameraPosition, headPosition = cameraCFrame.Position, headCFrame.Position
        local objectSpaceVelocity = CFrame.new(cameraPosition, Vector3.new(headPosition.X, cameraPosition.Y, headPosition.Z)):VectorToObjectSpace(moveDirection)
        Head.CFrame = CFrame.new(headPosition) * (cameraCFrame - cameraPosition) * CFrame.new(objectSpaceVelocity)
    end)
end

local function setFlying(state)
    isFlyToggledOn = state
    if FLYING == state or not character or not character.Parent then return end
    flyButton.TextColor3 = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(240, 240, 240)
    flyStroke.Color = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(50, 53, 60)
    flyButton.Text = state and "Fly (X) : ON" or "Fly (X) : OFF"

    if state then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = flyTransparency end
        end
        if useCFrameFly then
            for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
            startCFrameFlyLoop()
        else
            startModernFlyLoop()
        end
    else
        FLYING = false
        if flyLoopConnection then flyLoopConnection:Disconnect(); flyLoopConnection = nil end
        if CFloop then CFloop:Disconnect(); CFloop = nil end
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        if character and character:FindFirstChild("Head") then character.Head.Anchored = false end
        if linearVelocity then linearVelocity:Destroy() end
        if alignOrientation then alignOrientation:Destroy() end
        if attachment then attachment:Destroy() end
        if humanoid and humanoid.Parent then humanoid.PlatformStand = false end
        CONTROL = {F=0,B=0,L=0,R=0,Q=0,E=0}
        if character and character.Parent then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    if part.Name ~= "HumanoidRootPart" then part.Transparency = 0 end
                end
            end
        end
    end
end

--// Input Handlers
local keyMap = {[Enum.KeyCode.W]="F",[Enum.KeyCode.S]="B",[Enum.KeyCode.A]="L",[Enum.KeyCode.D]="R",[Enum.KeyCode.Q]="Q",[Enum.KeyCode.E]="E"}
local valueMap = {[Enum.KeyCode.W]=1,[Enum.KeyCode.S]=-1,[Enum.KeyCode.A]=-1,[Enum.KeyCode.D]=1,[Enum.KeyCode.Q]=-1,[Enum.KeyCode.E]=1}

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if keyMap[input.KeyCode] then
        CONTROL[keyMap[input.KeyCode]] = valueMap[input.KeyCode]
    elseif input.KeyCode == Enum.KeyCode.X then
        setFlying(not isFlyToggledOn)
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input) 
    if keyMap[input.KeyCode] then CONTROL[keyMap[input.KeyCode]] = 0 end 
end))

table.insert(connections, player.CharacterAdded:Connect(function(newChar)
    if flyLoopConnection then flyLoopConnection:Disconnect(); flyLoopConnection = nil end
    if CFloop then CFloop:Disconnect(); CFloop = nil end
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    FLYING = false; character = newChar
    humanoid = newChar:WaitForChild("Humanoid"); rootPart = newChar:WaitForChild("HumanoidRootPart")
    if isFlyToggledOn then setFlying(true) end
end))

--// Cleanup Function definition
local function cleanup()
    _G.azerty098890Loaded = false
    if espLoop then espLoop:Disconnect() end
    if flyLoopConnection then flyLoopConnection:Disconnect() end
    if CFloop then CFloop:Disconnect() end
    if noclipConnection then noclipConnection:Disconnect() end
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    for plr, drawings in pairs(espCache) do
        for _, obj in pairs(drawings) do
            if obj then pcall(function() obj:Remove() end) end
        end
    end
    if FLYING then setFlying(false) end
    pcall(function() screenGui:Destroy() end)
end
_G.azerty098890Cleanup = cleanup

closeButton.MouseButton1Click:Connect(cleanup)
flyButton.MouseButton1Click:Connect(function() setFlying(not isFlyToggledOn) end)
espButton.MouseButton1Click:Connect(function() toggleEsp(not espEnabled) end)

wallCheckButton.MouseButton1Click:Connect(function()
    wallCheckEnabled = not wallCheckEnabled
    wallCheckButton.TextColor3 = wallCheckEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(240, 240, 240)
    wallCheckStroke.Color = wallCheckEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(50, 53, 60)
    wallCheckButton.Text = wallCheckEnabled and "WallCheck: ON" or "WallCheck: OFF"
end)

predictionButton.MouseButton1Click:Connect(function()
    predictionEnabled = not predictionEnabled
    predictionButton.TextColor3 = predictionEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(240, 240, 240)
    predictionStroke.Color = predictionEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(50, 53, 60)
    predictionButton.Text = predictionEnabled and "Ballistic Prediction: ON" or "Ballistic Prediction: OFF"
end)

cframeToggle.MouseButton1Click:Connect(function()
    useCFrameFly = not useCFrameFly
    cframeToggle.TextColor3 = useCFrameFly and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(200, 200, 200)
    cframeStroke.Color = useCFrameFly and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(55, 58, 65)
end)

local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, 260, 0, 42) or UDim2.new(0, 260, 0, 290)
    if not isMinimized and bodyFrame and bodyFrame.Parent then bodyFrame.Visible = true end
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = targetSize})
    tween:Play()
    tween.Completed:Connect(function()
        if isMinimized and bodyFrame and bodyFrame.Parent then bodyFrame.Visible = false end
    end)
end)

transparencyBox.FocusLost:Connect(function()
    local num = tonumber(transparencyBox.Text)
    if num and num >= 0 and num <= 1 then 
        flyTransparency = num
        saveConfig()
        if FLYING and character and character.Parent then 
            for _, part in ipairs(character:GetDescendants()) do 
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = flyTransparency end 
            end 
        end
    else 
        transparencyBox.Text = tostring(flyTransparency) 
    end
end)

--// Slider Logic
local function updateSlider(input)
    local sliderWidth = speedSlider.AbsoluteSize.X
    if sliderWidth <= 0 then return end
    local newX = math.clamp(input.Position.X - speedSlider.AbsolutePosition.X, 0, sliderWidth)
    local percentage = newX / sliderWidth
    
    flySpeed = 1 + (percentage * 499) 
    speedSliderLabel.Text = string.format("Speed: %.0f", flySpeed)
    sliderBar.Size = UDim2.new(percentage, 0, 1, 0)
    sliderHandle.Position = UDim2.new(percentage, -8, 0.5, -8)
    saveConfig()
end

local isDraggingSlider = false
table.insert(connections, speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSlider(input)
    end
end))

table.insert(connections, sliderHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSlider(input)
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
end))

table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end))
