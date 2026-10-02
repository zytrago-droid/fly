local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

if not RunService:IsClient() then
	return
end

local player = Players.LocalPlayer

if not player then
	return
end

-- azerty098890 est volontairement limité au clavier + souris.
if not UserInputService.KeyboardEnabled
	or not UserInputService.MouseEnabled then
	return
end

local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "azerty098890"

local ACTION_FORWARD = "azerty098890_Forward"
local ACTION_BACKWARD = "azerty098890_Backward"
local ACTION_LEFT = "azerty098890_Left"
local ACTION_RIGHT = "azerty098890_Right"
local ACTION_UP = "azerty098890_Up"
local ACTION_DOWN = "azerty098890_Down"

local CONFIG = {
	MinSpeed = 1,
	MaxSpeed = 500,
	DefaultSpeed = 80,

	Acceleration = 12,
	Deceleration = 18,

	OrientationResponsiveness = 35,
	MaxAngularVelocity = 100,
	MaxTorque = 10000000,

	DefaultTransparency = 0.75,

	GUIWidth = 280,
	GUIHeight = 250,

	MaxDeltaTime = 0.1,

	CharacterLoadTimeout = 10,
	CharacterRetryDelay = 0.5,
	CharacterRetryCount = 3,

	GUI_MARGIN = 8,

	InputPriority = 3000,
}

CONFIG.MinSpeed = math.max(
	0,
	tonumber(CONFIG.MinSpeed) or 0
)

CONFIG.MaxSpeed = math.max(
	CONFIG.MinSpeed,
	tonumber(CONFIG.MaxSpeed) or CONFIG.MinSpeed
)

CONFIG.DefaultSpeed = math.clamp(
	tonumber(CONFIG.DefaultSpeed) or CONFIG.MinSpeed,
	CONFIG.MinSpeed,
	CONFIG.MaxSpeed
)

CONFIG.Acceleration = math.max(
	tonumber(CONFIG.Acceleration) or 0.01,
	0.01
)

CONFIG.Deceleration = math.max(
	tonumber(CONFIG.Deceleration) or 0.01,
	0.01
)

-- AlignOrientation documente Responsiveness entre 5 et 200.
CONFIG.OrientationResponsiveness = math.clamp(
	tonumber(CONFIG.OrientationResponsiveness) or 35,
	5,
	200
)

CONFIG.MaxAngularVelocity = math.max(
	tonumber(CONFIG.MaxAngularVelocity) or 1,
	0.01
)

CONFIG.MaxTorque = math.max(
	tonumber(CONFIG.MaxTorque) or 1,
	0.01
)

CONFIG.DefaultTransparency = math.clamp(
	tonumber(CONFIG.DefaultTransparency) or 0,
	0,
	1
)

CONFIG.MaxDeltaTime = math.clamp(
	tonumber(CONFIG.MaxDeltaTime) or 0.1,
	0.016,
	0.25
)

if playerGui:FindFirstChild(GUI_NAME) then
	return
end

local state = {
	Requested = false,
	Active = false,
	Destroying = false,

	Speed = CONFIG.DefaultSpeed,
	Transparency = CONFIG.DefaultTransparency,

	Velocity = Vector3.zero,

	Character = nil,
	Humanoid = nil,
	RootPart = nil,

	PreviousAutoRotate = true,

	Attachment = nil,
	LinearVelocity = nil,
	AlignOrientation = nil,

	SavedParts = {},
	Connections = {},

	CharacterToken = 0,
	UIToken = 0,

	LastFacing = Vector3.new(0, 0, -1),

	InputBound = false,
}

local input = {
	Forward = 0,
	Backward = 0,
	Left = 0,
	Right = 0,
	Up = 0,
	Down = 0,
}

local function disconnect(name)
	local connection = state.Connections[name]

	if connection then
		connection:Disconnect()
		state.Connections[name] = nil
	end
end

local function connect(name, signal, callback)
	disconnect(name)

	if not signal then
		return nil
	end

	local connection = signal:Connect(callback)

	state.Connections[name] = connection

	return connection
end

local function disconnectAll()
	for name, connection in pairs(state.Connections) do
		if connection then
			connection:Disconnect()
		end

		state.Connections[name] = nil
	end
end

local function resetInput()
	for key in pairs(input) do
		input[key] = 0
	end

	state.Velocity = Vector3.zero
end

local function isCharacterValid()
	local character = state.Character
	local humanoid = state.Humanoid
	local rootPart = state.RootPart

	return character ~= nil
		and character.Parent ~= nil
		and humanoid ~= nil
		and humanoid.Parent ~= nil
		and rootPart ~= nil
		and rootPart.Parent ~= nil
		and humanoid.Health > 0
