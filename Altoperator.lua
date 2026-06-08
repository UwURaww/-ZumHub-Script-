local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local quickTabGui = nil
local settingsGui = nil
local quickTabVisible = false
local settingsVisible = false
local viewConnection = nil
local viewingRobot = false
local savedCameraMode = nil
local useWhisper = true
local robotName = ""
local loopConnection = nil
local loopCmd = nil
local pingConnection = nil
local COOLDOWN = 0.8
local lastSent = 0
local guiWidth = 280
local guiHeight = 440
local statusDotRef = nil

local SAVE_KEY = "RobotOperatorName"

local function saveRobotName(name)
	pcall(function()
		game:GetService("RunService"):SetAttribute(SAVE_KEY, name)
	end)
	localPlayer:SetAttribute(SAVE_KEY, name)
end

local function loadRobotName()
	local v = localPlayer:GetAttribute(SAVE_KEY)
	if v and v ~= "" then return v end
	return ""
end

robotName = loadRobotName()

local function sendWhisper(message)
	game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
		Text = "[Operator] " .. message,
		Color = Color3.fromRGB(255, 180, 80),
		FontSize = Enum.FontSize.Size18,
	})
end

local function sendCommand(cmd)
	local now = tick()
	if now - lastSent < COOLDOWN then return end
	lastSent = now
	local channel = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if not channel then return end
	if useWhisper and robotName ~= "" then
		channel:SendAsync("/w " .. robotName .. " " .. cmd)
	else
		channel:SendAsync(cmd)
	end
end

local function startLoop(cmd)
	if loopConnection then loopConnection:Disconnect() loopConnection = nil end
	loopCmd = cmd
	loopConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastSent >= COOLDOWN then
			lastSent = now
			local channel = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
			if not channel then return end
			if useWhisper and robotName ~= "" then
				channel:SendAsync("/w " .. robotName .. " " .. loopCmd)
			else
				channel:SendAsync(loopCmd)
			end
		end
	end)
	sendWhisper("Looping: " .. cmd)
end

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection = nil end
	loopCmd = nil
	sendWhisper("Loop stopped.")
end

local function startView()
	if robotName == "" then sendWhisper("Set robot name first!") return end
	local robot = Players:FindFirstChild(robotName)
	if not robot or not robot.Character then sendWhisper("Robot not found.") return end
	local cam = game:GetService("Workspace").CurrentCamera
	savedCameraMode = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	viewingRobot = true
	viewConnection = RunService.Heartbeat:Connect(function()
		if not viewingRobot then return end
		local r = Players:FindFirstChild(robotName)
		if not r or not r.Character then return end
		local rp = r.Character:FindFirstChild("HumanoidRootPart")
		if not rp then return end
		cam.CFrame = CFrame.new(rp.Position + Vector3.new(0, 8, 14), rp.Position)
	end)
end

local function stopView()
	viewingRobot = false
	if viewConnection then viewConnection:Disconnect() viewConnection = nil end
	local cam = game:GetService("Workspace").CurrentCamera
	cam.CameraType = savedCameraMode or Enum.CameraType.Custom
end

local function updateStatusDot()
	if not statusDotRef then return end
	local robot = robotName ~= "" and Players:FindFirstChild(robotName)
	local connected = robot ~= nil and robot.Character ~= nil
	statusDotRef.BackgroundColor3 = connected and Color3.fromRGB(20, 80, 30) or Color3.fromRGB(80, 20, 20)
	statusDotRef.Text = connected and "● CONNECTED" or "● OFFLINE"
	statusDotRef.TextColor3 = connected and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
end

local toggleStates = {}

