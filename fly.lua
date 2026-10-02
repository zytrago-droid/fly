-- FlyGuiV9 — LinearVelocity + AlignOrientation + AssemblyLinearVelocity hybrid
-- Roblox 2025+ — compatible Hyperion (client-side, pas d'ancrage, pas de BodyMover déprécié)
-- Register: PEER — tech delivery

--// Prevent duplicate execution
if _G.FlyGuiV9Loaded then return end
_G.FlyGuiV9Loaded = true

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
local flySpeed = 50
local flyTransparency = 0.75
local FLYING = false
local isFlyToggledOn = false
local useCFrameFly = false          -- legacy CFrame mode (fallback only)
local useHybridFly = true           -- default: AssemblyLinearVelocity + AlignOrientation
local bodyGyro, bodyVelocity, CFloop, noclipConnection
local linearVelocity, alignOrientation, rootAttachment
local velocityConnection, ownershipConnection

--// Control scheme
local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}

--// Network ownership keep-alive
-- CRITICAL: ensures the client retains ownership of its own character.
-- Without this, the server can reclaim physics and kill the fly silently.
local function keepOwnership()
    if not rootPart or not rootPart.Parent then return end
    pcall(function()
        rootPart:SetNetworkOwner(player)
    end)
end

--// Noclip
local function NoclipLoop()
    if not character then return end
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("BasePart") and child.CanCollide then
            child.CanCollide = false
        end
    end
end

--// ──────────────────────────────────────────────
-- MODE 1: Hybrid — AssemblyLinearVelocity + AlignOrientation (DEFAULT)
-- The modern replacement for BodyVelocity + BodyGyro.
-- No anchoring. No deprecated classes. Server sees coherent velocity.
-- ──────────────────────────────────────────────
local function startHybridFlyLoop()
    if not character or not rootPart or not humanoid then return end
    FLYING = true

    -- Keep ownership alive
    keepOwnership()
    ownershipConnection = RunService.Heartbeat:Connect(function()
        if FLYING then keepOwnership() end
    end)

    -- Noclip while flying
    noclipConnection = RunService.Heartbeat:Connect(NoclipLoop)

    -- AlignOrientation replaces BodyGyro — keeps character facing camera
    rootAttachment = Instance.new("Attachment")
    rootAttachment.Name = "FlyAttachment"
    rootAttachment.Parent = rootPart

    alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Name = "FlyOrientation"
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Attachment0 = rootAttachment
    alignOrientation.RigidityEnabled = false
    alignOrientation.MaxTorque = 9e9
    alignOrientation.Responsiveness = 50
    alignOrientation.Parent = rootPart

    -- PlatformStand — required so Humanoid doesn't fight our forces
    humanoid.PlatformStand = true

    -- The fly loop: compute direction, set AssemblyLinearVelocity directly.
    -- This bypasses the need for BodyVelocity entirely and is the cleanest
    -- client-side movement — server replicates velocity, not teleportation.
    velocityConnection = RunService.RenderStepped:Connect(function(dt)
        if not FLYING or not rootPart or not rootPart.Parent then return end

        local camera = workspace.CurrentCamera
        local moveDir = Vector3.zero

        if CONTROL.F == 1 then moveDir += camera.CFrame.LookVector end
        if CONTROL.B == 1 then moveDir -= camera.CFrame.LookVector end
        if CONTROL.L == 1 then moveDir -= camera.CFrame.RightVector end
        if CONTROL.R == 1 then moveDir += camera.CFrame.RightVector end
        if CONTROL.Q == 1 then moveDir += Vector3.yAxis end
        if CONTROL.E == 1 then moveDir -= Vector3.yAxis end

        if moveDir.Magnitude > 0 then
            rootPart.AssemblyLinearVelocity = moveDir.Unit * flySpeed
        else
            -- Gentle decay instead of hard stop — less robotic signature
            rootPart.AssemblyLinearVelocity *= 0.85
            if rootPart.AssemblyLinearVelocity.Magnitude < 0.5 then
                rootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end

        -- Face camera direction (replaces BodyGyro.CFrame = camera.CFrame)
        if alignOrientation then
            alignOrientation.CFrame = camera.CFrame
        end
    end)

    -- Watch for Humanoid state changes — reapply PlatformStand if server resets it
    humanoid.StateChanged:Connect(function(_, newState)
        if FLYING and newState ~= Enum.HumanoidStateType.PlatformStanding then
            humanoid.PlatformStand = true
        end
    end)