end

local function loadCharacter(character, timeout)
	if state.Destroying then
		return false
	end

	if not character or not character.Parent then
		return false
	end

	timeout = math.max(
		0.1,
		tonumber(timeout) or CONFIG.CharacterLoadTimeout
	)

	local deadline = os.clock() + timeout

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		local remaining =
			math.max(0, deadline - os.clock())

		if remaining > 0 then
			humanoid = character:WaitForChild(
				"Humanoid",
				remaining
			)
		end
	end

	if not humanoid then
		return false
	end

	local rootPart =
		character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		local remaining =
			math.max(0, deadline - os.clock())

		if remaining > 0 then
			rootPart = character:WaitForChild(
				"HumanoidRootPart",
				remaining
			)
		end
	end

	if not humanoid
		or not rootPart
		or not humanoid:IsA("Humanoid")
		or not rootPart:IsA("BasePart") then
		return false
	end

	if not character.Parent then
		return false
	end

	state.Character = character
	state.Humanoid = humanoid
	state.RootPart = rootPart
	state.PreviousAutoRotate = humanoid.AutoRotate

	local look = rootPart.CFrame.LookVector

	local horizontalLook = Vector3.new(
		look.X,
		0,
		look.Z
	)

	if horizontalLook.Magnitude > 0.001 then
		state.LastFacing = horizontalLook.Unit
	end

	return true
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(
	CONFIG.GUIWidth,
	CONFIG.GUIHeight
)
mainFrame.Position = UDim2.new(
	0.5,
	-CONFIG.GUIWidth / 2,
	0.2,
	0
)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 32, 35)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 1.5
mainStroke.Color = Color3.fromRGB(15, 15, 15)
mainStroke.Parent = mainFrame

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local dragArea = Instance.new("Frame")
dragArea.Name = "DragArea"
dragArea.Size = UDim2.new(1, -80, 1, 0)
dragArea.Position = UDim2.fromOffset(0, 0)
dragArea.BackgroundTransparency = 1
dragArea.Active = true
dragArea.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "azerty098890"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = dragArea

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(70, 18)
statusLabel.Position = UDim2.new(1, -150, 0, 12)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "PC / AZERTY"
statusLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
statusLabel.TextSize = 9
statusLabel.TextXAlignment = Enum.TextXAlignment.Right
statusLabel.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.Size = UDim2.fromOffset(14, 14)
minimizeButton.Position = UDim2.new(1, -48, 0.5, -7)
minimizeButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
minimizeButton.Text = ""
minimizeButton.AutoButtonColor = false
minimizeButton.Parent = header

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(1, 0)
minimizeCorner.Parent = minimizeButton

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.fromOffset(14, 14)
closeButton.Position = UDim2.new(1, -24, 0.5, -7)
closeButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeButton.Text = ""
closeButton.AutoButtonColor = false
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeButton

local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -42)
body.Position = UDim2.fromOffset(0, 42)
body.BackgroundTransparency = 1
body.Parent = mainFrame

local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Size = UDim2.new(1, -20, 0, 38)
flyButton.Position = UDim2.fromOffset(10, 10)
flyButton.BackgroundColor3 = Color3.fromRGB(44, 46, 51)
flyButton.Font = Enum.Font.GothamBold
flyButton.Text = "FLY : OFF"
flyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flyButton.TextSize = 15
flyButton.AutoButtonColor = false
flyButton.Parent = body

local flyCorner = Instance.new("UICorner")
flyCorner.CornerRadius = UDim.new(0, 7)
flyCorner.Parent = flyButton

local flyStroke = Instance.new("UIStroke")
flyStroke.Color = Color3.fromRGB(20, 20, 20)
flyStroke.Thickness = 1
flyStroke.Parent = flyButton

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.Position = UDim2.fromOffset(10, 58)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
speedLabel.TextSize = 13
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = body

local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(1, -30, 0, 6)
speedSlider.Position = UDim2.fromOffset(15, 83)
speedSlider.BackgroundColor3 = Color3.fromRGB(18, 20, 23)
speedSlider.BorderSizePixel = 0
speedSlider.Active = true
speedSlider.Parent = body

local speedSliderCorner = Instance.new("UICorner")
speedSliderCorner.CornerRadius = UDim.new(1, 0)
speedSliderCorner.Parent = speedSlider

local speedBar = Instance.new("Frame")
speedBar.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
speedBar.BorderSizePixel = 0
speedBar.Parent = speedSlider

local speedBarCorner = Instance.new("UICorner")
speedBarCorner.CornerRadius = UDim.new(1, 0)
speedBarCorner.Parent = speedBar