local COMMANDS = {
	{label = ".follow me", cmd = ".follow me"},
	{label = ".stop", cmd = ".stop"},
	{label = ".sit", cmd = ".sit"},
	{label = ".stand", cmd = ".stand"},
	{label = ".jump", cmd = ".jump"},
	{label = ".reset", cmd = ".reset"},
	{label = ".fling", cmd = ".fling"},
	{label = ".wave", cmd = ".e wave"},
	{label = ".laugh", cmd = ".e laugh"},
	{label = ".cheer", cmd = ".e cheer"},
	{label = ".point", cmd = ".e point"},
	{label = ".dance", cmd = ".e dance"},
	{label = ".dance2", cmd = ".e dance2"},
	{label = ".dance3", cmd = ".e dance3"},
	{label = ".gravityoff", cmd = ".gravityoff"},
	{label = ".gravityreset", cmd = ".gravityreset"},
	{label = ".tpme", cmd = ".tpme"},
	{label = ".savepos", cmd = ".savepos"},
	{label = ".loadpos", cmd = ".loadpos"},
	{label = ".health", cmd = ".health"},
	{label = ".pos", cmd = ".pos"},
	{label = ".rig", cmd = ".rig"},
	{label = ".loopstop", cmd = ".loopstop"},
	{label = ".status", cmd = ".status"},
	{label = "noclip", toggle = true, on = ".noclip on", off = ".noclip off"},
	{label = "invisible", toggle = true, on = ".invisible on", off = ".invisible off"},
	{label = "godmode", toggle = true, on = ".godmode on", off = ".godmode off"},
	{label = "spin", toggle = true, on = ".spin on", off = ".spin off"},
	{label = "float", toggle = true, on = ".float on", off = ".float off"},
	{label = "bighead", toggle = true, on = ".bighead on", off = ".bighead off"},
	{label = "freeze", toggle = true, on = ".freeze", off = ".unfreeze"},
	{label = "crouch", toggle = true, on = ".crouch on", off = ".crouch off"},
	{label = "lockcontrol", toggle = true, on = ".lockcontrol on", off = ".lockcontrol off"},
	{label = "mirror", toggle = true, on = ".mirror on", off = ".mirror off"},
	{label = ".fw [n]", cmd = nil, input = true, base = ".fw"},
	{label = ".bw [n]", cmd = nil, input = true, base = ".bw"},
	{label = ".l [n]", cmd = nil, input = true, base = ".l"},
	{label = ".r [n]", cmd = nil, input = true, base = ".r"},
	{label = ".tl [deg]", cmd = nil, input = true, base = ".tl"},
	{label = ".tr [deg]", cmd = nil, input = true, base = ".tr"},
	{label = ".follow [n]", cmd = nil, input = true, base = ".follow"},
	{label = ".orbit [n]", cmd = nil, input = true, base = ".orbit"},
	{label = ".goto [n]", cmd = nil, input = true, base = ".goto"},
	{label = ".looptp [n]", cmd = nil, input = true, base = ".looptp"},
	{label = ".lookat [n]", cmd = nil, input = true, base = ".lookat"},
	{label = ".tp [n]", cmd = nil, input = true, base = ".tp"},
	{label = ".say [txt]", cmd = nil, input = true, base = ".say"},
	{label = ".e [name]", cmd = nil, input = true, base = ".e"},
	{label = ".patrol [n1 n2]", cmd = nil, input = true, base = ".patrol"},
	{label = ".gravity [n]", cmd = nil, input = true, base = ".gravity"},
	{label = ".transparency [n]", cmd = nil, input = true, base = ".transparency"},
	{label = ".size [n]", cmd = nil, input = true, base = ".size"},
	{label = ".loop [cmd]", cmd = nil, input = true, base = ".loop"},
}

local stepPresets = {5, 10, 20, 50}

local loopLabelRef = nil

