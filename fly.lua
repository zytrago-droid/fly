--// Prevent duplicate execution
if _G.FlyGuiV12Loaded then return end
_G.FlyGuiV12Loaded = true

--// Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// Player & Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

--// Configuration
local flySpeed = 1
local flyTransparency = 0.75
local FLYING = false
local isFlyToggledOn = false
local useCFrameFly = false
local CFloop, noclipConnection

--// Physics Instances
local attachment, linearVelocity, alignOrientation
local currentVelocity = Vector3.new(0, 0, 0)
local acceleration = 15
local boostMultiplier = 2.5

--// Control scheme
local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}

--// GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyGuiV12"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiScale = Instance.new("UIScale", screenGui)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 250, 0, 170)
mainFrame.Position = UDim2.new(0.5, -125, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 32, 35)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0, 8)

local uiStroke = Instance.new("UIStroke", mainFrame)
uiStroke.Thickness = 2
uiStroke.Color = Color3.fromRGB(0, 0, 0)

local headerFrame = Instance.new("Frame", mainFrame)
headerFrame.Size = UDim2.new(1, 0, 0, 40)
headerFrame.BackgroundTransparency = 1

local titleLabel = Instance.new("TextLabel", headerFrame)
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Fly Gui V12 by Botak"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
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
cframeToggle.BackgroundColor3 = Color3.fromRGB(44, 46, 51); cframeToggle.Font = Enum.Font.GothamBold
cframeToggle.Text = "CF"; cframeToggle.TextColor3 = Color3.fromRGB(255, 255, 255); cframeToggle.TextSize = 12
Instance.new("UICorner", cframeToggle).CornerRadius = UDim.new(0, 4)
local cframeStroke = Instance.new("UIStroke", cframeToggle); cframeStroke.Color = Color3.fromRGB(20, 20, 20)

local bodyFrame = Instance.new("Frame", mainFrame)
bodyFrame.Size = UDim2.new(1, 0, 1, -40); bodyFrame.Position = UDim2.new(0, 0, 0, 40)
bodyFrame.BackgroundTransparency = 1

local flyButton = Instance.new("TextButton", bodyFrame)
flyButton.Size = UDim2.new(1, -20, 0, 35); flyButton.Position = UDim2.new(0, 10, 0, 10)
flyButton.BackgroundColor3 = Color3.fromRGB(44, 46, 51); flyButton.Font = Enum.Font.Gotham
flyButton.Text = "Fly (X)"; flyButton.TextColor3 = Color3.fromRGB(255, 255, 255); flyButton.TextSize = 16
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 6)
local flyStroke = Instance.new("UIStroke", flyButton); flyStroke.Color = Color3.fromRGB(20, 20, 20)

local speedSliderLabel = Instance.new("TextLabel", bodyFrame)
speedSliderLabel.Size = UDim2.new(1, -20, 0, 20); speedSliderLabel.Position = UDim2.new(0, 10, 0, 55)
speedSliderLabel.BackgroundTransparency = 1; speedSliderLabel.Font = Enum.Font.Gotham
speedSliderLabel.Text = "Speed: 1"; speedSliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedSliderLabel.TextSize = 14; speedSliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local speedSlider = Instance.new("Frame", bodyFrame)
speedSlider.Size = UDim2.new(1, -20, 0, 6); speedSlider.Position = UDim2.new(0, 10, 0, 80)
speedSlider.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(0, 3)

local sliderBar = Instance.new("Frame", speedSlider)
sliderBar.Size = UDim2.new(0, 0, 1, 0); sliderBar.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 3)

local sliderHandle = Instance.new("TextButton", speedSlider)
sliderHandle.Size = UDim2.new(0, 18, 0, 18); sliderHandle.Position = UDim2.new(0, -9, 0.5, -9)
sliderHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255); sliderHandle.Text = ""
Instance.new("UICorner", sliderHandle).CornerRadius = UDim.new(1, 0)