local speedHandle = Instance.new("TextButton")
speedHandle.Size = UDim2.fromOffset(18, 18)
speedHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
speedHandle.Text = ""
speedHandle.AutoButtonColor = false
speedHandle.Parent = speedSlider

local speedHandleCorner = Instance.new("UICorner")
speedHandleCorner.CornerRadius = UDim.new(1, 0)
speedHandleCorner.Parent = speedHandle

local transparencyLabel = Instance.new("TextLabel")
transparencyLabel.Size = UDim2.new(0.55, -15, 0, 30)
transparencyLabel.Position = UDim2.fromOffset(10, 105)
transparencyLabel.BackgroundTransparency = 1
transparencyLabel.Font = Enum.Font.Gotham
transparencyLabel.Text = "Transparency"
transparencyLabel.TextColor3 = Color3.fromRGB(205, 205, 205)
transparencyLabel.TextSize = 13
transparencyLabel.TextXAlignment = Enum.TextXAlignment.Left
transparencyLabel.Parent = body

local transparencyBox = Instance.new("TextBox")
transparencyBox.Size = UDim2.new(0.45, -15, 0, 30)
transparencyBox.Position = UDim2.new(0.55, 5, 0, 105)
transparencyBox.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
transparencyBox.Font = Enum.Font.Gotham
transparencyBox.Text = tostring(state.Transparency)
transparencyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
transparencyBox.TextSize = 13
transparencyBox.ClearTextOnFocus = false
transparencyBox.Parent = body

local transparencyCorner = Instance.new("UICorner")
transparencyCorner.CornerRadius = UDim.new(0, 5)
transparencyCorner.Parent = transparencyBox

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 55)
infoLabel.Position = UDim2.fromOffset(10, 148)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Gotham
infoLabel.Text =
	"ZQSD  Move    E/A  Up/Down\n"
	.. "Camera-relative flight\n"
	.. "LinearVelocity + AlignOrientation"
infoLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
infoLabel.TextSize = 11
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = body

local function updateFlyButton()
	if not flyButton.Parent then
		return
	end

	if state.Active then
		flyButton.Text = "FLY : ON"
		flyButton.TextColor3 =
			Color3.fromRGB(120, 130, 255)
		flyStroke.Color =
			Color3.fromRGB(88, 101, 242)
	else
		flyButton.Text = "FLY : OFF"
		flyButton.TextColor3 =
			Color3.fromRGB(255, 255, 255)
		flyStroke.Color =
			Color3.fromRGB(20, 20, 20)
	end
end

local function savePart(part)
	if not part
		or not part.Parent
		or not part:IsA("BasePart") then
		return
	end

	if state.SavedParts[part] then
		return
	end

	state.SavedParts[part] = {
		CanCollide = part.CanCollide,
		LocalTransparencyModifier =
			part.LocalTransparencyModifier,
	}
end

local function saveCharacterProperties()
	table.clear(state.SavedParts)

	local character = state.Character

	if not character
		or not character.Parent then
		return
	end

	for _, object in ipairs(character:GetDescendants()) do
		savePart(object)
	end
end

local function restoreCharacterProperties()
	for part, properties in pairs(state.SavedParts) do
		if part and part.Parent then
			part.CanCollide =
				properties.CanCollide

			part.LocalTransparencyModifier =
				properties.LocalTransparencyModifier
		end
	end

	table.clear(state.SavedParts)
end

local function applyTransparency(part)
	if not part
		or not part.Parent
		or not part:IsA("BasePart") then
		return
	end

	if part == state.RootPart then
		part.LocalTransparencyModifier = 0
	else
		part.LocalTransparencyModifier =
			state.Transparency
	end
end

local function applyTransparencyToSavedParts()
	if not state.Active then
		return
	end

	for part in pairs(state.SavedParts) do
		if part and part.Parent then
			applyTransparency(part)
		end
	end
end

local function disableCollision(part)
	if not part
		or not part.Parent
		or not part:IsA("BasePart") then
		return
	end

	savePart(part)

	part.CanCollide = false

	if state.Active then
		applyTransparency(part)
	end
end

local function setupNoclip()
	disconnect("NoclipDescendant")

	local character = state.Character

	if not character
		or not character.Parent then
		return
	end

	for _, object in ipairs(character:GetDescendants()) do
		disableCollision(object)
	end

	connect(
		"NoclipDescendant",
		character.DescendantAdded,
		function(object)
			if not state.Active then
				return
			end

			disableCollision(object)
		end
	)
end