local function createSettingsGui()
	if settingsGui then settingsGui:Destroy() settingsGui = nil end
	if not settingsVisible then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "SettingsPanel"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = localPlayer.PlayerGui

	local panelW = 240
	local panelH = 480

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, panelW, 0, panelH)
	panel.Position = UDim2.new(1, -(guiWidth + panelW + 24), 0.5, -(panelH / 2))
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Draggable = true
	panel.Parent = sg

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 10)
	pc.Parent = panel

	local ps = Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(100, 100, 160)
	ps.Thickness = 1.5
	ps.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 28)
	titleBar.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel
	local tbc = Instance.new("UICorner")
	tbc.CornerRadius = UDim.new(0, 10)
	tbc.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -36, 1, 0)
	titleLbl.Position = UDim2.new(0, 10, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "⚙ SETTINGS"
	titleLbl.TextColor3 = Color3.fromRGB(160, 160, 220)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = titleBar

	local closeS = Instance.new("TextButton")
	closeS.Size = UDim2.new(0, 22, 0, 22)
	closeS.Position = UDim2.new(1, -26, 0, 3)
	closeS.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	closeS.Text = "X"
	closeS.TextColor3 = Color3.fromRGB(255,255,255)
	closeS.TextScaled = true
	closeS.Font = Enum.Font.GothamBold
	closeS.BorderSizePixel = 0
	closeS.Parent = titleBar
	local csc = Instance.new("UICorner")
	csc.CornerRadius = UDim.new(0, 4)
	csc.Parent = closeS
	closeS.MouseButton1Click:Connect(function()
		settingsVisible = false
		if pingConnection then pingConnection:Disconnect() pingConnection = nil end
		sg:Destroy()
		settingsGui = nil
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -8, 1, -34)
	scroll.Position = UDim2.new(0, 4, 0, 30)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 160)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local lpad = Instance.new("UIPadding")
	lpad.PaddingTop = UDim.new(0, 6)
	lpad.PaddingLeft = UDim.new(0, 6)
	lpad.PaddingRight = UDim.new(0, 6)
	lpad.Parent = scroll

	local sw = panelW - 24

	local function sectionLabel(text)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, sw, 0, 16)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = Color3.fromRGB(120, 120, 180)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = scroll
	end

	local function makeBox(placeholder, default)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0, sw, 0, 26)
		box.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
		box.TextColor3 = Color3.fromRGB(220, 220, 255)
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(80, 80, 110)
		box.Text = default or ""
		box.TextScaled = true
		box.Font = Enum.Font.Gotham
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = box
		local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(60,60,100) bs.Thickness = 1 bs.Parent = box
		return box
	end

	local function makeSettBtn(text, color, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, sw, 0, 26)
		btn.BackgroundColor3 = color
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.BorderSizePixel = 0
		btn.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = btn
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	local function makeSettToggle(text, initState, onColor, offColor, callback)
		local state = initState
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, sw, 0, 26)
		btn.BackgroundColor3 = state and onColor or offColor
		btn.Text = text .. (state and ": ON" or ": OFF")
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.BorderSizePixel = 0
		btn.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = btn
		btn.MouseButton1Click:Connect(function()
			state = not state
			btn.BackgroundColor3 = state and onColor or offColor
			btn.Text = text .. (state and ": ON" or ": OFF")
			callback(state)
		end)
		return btn
	end

	local statusDot = Instance.new("TextLabel")
	statusDot.Size = UDim2.new(0, sw, 0, 26)
	statusDot.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
	statusDot.Text = "● OFFLINE"
	statusDot.TextColor3 = Color3.fromRGB(255, 80, 80)
	statusDot.TextScaled = true
	statusDot.Font = Enum.Font.GothamBold
	statusDot.BorderSizePixel = 0
	statusDot.Parent = scroll
	local sdc = Instance.new("UICorner") sdc.CornerRadius = UDim.new(0,5) sdc.Parent = statusDot
	statusDotRef = statusDot
	updateStatusDot()

	sectionLabel("Robot Username")
	local robotBox = makeBox("robot username...", robotName)
	robotBox:GetPropertyChangedSignal("Text"):Connect(function()
		robotName = robotBox.Text
		saveRobotName(robotName)
		updateStatusDot()
	end)

	sectionLabel("Communication")
	makeSettToggle("Whisper", useWhisper, Color3.fromRGB(30,120,60), Color3.fromRGB(120,40,40), function(state)
		useWhisper = state
		sendWhisper("Whisper: " .. (state and "ON" or "OFF"))
	end)

	sectionLabel("View Robot Camera")
	makeSettToggle("View Robot", false, Color3.fromRGB(40,80,160), Color3.fromRGB(40,50,80), function(state)
		if state then startView() else stopView() end
	end)

	sectionLabel("Command Cooldown (s)")
	local coolBox = makeBox("0.8", tostring(COOLDOWN))
	makeSettBtn("Apply Cooldown", Color3.fromRGB(50,50,90), function()
		local v = tonumber(coolBox.Text)
		if v and v >= 0.3 then
			COOLDOWN = v
			sendWhisper("Cooldown: " .. v .. "s")
		else
			sendWhisper("Min cooldown: 0.3s")
		end
	end)

	sectionLabel("GUI Size Presets")
	local sizesFrame = Instance.new("Frame")
	sizesFrame.Size = UDim2.new(0, sw, 0, 26)
	sizesFrame.BackgroundTransparency = 1
	sizesFrame.Parent = scroll
	local sizePresets = {{"S", 220, 380}, {"M", 280, 440}, {"L", 360, 520}, {"XL", 420, 580}}
	local sBtnW = math.floor(sw / #sizePresets) - 3
	for i, s in ipairs(sizePresets) do
		local sb = Instance.new("TextButton")
		sb.Size = UDim2.new(0, sBtnW, 0, 26)
		sb.Position = UDim2.new(0, (i-1)*(sBtnW+3), 0, 0)
		sb.BackgroundColor3 = (guiWidth == s[2]) and Color3.fromRGB(80,80,40) or Color3.fromRGB(40,40,60)
		sb.Text = s[1]
		sb.TextColor3 = Color3.fromRGB(220,220,255)
		sb.TextScaled = true
		sb.Font = Enum.Font.GothamBold
		sb.BorderSizePixel = 0
		sb.Parent = sizesFrame
		local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0,4) sc.Parent = sb
		sb.MouseButton1Click:Connect(function()
			guiWidth = s[2] guiHeight = s[3]
			createQuickTab()
		end)
	end

	sectionLabel("Custom GUI Size")
	local customFrame = Instance.new("Frame")
	customFrame.Size = UDim2.new(0, sw, 0, 26)
	customFrame.BackgroundTransparency = 1
	customFrame.Parent = scroll
	local hw = math.floor(sw / 2) - 2
	local wBox = Instance.new("TextBox")
	wBox.Size = UDim2.new(0, hw, 0, 26)
	wBox.BackgroundColor3 = Color3.fromRGB(20,20,32)
	wBox.TextColor3 = Color3.fromRGB(220,220,255)
	wBox.PlaceholderText = "width"
	wBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
	wBox.Text = tostring(guiWidth)
	wBox.TextScaled = true
	wBox.Font = Enum.Font.Gotham
	wBox.BorderSizePixel = 0
	wBox.ClearTextOnFocus = false
	wBox.Parent = customFrame
	local wc = Instance.new("UICorner") wc.CornerRadius = UDim.new(0,5) wc.Parent = wBox
	local hBox = Instance.new("TextBox")
	hBox.Size = UDim2.new(0, hw, 0, 26)
	hBox.Position = UDim2.new(0, hw+4, 0, 0)
	hBox.BackgroundColor3 = Color3.fromRGB(20,20,32)
	hBox.TextColor3 = Color3.fromRGB(220,220,255)
	hBox.PlaceholderText = "height"
	hBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
	hBox.Text = tostring(guiHeight)
	hBox.TextScaled = true
	hBox.Font = Enum.Font.Gotham
	hBox.BorderSizePixel = 0
	hBox.ClearTextOnFocus = false
	hBox.Parent = customFrame
	local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0,5) hc.Parent = hBox
	makeSettBtn("Apply Custom Size", Color3.fromRGB(60,60,100), function()
		local w = tonumber(wBox.Text)
		local h = tonumber(hBox.Text)
		if w and h and w >= 180 and h >= 300 then
			guiWidth = w guiHeight = h
			createQuickTab()
		else
			sendWhisper("Min: 180 wide, 300 tall.")
		end
	end)

	pingConnection = RunService.Heartbeat:Connect(function()
		updateStatusDot()
	end)

	settingsGui = sg