end

--// ──────────────────────────────────────────────
-- MODE 2: CFrame fly — legacy fallback, less safe vs anti-cheat
-- Kept for games where physics-based fly gets server-rejected.
-- No Head anchoring — uses HumanoidRootPart CFrame directly.
-- ──────────────────────────────────────────────
local function startCFrameFlyLoop()
    if not character or not rootPart then return end
    FLYING = true

    keepOwnership()
    ownershipConnection = RunService.Heartbeat:Connect(function()
        if FLYING then keepOwnership() end
    end)

    noclipConnection = RunService.Heartbeat:Connect(NoclipLoop)
    humanoid.PlatformStand = true

    CFloop = RunService.RenderStepped:Connect(function(dt)
        if not FLYING or not rootPart or not rootPart.Parent then return end

        local camera = workspace.CurrentCamera
        local moveDir = Vector3.zero

        if CONTROL.F == 1 then moveDir += camera.CFrame.LookVector end
        if CONTROL.B == 1 then moveDir -= camera.CFrame.LookVector end
        if CONTROL.L == 1 then moveDir -= camera.CFrame.RightVector end
        if CONTROL.R == 1 then moveDir += camera.CFrame.RightVector end
        if CONTROL.Q == 1 then moveDir += Vector3.yAxis end
        if CONTROL.E == 1 then moveDir -= Vector3.yAxis end

        local newPos = rootPart.Position + (moveDir.Unit * flySpeed * dt)
        rootPart.CFrame = CFrame.new(newPos, newPos + camera.CFrame.LookVector)
    end)
end

--// ──────────────────────────────────────────────
-- Stop — clean teardown of all constraints and connections
-- ──────────────────────────────────────────────
local function stopFly()
    FLYING = false

    if velocityConnection then velocityConnection:Disconnect(); velocityConnection = nil end
    if ownershipConnection then ownershipConnection:Disconnect(); ownershipConnection = nil end
    if CFloop then CFloop:Disconnect(); CFloop = nil end
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end

    if linearVelocity then linearVelocity:Destroy(); linearVelocity = nil end
    if alignOrientation then alignOrientation:Destroy(); alignOrientation = nil end
    if rootAttachment then rootAttachment:Destroy(); rootAttachment = nil end

    if humanoid and humanoid.Parent then
        humanoid.PlatformStand = false
    end

    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                if part.Name ~= "HumanoidRootPart" then
                    part.Transparency = 0
                end
            end
        end
        if rootPart and rootPart.Parent then
            rootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end

    CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
end

--// ──────────────────────────────────────────────
-- GUI (kept structurally identical — only speed slider range updated)
-- ──────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyGuiV9"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local uiScale = Instance.new("UIScale", screenGui)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.Size = UDim2.new(0, 250, 0, 190)
mainFrame.Position = UDim2.new(0.5, -125, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 32, 35)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

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
titleLabel.Text = "Fly Gui V9 — modern"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Center

local closeButton = Instance.new("TextButton", headerFrame)
closeButton.Size = UDim2.new(0, 12, 0, 12)
closeButton.Position = UDim2.new(1, -22, 0.5, -6)
closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeButton.Text = ""
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(1, 0)

local minimizeButton = Instance.new("TextButton", headerFrame)
minimizeButton.Size = UDim2.new(0, 12, 0, 12)
minimizeButton.Position = UDim2.new(1, -40, 0.5, -6)
minimizeButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
minimizeButton.Text = ""
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(1, 0)