local function destroyFlightObjects()
	local linearVelocity = state.LinearVelocity
	local alignOrientation = state.AlignOrientation
	local attachment = state.Attachment

	state.LinearVelocity = nil
	state.AlignOrientation = nil
	state.Attachment = nil

	if linearVelocity then
		linearVelocity:Destroy()
	end

	if alignOrientation then
		alignOrientation:Destroy()
	end

	if attachment then
		attachment:Destroy()
	end
end

local function createFlightObjects()
	local rootPart = state.RootPart

	if not rootPart
		or not rootPart.Parent
		or not rootPart:IsA("BasePart") then
		return false
	end

	destroyFlightObjects()

	local attachment
	local linearVelocity
	local alignOrientation

	local success = pcall(function()
		attachment = Instance.new("Attachment")
		attachment.Name =
			GUI_NAME .. "_Attachment"
		attachment.Parent = rootPart

		linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Name =
			GUI_NAME .. "_LinearVelocity"

		linearVelocity.Attachment0 =
			attachment

		linearVelocity.RelativeTo =
			Enum.ActuatorRelativeTo.World

		linearVelocity.VelocityConstraintMode =
			Enum.VelocityConstraintMode.Vector

		linearVelocity.ForceLimitsEnabled = false
		linearVelocity.VectorVelocity =
			Vector3.zero

		linearVelocity.Parent = rootPart

		alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Name =
			GUI_NAME .. "_AlignOrientation"

		alignOrientation.Mode =
			Enum.OrientationAlignmentMode.OneAttachment

		alignOrientation.Attachment0 =
			attachment

		alignOrientation.RigidityEnabled = false

		alignOrientation.MaxTorque =
			CONFIG.MaxTorque

		alignOrientation.MaxAngularVelocity =
			CONFIG.MaxAngularVelocity

		alignOrientation.Responsiveness =
			CONFIG.OrientationResponsiveness

		alignOrientation.CFrame =
			rootPart.CFrame

		alignOrientation.Parent = rootPart
	end)

	if not success then
		if linearVelocity then
			linearVelocity:Destroy()
		end

		if alignOrientation then
			alignOrientation:Destroy()
		end

		if attachment then
			attachment:Destroy()
		end

		return false
	end

	state.Attachment = attachment
	state.LinearVelocity = linearVelocity
	state.AlignOrientation = alignOrientation

	return true
end

local function getCameraBasis()
	local camera = workspace.CurrentCamera

	local horizontalLook

	if camera then
		local look = camera.CFrame.LookVector

		horizontalLook = Vector3.new(
			look.X,
			0,
			look.Z
		)
	end

	if not horizontalLook
		or horizontalLook.Magnitude <= 0.001 then

		horizontalLook = state.LastFacing
	end

	if horizontalLook.Magnitude <= 0.001 then
		horizontalLook =
			Vector3.new(0, 0, -1)
	end

	horizontalLook = horizontalLook.Unit

	state.LastFacing = horizontalLook

	local horizontalRight =
		horizontalLook:Cross(Vector3.yAxis)

	if horizontalRight.Magnitude <= 0.001 then
		horizontalRight =
			Vector3.new(1, 0, 0)
	else
		horizontalRight =
			horizontalRight.Unit
	end

	return horizontalLook, horizontalRight
end

local function getInputVector()
	local x = input.Right - input.Left
	local y = input.Up - input.Down
	local z = input.Forward - input.Backward

	local vector =
		Vector3.new(x, y, z)

	if vector.Magnitude > 1 then
		vector = vector.Unit
	end

	return vector
end

-- Forward declarations.
local stopFlight
local startFlight

local function updateFlight(deltaTime)
	if state.Destroying
		or not state.Active then
		return
	end

	if not isCharacterValid() then
		stopFlight(false)
		return
	end

	local rootPart = state.RootPart

	if not rootPart
		or not rootPart.Parent then
		stopFlight(false)
		return
	end

	local linearVelocity =
		state.LinearVelocity

	local alignOrientation =
		state.AlignOrientation

	if not linearVelocity
		or not linearVelocity.Parent
		or not alignOrientation
		or not alignOrientation.Parent then

		if not createFlightObjects() then
			stopFlight(false)
			return
		end

		linearVelocity =
			state.LinearVelocity

		alignOrientation =
			state.AlignOrientation
	end

	if not linearVelocity
		or not alignOrientation then
		stopFlight(false)
		return
	end

	local dt = math.clamp(
		tonumber(deltaTime) or 0,
		0,
		CONFIG.MaxDeltaTime
	)

	if dt <= 0 then
		return
	end

	local horizontalLook, horizontalRight =
		getCameraBasis()

	local movement =
		getInputVector()

	local desiredDirection =
		horizontalRight * movement.X
		+ Vector3.yAxis * movement.Y
		+ horizontalLook * movement.Z

	if desiredDirection.Magnitude > 1 then
		desiredDirection =
			desiredDirection.Unit
	end

	local targetVelocity =
		desiredDirection * state.Speed

	alignOrientation.CFrame =
		CFrame.lookAt(
			rootPart.Position,
			rootPart.Position + horizontalLook,
			Vector3.yAxis
		)

	local response

	if targetVelocity.Magnitude > 0.001 then
		response = CONFIG.Acceleration
	else
		response = CONFIG.Deceleration
	end

	local alpha =
		1 - math.exp(-response * dt)

	state.Velocity =
		state.Velocity:Lerp(
			targetVelocity,
			alpha
		)

	if state.Velocity.Magnitude < 0.01 then
		state.Velocity = Vector3.zero
	end

	linearVelocity.VectorVelocity =
		state.Velocity