local transparencyLabel = Instance.new("TextLabel", bodyFrame)
transparencyLabel.Size = UDim2.new(0.5, -15, 0, 30); transparencyLabel.Position = UDim2.new(0, 10, 0, 95)
transparencyLabel.BackgroundTransparency = 1; transparencyLabel.Font = Enum.Font.Gotham
transparencyLabel.Text = "Transparency:"; transparencyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
transparencyLabel.TextSize = 14; transparencyLabel.TextXAlignment = Enum.TextXAlignment.Left

local transparencyBox = Instance.new("TextBox", bodyFrame)
transparencyBox.Size = UDim2.new(0.5, -15, 0, 30); transparencyBox.Position = UDim2.new(0.5, 5, 0, 95)
transparencyBox.BackgroundColor3 = Color3.fromRGB(20, 22, 25); transparencyBox.Font = Enum.Font.Gotham
transparencyBox.Text = tostring(flyTransparency); transparencyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
transparencyBox.TextSize = 14; transparencyBox.ClearTextOnFocus = false
Instance.new("UICorner", transparencyBox).CornerRadius = UDim.new(0, 4)

--// Dragging Logic
local function makeDraggable(guiObject, dragHandle)
    local dragging = false; local dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, guiObject.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
makeDraggable(mainFrame, headerFrame)

--// Noclip Loop
local function NoclipLoop()
    if character ~= nil then
        for _, child in pairs(character:GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide == true then child.CanCollide = false end
        end
    end
end

--// Modern Physics Loop
local function startModernFlyLoop()
    if not character or not rootPart or not humanoid then return end; FLYING = true
    noclipConnection = RunService.Heartbeat:Connect(NoclipLoop)
    
    attachment = Instance.new("Attachment", rootPart)
    
    linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Attachment0 = attachment
    linearVelocity.MaxForce = 9e9
    linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVelocity.Parent = rootPart

    alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Attachment0 = attachment
    alignOrientation.MaxTorque = 9e9
    alignOrientation.Responsiveness = 200
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Parent = rootPart

    if humanoid then humanoid.PlatformStand = true end
    currentVelocity = Vector3.new(0, 0, 0)

    task.spawn(function()
        repeat
            local dt = task.wait()
            local camera = workspace.CurrentCamera
            local moveVector = ((camera.CFrame.LookVector * (CONTROL.F + CONTROL.B)) + ((camera.CFrame * CFrame.new((CONTROL.L + CONTROL.R), (CONTROL.Q + CONTROL.E) * 0.2, 0).p) - camera.CFrame.p))
            local currentFlySpeed = flySpeed * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and boostMultiplier or 1)
            local targetVelocity = moveVector.Magnitude > 0 and moveVector.Unit * currentFlySpeed or Vector3.new(0,0,0)
            
            currentVelocity = currentVelocity:Lerp(targetVelocity, math.clamp(acceleration * dt, 0, 1))
            linearVelocity.VectorVelocity = currentVelocity
            alignOrientation.CFrame = camera.CFrame
        until not FLYING or not rootPart.Parent
        
        if linearVelocity then linearVelocity:Destroy() end
        if alignOrientation then alignOrientation:Destroy() end
        if attachment then attachment:Destroy() end
        if humanoid and humanoid.Parent then humanoid.PlatformStand = false end
        CONTROL = {F=0,B=0,L=0,R=0,Q=0,E=0}
    end)
end

local function startCFrameFlyLoop()
    if not character or not character:FindFirstChild("Head") then return end; FLYING = true
    local Head = character.Head; Head.Anchored = true
    CFloop = RunService.Heartbeat:Connect(function(deltaTime)
        local currentFlySpeed = flySpeed * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and boostMultiplier or 1)
        local effectiveSpeed = currentFlySpeed * 10; local moveDirection = humanoid.MoveDirection * (effectiveSpeed * deltaTime)
        local headCFrame, camera = Head.CFrame, workspace.CurrentCamera; local cameraCFrame = camera.CFrame
        local cameraOffset = headCFrame:ToObjectSpace(cameraCFrame).Position
        cameraCFrame = cameraCFrame * CFrame.new(-cameraOffset.X, -cameraOffset.Y, -cameraOffset.Z + 1)
        local cameraPosition, headPosition = cameraCFrame.Position, headCFrame.Position
        local objectSpaceVelocity = CFrame.new(cameraPosition, Vector3.new(headPosition.X, cameraPosition.Y, headPosition.Z)):VectorToObjectSpace(moveDirection)
        Head.CFrame = CFrame.new(headPosition) * (cameraCFrame - cameraPosition) * CFrame.new(objectSpaceVelocity)
    end)