local modeToggle = Instance.new("TextButton", headerFrame)
modeToggle.Size = UDim2.new(0, 36, 0, 20)
modeToggle.Position = UDim2.new(1, -80, 0.5, -10)
modeToggle.BackgroundColor3 = Color3.fromRGB(44, 46, 51)
modeToggle.Font = Enum.Font.GothamBold
modeToggle.Text = "H"
modeToggle.TextColor3 = Color3.fromRGB(88, 101, 242)
modeToggle.TextSize = 12
Instance.new("UICorner", modeToggle).CornerRadius = UDim.new(0, 4)
local modeStroke = Instance.new("UIStroke", modeToggle)
modeStroke.Color = Color3.fromRGB(20, 20, 20)

local bodyFrame = Instance.new("Frame", mainFrame)
bodyFrame.Size = UDim2.new(1, 0, 1, -40)
bodyFrame.Position = UDim2.new(0, 0, 0, 40)
bodyFrame.BackgroundTransparency = 1

local flyButton = Instance.new("TextButton", bodyFrame)
flyButton.Size = UDim2.new(1, -20, 0, 35)
flyButton.Position = UDim2.new(0, 10, 0, 10)
flyButton.BackgroundColor3 = Color3.fromRGB(44, 46, 51)
flyButton.Font = Enum.Font.Gotham
flyButton.Text = "Fly"
flyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flyButton.TextSize = 16
Instance.new("UICorner", flyButton).CornerRadius = UDim.new(0, 6)
local flyStroke = Instance.new("UIStroke", flyButton)
flyStroke.Color = Color3.fromRGB(20, 20, 20)

local speedSliderLabel = Instance.new("TextLabel", bodyFrame)
speedSliderLabel.Size = UDim2.new(1, -20, 0, 20)
speedSliderLabel.Position = UDim2.new(0, 10, 0, 55)
speedSliderLabel.BackgroundTransparency = 1
speedSliderLabel.Font = Enum.Font.Gotham
speedSliderLabel.Text = "Speed: 50"
speedSliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedSliderLabel.TextSize = 14
speedSliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local speedSlider = Instance.new("Frame", bodyFrame)
speedSlider.Size = UDim2.new(1, -20, 0, 6)
speedSlider.Position = UDim2.new(0, 10, 0, 80)
speedSlider.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(0, 3)

local sliderBar = Instance.new("Frame", speedSlider)
sliderBar.Size = UDim2.new(0, 0, 1, 0)
sliderBar.BackgroundColor3 = Color3.fromRGB(114, 137, 218)
Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 3)

local sliderHandle = Instance.new("TextButton", speedSlider)
sliderHandle.Size = UDim2.new(0, 18, 0, 18)
sliderHandle.Position = UDim2.new(0, -9, 0.5, -9)
sliderHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderHandle.Text = ""
Instance.new("UICorner", sliderHandle).CornerRadius = UDim.new(1, 0)

local transparencyLabel = Instance.new("TextLabel", bodyFrame)
transparencyLabel.Size = UDim2.new(0.5, -15, 0, 30)
transparencyLabel.Position = UDim2.new(0, 10, 0, 100)
transparencyLabel.BackgroundTransparency = 1
transparencyLabel.Font = Enum.Font.Gotham
transparencyLabel.Text = "Transparency:"
transparencyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
transparencyLabel.TextSize = 14
transparencyLabel.TextXAlignment = Enum.TextXAlignment.Left

local transparencyBox = Instance.new("TextBox", bodyFrame)
transparencyBox.Size = UDim2.new(0.5, -15, 0, 30)
transparencyBox.Position = UDim2.new(0.5, 5, 0, 100)
transparencyBox.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
transparencyBox.Font = Enum.Font.Gotham
transparencyBox.Text = tostring(flyTransparency)
transparencyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
transparencyBox.TextSize = 14
transparencyBox.ClearTextOnFocus = false
Instance.new("UICorner", transparencyBox).CornerRadius = UDim.new(0, 4)

--// Dragging
local function makeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end
makeDraggable(mainFrame, headerFrame)