end

local function createQuickTab()
	if quickTabGui then quickTabGui:Destroy() end
	toggleStates = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuickTab"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, guiWidth, 0, guiHeight)
	frame.Position = UDim2.new(1, -(guiWidth + 15), 0.5, -(guiHeight / 2))
	frame.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 180, 80)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 28)
	titleBar.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = frame
	local tbc2 = Instance.new("UICorner")
	tbc2.CornerRadius = UDim.new(0, 10)
	tbc2.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -60, 1, 0)
	titleLbl.Position = UDim2.new(0, 10, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "QUICK TAB"
	titleLbl.TextColor3 = Color3.fromRGB(255, 180, 80)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = titleBar

	local cogBtn = Instance.new("TextButton")
	cogBtn.Size = UDim2.new(0, 24, 0, 24)
	cogBtn.Position = UDim2.new(1, -52, 0, 2)
	cogBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	cogBtn.Text = "⚙"
	cogBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
	cogBtn.TextScaled = true
	cogBtn.Font = Enum.Font.GothamBold
	cogBtn.BorderSizePixel = 0
	cogBtn.Parent = titleBar
	local cogC = Instance.new("UICorner") cogC.CornerRadius = UDim.new(0,4) cogC.Parent = cogBtn
	cogBtn.MouseButton1Click:Connect(function()
		settingsVisible = not settingsVisible
		cogBtn.BackgroundColor3 = settingsVisible and Color3.fromRGB(80,80,40) or Color3.fromRGB(40,40,60)
		cogBtn.TextColor3 = settingsVisible and Color3.fromRGB(255,200,80) or Color3.fromRGB(180,180,220)
		createSettingsGui()
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -26, 0, 2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,4) cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		if settingsGui then settingsGui:Destroy() settingsGui = nil end
		if pingConnection then pingConnection:Disconnect() pingConnection = nil end
		quickTabGui:Destroy()
		quickTabGui = nil
		quickTabVisible = false
		settingsVisible = false
	end)

	local innerSw = guiWidth - 16
	local yOff = 34

	local argInput = Instance.new("TextBox")
	argInput.Size = UDim2.new(0, innerSw, 0, 22)
	argInput.Position = UDim2.new(0, 8, 0, yOff)
	argInput.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	argInput.TextColor3 = Color3.fromRGB(220, 220, 255)
	argInput.PlaceholderText = "argument / name / text..."
	argInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 110)
	argInput.Text = ""
	argInput.TextScaled = true
	argInput.Font = Enum.Font.Gotham
	argInput.BorderSizePixel = 0
	argInput.ClearTextOnFocus = false
	argInput.Parent = frame
	local aic = Instance.new("UICorner") aic.CornerRadius = UDim.new(0,5) aic.Parent = argInput
	local ais = Instance.new("UIStroke") ais.Color = Color3.fromRGB(60,60,100) ais.Thickness = 1 ais.Parent = argInput
	yOff = yOff + 26

	local hw2 = math.floor(innerSw/2) - 2

	local speedInput = Instance.new("TextBox")
	speedInput.Size = UDim2.new(0, hw2, 0, 22)
	speedInput.Position = UDim2.new(0, 8, 0, yOff)
	speedInput.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	speedInput.TextColor3 = Color3.fromRGB(220, 220, 255)
	speedInput.PlaceholderText = "speed..."
	speedInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 110)
	speedInput.Text = ""
	speedInput.TextScaled = true
	speedInput.Font = Enum.Font.Gotham
	speedInput.BorderSizePixel = 0
	speedInput.ClearTextOnFocus = false
	speedInput.Parent = frame
	local sic = Instance.new("UICorner") sic.CornerRadius = UDim.new(0,5) sic.Parent = speedInput

	local speedSendBtn = Instance.new("TextButton")
	speedSendBtn.Size = UDim2.new(0, hw2, 0, 22)
	speedSendBtn.Position = UDim2.new(0, 8+hw2+4, 0, yOff)
	speedSendBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
	speedSendBtn.Text = "Set Speed"
	speedSendBtn.TextColor3 = Color3.fromRGB(255,255,255)
	speedSendBtn.TextScaled = true
	speedSendBtn.Font = Enum.Font.GothamBold
	speedSendBtn.BorderSizePixel = 0
	speedSendBtn.Parent = frame
	local ssbc = Instance.new("UICorner") ssbc.CornerRadius = UDim.new(0,5) ssbc.Parent = speedSendBtn
	speedSendBtn.MouseButton1Click:Connect(function()
		local v = tonumber(speedInput.Text)
		if v then sendCommand(".speed " .. v) sendWhisper("Speed: " .. v)
		else sendWhisper("Enter a valid number!") end
	end)
	yOff = yOff + 26

	local jumpInput = Instance.new("TextBox")
	jumpInput.Size = UDim2.new(0, hw2, 0, 22)
	jumpInput.Position = UDim2.new(0, 8, 0, yOff)
	jumpInput.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	jumpInput.TextColor3 = Color3.fromRGB(220, 220, 255)
	jumpInput.PlaceholderText = "jump power..."
	jumpInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 110)
	jumpInput.Text = ""
	jumpInput.TextScaled = true
	jumpInput.Font = Enum.Font.Gotham
	jumpInput.BorderSizePixel = 0
	jumpInput.ClearTextOnFocus = false
	jumpInput.Parent = frame
	local jic = Instance.new("UICorner") jic.CornerRadius = UDim.new(0,5) jic.Parent = jumpInput

	local jumpSendBtn = Instance.new("TextButton")
	jumpSendBtn.Size = UDim2.new(0, hw2, 0, 22)
	jumpSendBtn.Position = UDim2.new(0, 8+hw2+4, 0, yOff)
	jumpSendBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
	jumpSendBtn.Text = "Set Jump"
	jumpSendBtn.TextColor3 = Color3.fromRGB(255,255,255)
	jumpSendBtn.TextScaled = true
	jumpSendBtn.Font = Enum.Font.GothamBold
	jumpSendBtn.BorderSizePixel = 0
	jumpSendBtn.Parent = frame
	local jsbc = Instance.new("UICorner") jsbc.CornerRadius = UDim.new(0,5) jsbc.Parent = jumpSendBtn
	jumpSendBtn.MouseButton1Click:Connect(function()
		local v = tonumber(jumpInput.Text)
		if v then sendCommand(".jumppower " .. v) sendWhisper("JumpPower: " .. v)
		else sendWhisper("Enter a valid number!") end
	end)
	yOff = yOff + 26

	local stepFrame = Instance.new("Frame")
	stepFrame.Size = UDim2.new(0, innerSw, 0, 20)
	stepFrame.Position = UDim2.new(0, 8, 0, yOff)
	stepFrame.BackgroundTransparency = 1
	stepFrame.Parent = frame
	local stepLbl = Instance.new("TextLabel")
	stepLbl.Size = UDim2.new(0, 32, 1, 0)
	stepLbl.BackgroundTransparency = 1
	stepLbl.Text = "Stp:"
	stepLbl.TextColor3 = Color3.fromRGB(150,150,180)
	stepLbl.TextScaled = true
	stepLbl.Font = Enum.Font.Gotham
	stepLbl.TextXAlignment = Enum.TextXAlignment.Left
	stepLbl.Parent = stepFrame
	local availW = innerSw - 36
	local btnW2 = math.floor(availW / #stepPresets) - 2
	for i, val in ipairs(stepPresets) do
		local pb = Instance.new("TextButton")
		pb.Size = UDim2.new(0, btnW2, 1, 0)
		pb.Position = UDim2.new(0, 34+(i-1)*(btnW2+2), 0, 0)
		pb.BackgroundColor3 = Color3.fromRGB(35,35,55)
		pb.TextColor3 = Color3.fromRGB(200,200,240)
		pb.Text = tostring(val)
		pb.TextScaled = true
		pb.Font = Enum.Font.Gotham
		pb.BorderSizePixel = 0
		pb.Parent = stepFrame
		local pc2 = Instance.new("UICorner") pc2.CornerRadius = UDim.new(0,3) pc2.Parent = pb
		pb.MouseButton1Click:Connect(function()
			sendCommand(".fw " .. val)
			sendWhisper("Step: " .. val)
		end)
	end
	yOff = yOff + 24

	local loopFrame = Instance.new("Frame")
	loopFrame.Size = UDim2.new(0, innerSw, 0, 20)
	loopFrame.Position = UDim2.new(0, 8, 0, yOff)
	loopFrame.BackgroundTransparency = 1
	loopFrame.Parent = frame

	local loopLabel = Instance.new("TextLabel")
	loopLabel.Size = UDim2.new(1, -68, 1, 0)
	loopLabel.BackgroundTransparency = 1
	loopLabel.Text = loopCmd and ("⟳ " .. loopCmd) or "⟳ No loop"
	loopLabel.TextColor3 = loopCmd and Color3.fromRGB(255,120,120) or Color3.fromRGB(120,120,150)
	loopLabel.TextScaled = true
	loopLabel.Font = Enum.Font.Gotham
	loopLabel.TextXAlignment = Enum.TextXAlignment.Left
	loopLabel.Parent = loopFrame
	loopLabelRef = loopLabel

	local stopLoopBtn = Instance.new("TextButton")
	stopLoopBtn.Size = UDim2.new(0, 64, 1, 0)
	stopLoopBtn.Position = UDim2.new(1, -64, 0, 0)
	stopLoopBtn.BackgroundColor3 = Color3.fromRGB(140,40,40)
	stopLoopBtn.Text = "Stop Loop"
	stopLoopBtn.TextColor3 = Color3.fromRGB(255,255,255)
	stopLoopBtn.TextScaled = true
	stopLoopBtn.Font = Enum.Font.Gotham
	stopLoopBtn.BorderSizePixel = 0
	stopLoopBtn.Parent = loopFrame
	local slc = Instance.new("UICorner") slc.CornerRadius = UDim.new(0,4) slc.Parent = stopLoopBtn
	stopLoopBtn.MouseButton1Click:Connect(function()
		stopLoop()
		loopLabel.Text = "⟳ No loop"
		loopLabel.TextColor3 = Color3.fromRGB(120,120,150)
	end)
	yOff = yOff + 24

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0, innerSw, 0, 1)
	divider.Position = UDim2.new(0, 8, 0, yOff)
	divider.BackgroundColor3 = Color3.fromRGB(255,180,80)
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = frame
	yOff = yOff + 5

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(0, innerSw, 1, -(yOff+4))
	scrollFrame.Position = UDim2.new(0, 8, 0, yOff+2)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255,180,80)
	scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local cellW = math.floor((innerSw-6)/3)

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, cellW, 0, 26)
	layout.CellPadding = UDim2.new(0, 3, 0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 0)
	pad.Parent = scrollFrame

	for i, data in ipairs(COMMANDS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, cellW, 0, 26)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.TextScaled = true
		btn.Font = Enum.Font.Gotham
		btn.Parent = scrollFrame

		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,4) bc.Parent = btn
		local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(50,50,80) bs.Thickness = 1 bs.Parent = btn

		if data.toggle then
			toggleStates[i] = false
			btn.BackgroundColor3 = Color3.fromRGB(40,40,58)
			btn.TextColor3 = Color3.fromRGB(160,160,190)
			btn.Text = data.label .. ": OFF"
			btn.MouseButton1Click:Connect(function()
				toggleStates[i] = not toggleStates[i]
				local state = toggleStates[i]
				local cmd = state and data.on or data.off
				btn.Text = data.label .. (state and ": ON" or ": OFF")
				btn.BackgroundColor3 = state and Color3.fromRGB(25,90,45) or Color3.fromRGB(40,40,58)
				btn.TextColor3 = state and Color3.fromRGB(80,230,130) or Color3.fromRGB(160,160,190)
				sendCommand(cmd)
				sendWhisper("Sent: " .. cmd)
			end)
		else
			btn.BackgroundColor3 = Color3.fromRGB(22,22,38)
			btn.TextColor3 = Color3.fromRGB(200,200,240)
			btn.Text = data.label

			btn.MouseButton1Click:Connect(function()
				local full = ""
				if data.cmd then
					full = data.cmd
				elseif data.input then
					local arg = argInput.Text
					if arg == "" then sendWhisper("Type argument first!") return end
					full = data.base .. " " .. arg
				end
				if full == "" then return end
				sendCommand(full)
				sendWhisper("Sent: " .. full)
			end)

			btn.MouseButton2Click:Connect(function()
				local full = ""
				if data.cmd then
					full = data.cmd
				elseif data.input then
					local arg = argInput.Text
					if arg == "" then sendWhisper("Type argument first!") return end
					full = data.base .. " " .. arg
				end
				if full == "" then return end
				if loopCmd then
					stopLoop()
					loopLabel.Text = "⟳ No loop"
					loopLabel.TextColor3 = Color3.fromRGB(120,120,150)
				else
					startLoop(full)
					loopLabel.Text = "⟳ " .. full
					loopLabel.TextColor3 = Color3.fromRGB(255,120,120)
				end
			end)
		end
	end

	quickTabGui = screenGui
	quickTabVisible = true

	if robotName ~= "" then
		sendWhisper("Loaded robot: " .. robotName)
	end
end

localPlayer.Chatted:Connect(function(message)
	local lower = message:lower()
	if lower == ".quicktab" then
		if quickTabVisible then
			if settingsGui then settingsGui:Destroy() settingsGui = nil end
			if pingConnection then pingConnection:Disconnect() pingConnection = nil end
			if quickTabGui then quickTabGui:Destroy() quickTabGui = nil end
			quickTabVisible = false
			settingsVisible = false
		else
			createQuickTab()
		end
	elseif lower == ".commands" then
		for _, data in ipairs(COMMANDS) do
			sendWhisper(data.label)
		end
	end
end)

sendWhisper("Operator ready. Type .quicktab | Robot: " .. (robotName ~= "" and robotName or "not set"))