end

local function updateSlider(input)
    local sliderWidth = speedSlider.AbsoluteSize.X; local newX = math.clamp(input.Position.X - speedSlider.AbsolutePosition.X, 0, sliderWidth)
    local percentage = newX / sliderWidth; flySpeed = 1 + (percentage * 499) 
    speedSliderLabel.Text = string.format("Speed: %.0f", flySpeed)
    sliderBar.Size = UDim2.new(percentage, 0, 1, 0); sliderHandle.Position = UDim2.new(percentage, -9, 0.5, -9)
end

local function setFlying(state)
    isFlyToggledOn = state
    if FLYING == state or not character or not character.Parent then return end
    flyButton.TextColor3 = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(255, 255, 255)
    flyStroke.Color = state and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(20, 20, 20)

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
        if CFloop then CFloop:Disconnect(); CFloop = nil end
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        if character and character:FindFirstChild("Head") then character.Head.Anchored = false end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                if part.Name ~= "HumanoidRootPart" then part.Transparency = 0 end
            end
        end
    end
end

--// Inputs & Handlers
local keyMap = {[Enum.KeyCode.W]="F",[Enum.KeyCode.S]="B",[Enum.KeyCode.A]="L",[Enum.KeyCode.D]="R",[Enum.KeyCode.Q]="Q",[Enum.KeyCode.E]="E"}
local valueMap = {[Enum.KeyCode.W]=1,[Enum.KeyCode.S]=-1,[Enum.KeyCode.A]=-1,[Enum.KeyCode.D]=1,[Enum.KeyCode.Q]=-1,[Enum.KeyCode.E]=1}
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if keyMap[input.KeyCode] then
        CONTROL[keyMap[input.KeyCode]] = valueMap[input.KeyCode]
    elseif input.KeyCode == Enum.KeyCode.X then
        setFlying(not isFlyToggledOn)
    end
end)
UserInputService.InputEnded:Connect(function(input) if keyMap[input.KeyCode] then CONTROL[keyMap[input.KeyCode]] = 0 end end)

player.CharacterAdded:Connect(function(newChar)
    if CFloop then CFloop:Disconnect(); CFloop = nil end
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    FLYING = false; character = newChar
    humanoid = newChar:WaitForChild("Humanoid"); rootPart = newChar:WaitForChild("HumanoidRootPart")
    if isFlyToggledOn then setFlying(true) end
end)

closeButton.MouseButton1Click:Connect(function()
    _G.FlyGuiV12Loaded = false; screenGui:Destroy()
end)
flyButton.MouseButton1Click:Connect(function() setFlying(not isFlyToggledOn) end)
cframeToggle.MouseButton1Click:Connect(function()
    useCFrameFly = not useCFrameFly
    cframeToggle.TextColor3 = useCFrameFly and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(255, 255, 255)
    cframeStroke.Color = useCFrameFly and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(20, 20, 20)
end)

local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, 250, 0, 40) or UDim2.new(0, 250, 0, 170)
    if not isMinimized then bodyFrame.Visible = true end
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = targetSize})
    tween:Play()
    tween.Completed:Connect(function()
        if isMinimized then bodyFrame.Visible = false end
    end)
end)

transparencyBox.FocusLost:Connect(function(enterPressed)
    local num = tonumber(transparencyBox.Text)
    if num and num >= 0 and num <= 1 then flyTransparency = num
        if FLYING then for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = flyTransparency end end end
    else transparencyBox.Text = tostring(flyTransparency) end
end)

local isDraggingSlider = false
sliderHandle.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = true; updateSlider(input) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = false end end)
UserInputService.InputChanged:Connect(function(input) if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input) end end)