--// ──────────────────────────────────────────────
-- setFlying — router between hybrid and legacy modes
-- ──────────────────────────────────────────────
local function setFlying(state)
    isFlyToggledOn = state
    if FLYING == state or not character or not character.Parent then return end

    flyButton.TextColor3 = state and Color3.fromRGB(88, 101, 242)
        or Color3.fromRGB(255, 255, 255)
    flyStroke.Color = state and Color3.fromRGB(88, 101, 242)
        or Color3.fromRGB(20, 20, 20)

    if state then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = flyTransparency
            end
        end

        if useCFrameFly then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            startCFrameFlyLoop()
        else
            startHybridFlyLoop()
        end
    else
        stopFly()
    end
end

--// ──────────────────────────────────────────────
-- Keybinds
-- ──────────────────────────────────────────────
local keyMap = {
    [Enum.KeyCode.W] = "F", [Enum.KeyCode.S] = "B",
    [Enum.KeyCode.A] = "L", [Enum.KeyCode.D] = "R",
    [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.E] = "E"
}
local valueMap = {
    [Enum.KeyCode.W] = 1, [Enum.KeyCode.S] = -1,
    [Enum.KeyCode.A] = -1, [Enum.KeyCode.D] = 1,
    [Enum.KeyCode.Q] = 1, [Enum.KeyCode.E] = -1
}

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not keyMap[input.KeyCode] then return end
    CONTROL[keyMap[input.KeyCode]] = valueMap[input.KeyCode]
end)
UserInputService.InputEnded:Connect(function(input)
    if keyMap[input.KeyCode] then
        CONTROL[keyMap[input.KeyCode]] = 0
    end
end)

--// ──────────────────────────────────────────────
-- Character respawn handler
-- ──────────────────────────────────────────────
player.CharacterAdded:Connect(function(newChar)
    stopFly()
    FLYING = false
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    if isFlyToggledOn then
        task.wait(0.5)
        setFlying(true)
    end
end)

--// ──────────────────────────────────────────────
-- GUI interactions
-- ──────────────────────────────────────────────
closeButton.MouseButton1Click:Connect(function()
    stopFly()
    _G.FlyGuiV9Loaded = false
    screenGui:Destroy()
end)

flyButton.MouseButton1Click:Connect(function()
    setFlying(not isFlyToggledOn)
end)

-- Mode toggle: H (hybrid) ↔ CF (legacy CFrame)
modeToggle.MouseButton1Click:Connect(function()
    useCFrameFly = not useCFrameFly
    if useCFrameFly then
        modeToggle.Text = "CF"
        modeToggle.TextColor3 = Color3.fromRGB(255, 200, 50)
    else
        modeToggle.Text = "H"
        modeToggle.TextColor3 = Color3.fromRGB(88, 101, 242)
    end
    -- If flying, restart in the new mode
    if isFlyToggledOn then
        local wasOn = isFlyToggledOn
        setFlying(false)
        task.wait(0.1)
        setFlying(true)
    end
end)

local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    bodyFrame.Visible = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, 250, 0, 40)
        or UDim2.new(0, 250, 0, 190)
    TweenService:Create(
        mainFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {Size = targetSize}
    ):Play()
end)

transparencyBox.FocusLost:Connect(function()
    local num = tonumber(transparencyBox.Text)
    if num and num >= 0 and num <= 1 then
        flyTransparency = num
        if FLYING then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = flyTransparency
                end
            end
        end
    else
        transparencyBox.Text = tostring(flyTransparency)
    end
end)

-- Speed slider — range 10–500
local function updateSlider(input)
    local sliderWidth = speedSlider.AbsoluteSize.X
    local newX = math.clamp(
        input.Position.X - speedSlider.AbsolutePosition.X,
        0, sliderWidth
    )
    local percentage = newX / sliderWidth
    flySpeed = 10 + (percentage * 490)
    speedSliderLabel.Text = string.format("Speed: %.0f", flySpeed)
    sliderBar.Size = UDim2.new(percentage, 0, 1, 0)
    sliderHandle.Position = UDim2.new(percentage, -9, 0.5, -9)
end

local isDraggingSlider = false
sliderHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSlider(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)