end

local function unbindFlightInput()
	ContextActionService:UnbindAction(
		ACTION_FORWARD
	)

	ContextActionService:UnbindAction(
		ACTION_BACKWARD
	)

	ContextActionService:UnbindAction(
		ACTION_LEFT
	)

	ContextActionService:UnbindAction(
		ACTION_RIGHT
	)

	ContextActionService:UnbindAction(
		ACTION_UP
	)

	ContextActionService:UnbindAction(
		ACTION_DOWN
	)

	state.InputBound = false

	resetInput()
end

local function movementHandler(name)
	return function(_, inputState)
		if state.Destroying
			or not state.Active then

			return Enum.ContextActionResult.Pass
		end

		if UserInputService:GetFocusedTextBox() then
			resetInput()

			if state.LinearVelocity
				and state.LinearVelocity.Parent then

				state.LinearVelocity.VectorVelocity =
					Vector3.zero
			end

			return Enum.ContextActionResult.Pass
		end

		if inputState == Enum.UserInputState.Begin then
			input[name] = 1

		elseif inputState == Enum.UserInputState.End
			or inputState == Enum.UserInputState.Cancel then

			input[name] = 0
		end

		return Enum.ContextActionResult.Sink
	end
end

local function bindFlightInput()
	if state.InputBound
		or state.Destroying
		or not state.Active then
		return
	end

	ContextActionService:BindActionAtPriority(
		ACTION_FORWARD,
		movementHandler("Forward"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.W
	)

	ContextActionService:BindActionAtPriority(
		ACTION_BACKWARD,
		movementHandler("Backward"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.S
	)

	ContextActionService:BindActionAtPriority(
		ACTION_LEFT,
		movementHandler("Left"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.A
	)

	ContextActionService:BindActionAtPriority(
		ACTION_RIGHT,
		movementHandler("Right"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.D
	)

	ContextActionService:BindActionAtPriority(
		ACTION_UP,
		movementHandler("Up"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.E
	)

	ContextActionService:BindActionAtPriority(
		ACTION_DOWN,
		movementHandler("Down"),
		false,
		CONFIG.InputPriority,
		Enum.KeyCode.Q
	)

	state.InputBound = true
end

stopFlight = function(clearRequest)
	if clearRequest ~= false then
		state.Requested = false
	end

	state.Active = false

	disconnect("FlightSimulation")

	unbindFlightInput()

	disconnect("NoclipDescendant")

	local linearVelocity =
		state.LinearVelocity

	if linearVelocity
		and linearVelocity.Parent then

		linearVelocity.VectorVelocity =
			Vector3.zero
	end

	destroyFlightObjects()

	local humanoid =
		state.Humanoid

	if humanoid
		and humanoid.Parent then

		humanoid.AutoRotate =
			state.PreviousAutoRotate
	end

	restoreCharacterProperties()

	state.Velocity = Vector3.zero

	local rootPart =
		state.RootPart

	if rootPart
		and rootPart.Parent
		and not rootPart.Anchored then

		rootPart.AssemblyLinearVelocity =
			Vector3.zero

		rootPart.AssemblyAngularVelocity =
			Vector3.zero
	end

	updateFlyButton()
end

startFlight = function(preserveRequest)
	if state.Destroying
		or state.Active then
		return false
	end

	if not isCharacterValid() then
		if not preserveRequest then
			state.Requested = false
		end

		return false
	end

	local humanoid =
		state.Humanoid

	if not humanoid
		or humanoid.Health <= 0 then

		if not preserveRequest then
			state.Requested = false
		end

		return false
	end

	state.Requested = true
	state.Active = false
	state.Velocity = Vector3.zero

	saveCharacterProperties()

	state.PreviousAutoRotate =
		humanoid.AutoRotate

	humanoid.AutoRotate = false

	setupNoclip()

	if not createFlightObjects() then
		disconnect("NoclipDescendant")

		restoreCharacterProperties()

		if humanoid.Parent then
			humanoid.AutoRotate =
				state.PreviousAutoRotate
		end

		state.Velocity = Vector3.zero
		state.Active = false

		state.Requested =
			preserveRequest == true

		updateFlyButton()

		return false
	end

	state.Active = true

	applyTransparencyToSavedParts()

	bindFlightInput()

	connect(
		"FlightSimulation",
		RunService.PreSimulation,
		updateFlight
	)

	updateFlyButton()

	return true
end

local function toggleFlight()
	if state.Destroying then
		return
	end

	if state.Active then
		stopFlight(true)
	else
		startFlight(false)
	end
end

local function updateSpeedUI()
	local range =
		CONFIG.MaxSpeed - CONFIG.MinSpeed

	local normalized = 0

	if range > 0 then
		normalized =
			(state.Speed - CONFIG.MinSpeed)
			/ range
	end

	normalized =
		math.clamp(
			normalized,
			0,
			1
		)

	local handleWidth =
		speedHandle.AbsoluteSize.X

	local sliderWidth =
		speedSlider.AbsoluteSize.X

	local radius =
		handleWidth * 0.5

	local usableWidth =
		math.max(
			0,
			sliderWidth - handleWidth
		)

	local handleOffset =
		normalized * usableWidth

	speedBar.Size =
		UDim2.new(
			normalized,
			0,
			1,
			0
		)

	speedHandle.Position =
		UDim2.new(
			0,
			handleOffset,
			0.5,
			-radius
		)

	speedLabel.Text =
		string.format(
			"Speed: %d",
			math.round(state.Speed)
		)
end

local speedDragging = false

local function updateSpeedFromMouse()
	local sliderWidth =
		speedSlider.AbsoluteSize.X

	local handleWidth =
		speedHandle.AbsoluteSize.X

	local usableWidth =
		sliderWidth - handleWidth

	if usableWidth <= 0 then
		return
	end

	local mouseX =
		UserInputService:GetMouseLocation().X

	local localX =
		mouseX
		- speedSlider.AbsolutePosition.X

	local handleRadius =
		handleWidth * 0.5

	local percentage =
		(localX - handleRadius)
		/ usableWidth

	percentage =
		math.clamp(
			percentage,
			0,
			1
		)

	state.Speed =
		CONFIG.MinSpeed
		+
		(
			CONFIG.MaxSpeed
			- CONFIG.MinSpeed
		)
		* percentage

	updateSpeedUI()
end

connect(
	"SpeedHandleBegin",
	speedHandle.InputBegan,
	function(inputObject)
		if inputObject.UserInputType
			== Enum.UserInputType.MouseButton1 then

			speedDragging = true
			updateSpeedFromMouse()
		end
	end
)

connect(
	"SpeedSliderBegin",
	speedSlider.InputBegan,
	function(inputObject)
		if inputObject.UserInputType
			== Enum.UserInputType.MouseButton1 then

			speedDragging = true
			updateSpeedFromMouse()
		end
	end
)

connect(
	"SpeedMouseMove",
	UserInputService.InputChanged,
	function(inputObject)
		if not speedDragging then
			return
		end

		if inputObject.UserInputType
			== Enum.UserInputType.MouseMovement then

			updateSpeedFromMouse()
		end
	end
)

connect(
	"SpeedMouseEnd",
	UserInputService.InputEnded,
	function(inputObject)
		if inputObject.UserInputType
			== Enum.UserInputType.MouseButton1 then

			speedDragging = false
		end
	end
)

connect(
	"TransparencyFocusLost",
	transparencyBox.FocusLost,
	function()
		local text =
			string.gsub(
				transparencyBox.Text,
				",",
				"."
			)

		local value = tonumber(text)

		if value == nil then
			transparencyBox.Text =
				tostring(state.Transparency)

			return
		end

		state.Transparency =
			math.clamp(
				value,
				0,
				1
			)

		transparencyBox.Text =
			tostring(state.Transparency)

		applyTransparencyToSavedParts()
	end
)

local draggingGUI = false
local dragStart = nil
local startPosition = nil

local function clampGUIPosition(position)
	local camera =
		workspace.CurrentCamera

	if not camera then
		return position
	end

	local viewport =
		camera.ViewportSize

	local frameSize =
		mainFrame.AbsoluteSize

	local margin =
		CONFIG.GUI_MARGIN

	local absoluteX =
		position.X.Scale * viewport.X
		+ position.X.Offset

	local absoluteY =
		position.Y.Scale * viewport.Y
		+ position.Y.Offset

	local maxX =
		math.max(
			margin,
			viewport.X
				- frameSize.X
				- margin
		)

	local maxY =
		math.max(
			margin,
			viewport.Y
				- frameSize.Y
				- margin
		)

	absoluteX =
		math.clamp(
			absoluteX,
			margin,
			maxX
		)

	absoluteY =
		math.clamp(
			absoluteY,
			margin,
			maxY
		)

	return UDim2.fromOffset(
		absoluteX,
		absoluteY
	)
end

connect(
	"DragBegin",
	dragArea.InputBegan,
	function(inputObject)
		if inputObject.UserInputType
			== Enum.UserInputType.MouseButton1 then

			draggingGUI = true
			dragStart = inputObject.Position
			startPosition = mainFrame.Position
		end
	end
)

connect(
	"DragChanged",
	UserInputService.InputChanged,
	function(inputObject)
		if not draggingGUI then
			return
		end

		if inputObject.UserInputType
			~= Enum.UserInputType.MouseMovement then
			return
		end

		if not dragStart
			or not startPosition then
			return
		end

		local delta =
			inputObject.Position - dragStart

		local newPosition =
			UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)

		mainFrame.Position =
			clampGUIPosition(
				newPosition
			)
	end
)

connect(
	"DragEnded",
	UserInputService.InputEnded,
	function(inputObject)
		if inputObject.UserInputType
			== Enum.UserInputType.MouseButton1 then

			draggingGUI = false
			dragStart = nil
			startPosition = nil
		end
	end
)

local function clearTransientUIInput()
	speedDragging = false

	draggingGUI = false
	dragStart = nil
	startPosition = nil
end

connect(
	"TextBoxFocused",
	UserInputService.TextBoxFocused,
	function()
		resetInput()

		if state.LinearVelocity
			and state.LinearVelocity.Parent then

			state.LinearVelocity.VectorVelocity =
				Vector3.zero
		end
	end
)

connect(
	"TextBoxFocusReleased",
	UserInputService.TextBoxFocusReleased,
	function()
		resetInput()
	end
)

connect(
	"WindowFocusReleased",
	UserInputService.WindowFocusReleased,
	function()
		resetInput()
		clearTransientUIInput()

		if state.Active
			and state.LinearVelocity
			and state.LinearVelocity.Parent then

			state.LinearVelocity.VectorVelocity =
				Vector3.zero
		end
	end
)

local function bindCharacterEvents()
	disconnect("HumanoidDied")
	disconnect("HumanoidAncestry")
	disconnect("RootAncestry")

	local humanoid =
		state.Humanoid

	local rootPart =
		state.RootPart

	if humanoid then
		connect(
			"HumanoidDied",
			humanoid.Died,
			function()
				if state.Destroying then
					return
				end

				if state.Active then
					stopFlight(false)
				else
					resetInput()
				end
			end
		)

		connect(
			"HumanoidAncestry",
			humanoid.AncestryChanged,
			function(_, parent)
				if parent == nil
					and not state.Destroying then

					if state.Active then
						stopFlight(false)
					else
						resetInput()
					end
				end
			end
		)
	end

	if rootPart then
		connect(
			"RootAncestry",
			rootPart.AncestryChanged,
			function(_, parent)
				if parent == nil
					and not state.Destroying then

					if state.Active then
						stopFlight(false)
					else
						resetInput()
					end
				end
			end
		)
	end
end

local function prepareCharacter(newCharacter)
	state.CharacterToken += 1

	local token =
		state.CharacterToken

	local shouldResume =
		state.Requested

	stopFlight(false)
	resetInput()

	disconnect("HumanoidDied")
	disconnect("HumanoidAncestry")
	disconnect("RootAncestry")

	state.Character = nil
	state.Humanoid = nil
	state.RootPart = nil

	table.clear(state.SavedParts)

	return token, shouldResume
end

local function tryLoadCharacter(
	character,
	token,
	shouldResume
)
	for attempt = 1, CONFIG.CharacterRetryCount do
		if state.Destroying then
			return
		end

		if token ~= state.CharacterToken then
			return
		end

		if player.Character ~= character then
			return
		end

		local timeout

		if attempt == 1 then
			timeout =
				CONFIG.CharacterLoadTimeout
		else
			timeout = math.min(
				CONFIG.CharacterLoadTimeout,
				3
			)
		end

		if loadCharacter(
			character,
			timeout
		) then

			bindCharacterEvents()

			task.defer(function()
				if state.Destroying then
					return
				end

				if token ~= state.CharacterToken then
					return
				end

				if state.Character ~= character then
					return
				end

				if shouldResume
					and state.Requested then

					startFlight(true)
				else
					updateFlyButton()
				end
			end)

			return
		end

		if attempt < CONFIG.CharacterRetryCount then
			task.wait(
				CONFIG.CharacterRetryDelay
			)
		end
	end

	if token == state.CharacterToken then
		state.Requested =
			shouldResume

		updateFlyButton()
	end
end

connect(
	"CharacterAdded",
	player.CharacterAdded,
	function(newCharacter)
		if state.Destroying then
			return
		end

		local token, shouldResume =
			prepareCharacter(
				newCharacter
			)

		task.spawn(function()
			tryLoadCharacter(
				newCharacter,
				token,
				shouldResume
			)
		end)
	end
)

connect(
	"CharacterRemoving",
	player.CharacterRemoving,
	function(character)
		if state.Destroying then
			return
		end

		if character ~= state.Character then
			return
		end

		state.CharacterToken += 1

		stopFlight(false)
		resetInput()

		disconnect("HumanoidDied")
		disconnect("HumanoidAncestry")
		disconnect("RootAncestry")

		state.Character = nil
		state.Humanoid = nil
		state.RootPart = nil

		table.clear(state.SavedParts)
	end
)

-- Souris uniquement pour l'interface.
connect(
	"FlyButton",
	flyButton.MouseButton1Click,
	function()
		toggleFlight()
	end
)

local minimized = false
local minimizeTween = nil

connect(
	"Minimize",
	minimizeButton.MouseButton1Click,
	function()
		if state.Destroying then
			return
		end

		state.UIToken += 1

		local token =
			state.UIToken

		minimized = not minimized

		local targetSize

		if minimized then
			targetSize =
				UDim2.fromOffset(
					CONFIG.GUIWidth,
					42
				)
		else
			targetSize =
				UDim2.fromOffset(
					CONFIG.GUIWidth,
					CONFIG.GUIHeight
				)

			body.Visible = true
		end

		if minimizeTween then
			minimizeTween:Cancel()
			minimizeTween = nil
		end

		minimizeTween =
			TweenService:Create(
				mainFrame,
				TweenInfo.new(
					0.2,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					Size = targetSize,
				}
			)

		minimizeTween:Play()

		if minimized then
			task.delay(
				0.2,
				function()
					if state.Destroying then
						return
					end

					if state.UIToken ~= token then
						return
					end

					if minimized then
						body.Visible = false
					end
				end
			)
		end
	end
)

local function destroy()
	if state.Destroying then
		return
	end

	state.Destroying = true

	state.CharacterToken += 1
	state.UIToken += 1

	state.Requested = false

	resetInput()
	clearTransientUIInput()

	stopFlight(true)

	disconnectAll()

	restoreCharacterProperties()
	destroyFlightObjects()

	state.Character = nil
	state.Humanoid = nil
	state.RootPart = nil

	table.clear(state.SavedParts)

	if minimizeTween then
		minimizeTween:Cancel()
		minimizeTween = nil
	end

	if screenGui then
		screenGui:Destroy()
	end
end

connect(
	"Close",
	closeButton.MouseButton1Click,
	destroy
)

local function clampCurrentGUIPosition()
	if state.Destroying then
		return
	end

	if not screenGui.Parent then
		return
	end

	mainFrame.Position =
		clampGUIPosition(
			mainFrame.Position
		)
end

local function bindViewport()
	disconnect("ViewportChanged")

	local camera =
		workspace.CurrentCamera

	if not camera then
		return
	end

	connect(
		"ViewportChanged",
		camera:GetPropertyChangedSignal(
			"ViewportSize"
		),
		clampCurrentGUIPosition
	)
end

connect(
	"CurrentCameraChanged",
	workspace:GetPropertyChangedSignal(
		"CurrentCamera"
	),
	function()
		bindViewport()
		clampCurrentGUIPosition()
	end
)

bindViewport()

local initialCharacter =
	player.Character

if not initialCharacter then
	initialCharacter =
		player.CharacterAdded:Wait()
end

if state.Destroying then
	return
end

if not loadCharacter(
	initialCharacter,
	CONFIG.CharacterLoadTimeout
) then

	local loaded = false

	for attempt = 1,
		CONFIG.CharacterRetryCount do

		if state.Destroying then
			return
		end

		task.wait(
			CONFIG.CharacterRetryDelay
		)

		if player.Character ~= initialCharacter then
			break
		end

		if loadCharacter(
			initialCharacter,
			math.min(
				CONFIG.CharacterLoadTimeout,
				3
			)
		) then

			loaded = true
			break
		end
	end

	if not loaded then
		destroy()
		return
	end
end

bindCharacterEvents()

mainFrame.Position =
	clampGUIPosition(
		mainFrame.Position
	)

updateSpeedUI()
updateFlyButton()
