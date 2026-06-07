local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local quickTabGui = nil
local quickTabVisible = false
local viewConnection = nil
local viewingRobot = false
local savedCameraMode = nil
local useWhisper = true
local robotName = ""
local loopConnection = nil
local loopCmd = nil

local lastSent = 0
local COOLDOWN = 0.8
local guiWidth = 280
local guiHeight = 420

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
	loopConnection = game:GetService("RunService").Heartbeat:Connect(function()
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
	sendWhisper("Viewing robot.")
	viewConnection = game:GetService("RunService").Heartbeat:Connect(function()
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
	sendWhisper("View stopped.")
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
	{label = ".gravityoff", cmd = ".gravityoff"},
	{label = ".gravityreset", cmd = ".gravityreset"},
	{label = ".loopstop", cmd = ".loopstop"},
	{label = ".status", cmd = ".status"},
	{label = ".e wave", cmd = ".e wave"},
	{label = ".e dance", cmd = ".e dance"},
	{label = ".e dance2", cmd = ".e dance2"},
	{label = ".e dance3", cmd = ".e dance3"},
	{label = ".e laugh", cmd = ".e laugh"},
	{label = ".e cheer", cmd = ".e cheer"},
	{label = ".e point", cmd = ".e point"},
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
	{label = ".goto [n]", cmd = nil, input = true, base = ".goto"},
	{label = ".looptp [n]", cmd = nil, input = true, base = ".looptp"},
	{label = ".lookat [n]", cmd = nil, input = true, base = ".lookat"},
	{label = ".tp [n]", cmd = nil, input = true, base = ".tp"},
	{label = ".say [txt]", cmd = nil, input = true, base = ".say"},
	{label = ".speed [n]", cmd = nil, input = true, base = ".speed"},
	{label = ".jumppower [n]", cmd = nil, input = true, base = ".jumppower"},
	{label = ".gravity [n]", cmd = nil, input = true, base = ".gravity"},
	{label = ".e [name]", cmd = nil, input = true, base = ".e"},
	{label = ".patrol [n1 n2]", cmd = nil, input = true, base = ".patrol"},
	{label = ".loop [cmd]", cmd = nil, input = true, base = ".loop"},
}

local speedPresets = {8, 16, 24, 50, 100}
local jumpPresets = {50, 100, 150, 200}
local stepPresets = {5, 10, 20, 50}

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
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	frame.BackgroundTransparency = 0.05
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

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -36, 0, 24)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "QUICK TAB"
	title.TextColor3 = Color3.fromRGB(255, 180, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(1, -26, 0, 4)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 4)
	cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		quickTabGui:Destroy()
		quickTabGui = nil
		quickTabVisible = false
	end)

	local robotInput = Instance.new("TextBox")
	robotInput.Size = UDim2.new(1, -16, 0, 22)
	robotInput.Position = UDim2.new(0, 8, 0, 30)
	robotInput.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	robotInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	robotInput.PlaceholderText = "robot username..."
	robotInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	robotInput.Text = robotName
	robotInput.TextScaled = true
	robotInput.Font = Enum.Font.Gotham
	robotInput.BorderSizePixel = 0
	robotInput.ClearTextOnFocus = false
	robotInput.Parent = frame
	local ric = Instance.new("UICorner")
	ric.CornerRadius = UDim.new(0, 4)
	ric.Parent = robotInput
	robotInput:GetPropertyChangedSignal("Text"):Connect(function()
		robotName = robotInput.Text
	end)

	local halfW = math.floor((guiWidth - 20) / 2)

	local function makeTopToggle(text, xOff, yOff, w, activeColor, inactiveColor, initState, onToggle)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, w, 0, 20)
		btn.Position = UDim2.new(0, xOff, 0, yOff)
		btn.BackgroundColor3 = initState and activeColor or inactiveColor
		btn.Text = text .. (initState and ": ON" or ": OFF")
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.BorderSizePixel = 0
		btn.Parent = frame
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 4)
		bc.Parent = btn
		local state = initState
		btn.MouseButton1Click:Connect(function()
			state = not state
			btn.BackgroundColor3 = state and activeColor or inactiveColor
			btn.Text = text .. (state and ": ON" or ": OFF")
			onToggle(state)
		end)
		return btn
	end

	makeTopToggle("Whisper", 8, 56, halfW, Color3.fromRGB(30, 120, 60), Color3.fromRGB(100, 40, 40), useWhisper, function(state)
		useWhisper = state
		sendWhisper("Whisper: " .. (state and "ON" or "OFF"))
	end)

	makeTopToggle("View", 8 + halfW + 4, 56, halfW, Color3.fromRGB(40, 80, 160), Color3.fromRGB(40, 50, 80), false, function(state)
		if state then startView() else stopView() end
	end)

	local argInput = Instance.new("TextBox")
	argInput.Size = UDim2.new(1, -16, 0, 22)
	argInput.Position = UDim2.new(0, 8, 0, 80)
	argInput.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	argInput.TextColor3 = Color3.fromRGB(255, 255, 255)
	argInput.PlaceholderText = "argument for [n] commands..."
	argInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	argInput.Text = ""
	argInput.TextScaled = true
	argInput.Font = Enum.Font.Gotham
	argInput.BorderSizePixel = 0
	argInput.ClearTextOnFocus = false
	argInput.Parent = frame
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 4)
	ac.Parent = argInput

	local loopLabel = Instance.new("TextLabel")
	loopLabel.Size = UDim2.new(1, -76, 0, 18)
	loopLabel.Position = UDim2.new(0, 8, 0, 106)
	loopLabel.BackgroundTransparency = 1
	loopLabel.Text = loopCmd and ("Loop: " .. loopCmd) or "Loop: OFF"
	loopLabel.TextColor3 = loopCmd and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(150, 150, 170)
	loopLabel.TextScaled = true
	loopLabel.Font = Enum.Font.Gotham
	loopLabel.TextXAlignment = Enum.TextXAlignment.Left
	loopLabel.Parent = frame

	local stopLoopBtn = Instance.new("TextButton")
	stopLoopBtn.Size = UDim2.new(0, 62, 0, 18)
	stopLoopBtn.Position = UDim2.new(1, -70, 0, 106)
	stopLoopBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
	stopLoopBtn.Text = "Stop Loop"
	stopLoopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	stopLoopBtn.TextScaled = true
	stopLoopBtn.Font = Enum.Font.Gotham
	stopLoopBtn.BorderSizePixel = 0
	stopLoopBtn.Parent = frame
	local slc = Instance.new("UICorner")
	slc.CornerRadius = UDim.new(0, 4)
	slc.Parent = stopLoopBtn
	stopLoopBtn.MouseButton1Click:Connect(function()
		stopLoop()
		loopLabel.Text = "Loop: OFF"
		loopLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
	end)

	local function makePresetRow(parent, label, presets, buildCmd, yPos)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 40, 0, 16)
		lbl.Position = UDim2.new(0, 8, 0, yPos)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = parent
		local availW = guiWidth - 20 - 44
		local btnW = math.floor(availW / #presets) - 3
		for i, val in ipairs(presets) do
			local pb = Instance.new("TextButton")
			pb.Size = UDim2.new(0, btnW, 0, 16)
			pb.Position = UDim2.new(0, 50 + (i - 1) * (btnW + 3), 0, yPos)
			pb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
			pb.TextColor3 = Color3.fromRGB(220, 220, 255)
			pb.Text = tostring(val)
			pb.TextScaled = true
			pb.Font = Enum.Font.Gotham
			pb.BorderSizePixel = 0
			pb.Parent = parent
			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(0, 3)
			pc.Parent = pb
			pb.MouseButton1Click:Connect(function()
				local cmd = buildCmd(val)
				sendCommand(cmd)
				sendWhisper("Sent: " .. cmd)
			end)
		end
	end

	makePresetRow(frame, "Spd:", speedPresets, function(v) return ".speed " .. v end, 128)
	makePresetRow(frame, "Jmp:", jumpPresets, function(v) return ".jumppower " .. v end, 148)
	makePresetRow(frame, "Stp:", stepPresets, function(v) return ".fw " .. v end, 168)

	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(0, 40, 0, 16)
	sizeLabel.Position = UDim2.new(0, 8, 0, 188)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Text = "Size:"
	sizeLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	sizeLabel.TextScaled = true
	sizeLabel.Font = Enum.Font.Gotham
	sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeLabel.Parent = frame

	local sizes = {{"S", 220, 360}, {"M", 280, 420}, {"L", 360, 520}}
	for i, s in ipairs(sizes) do
		local sb = Instance.new("TextButton")
		sb.Size = UDim2.new(0, 36, 0, 16)
		sb.Position = UDim2.new(0, 50 + (i - 1) * 40, 0, 188)
		sb.BackgroundColor3 = (guiWidth == s[2]) and Color3.fromRGB(80, 80, 40) or Color3.fromRGB(40, 40, 60)
		sb.TextColor3 = Color3.fromRGB(220, 220, 255)
		sb.Text = s[1]
		sb.TextScaled = true
		sb.Font = Enum.Font.GothamBold
		sb.BorderSizePixel = 0
		sb.Parent = frame
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 3)
		sc.Parent = sb
		sb.MouseButton1Click:Connect(function()
			guiWidth = s[2]
			guiHeight = s[3]
			createQuickTab()
		end)
	end

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -16, 0, 1)
	divider.Position = UDim2.new(0, 8, 0, 208)
	divider.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -10, 1, -216)
	scrollFrame.Position = UDim2.new(0, 5, 0, 212)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 80)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local cellW = math.floor((guiWidth - 18) / 3)

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, cellW, 0, 24)
	layout.CellPadding = UDim2.new(0, 3, 0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.Parent = scrollFrame

	for i, data in ipairs(COMMANDS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, cellW, 0, 24)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.TextScaled = true
		btn.Font = Enum.Font.Gotham
		btn.Parent = scrollFrame

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 4)
		bc.Parent = btn

		local bs = Instance.new("UIStroke")
		bs.Color = Color3.fromRGB(60, 60, 90)
		bs.Thickness = 1
		bs.Parent = btn

		if data.toggle then
			toggleStates[i] = false
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
			btn.TextColor3 = Color3.fromRGB(180, 180, 200)
			btn.Text = data.label .. ": OFF"
			btn.MouseButton1Click:Connect(function()
				toggleStates[i] = not toggleStates[i]
				local state = toggleStates[i]
				local cmd = state and data.on or data.off
				btn.Text = data.label .. (state and ": ON" or ": OFF")
				btn.BackgroundColor3 = state and Color3.fromRGB(30, 100, 50) or Color3.fromRGB(50, 50, 70)
				btn.TextColor3 = state and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(180, 180, 200)
				sendCommand(cmd)
				sendWhisper("Sent: " .. cmd)
			end)
		else
			btn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
			btn.TextColor3 = Color3.fromRGB(210, 210, 255)
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
					loopLabel.Text = "Loop: OFF"
					loopLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
				else
					startLoop(full)
					loopLabel.Text = "Loop: " .. full
					loopLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				end
			end)
		end
	end

	quickTabGui = screenGui
	quickTabVisible = true
end

localPlayer.Chatted:Connect(function(message)
	local lower = message:lower()
	if lower == ".quicktab" then
		if quickTabVisible then
			if quickTabGui then quickTabGui:Destroy() quickTabGui = nil end
			quickTabVisible = false
		else
			createQuickTab()
		end
	elseif lower == ".view on" then
		startView()
	elseif lower == ".view off" then
		stopView()
	elseif lower == ".commands" then
		for _, data in ipairs(COMMANDS) do
			sendWhisper(data.label)
		end
	end
end)

sendWhisper("Operator ready. Type .quicktab | .view on/off | .commands")
