local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local ROBOT_NAME = "YourRobotNameHere"

local quickTabGui = nil
local quickTabVisible = false
local viewConnection = nil
local viewingRobot = false
local savedCameraMode = nil

local lastSent = 0
local COOLDOWN = 0.8

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
	if channel then channel:SendAsync("/w " .. ROBOT_NAME .. " " .. cmd) end
end

local function startView()
	local robot = Players:FindFirstChild(ROBOT_NAME)
	if not robot or not robot.Character then
		sendWhisper("Robot not found.")
		return
	end
	local cam = game:GetService("Workspace").CurrentCamera
	savedCameraMode = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	viewingRobot = true
	sendWhisper("Viewing robot.")
	viewConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if not viewingRobot then return end
		local r = Players:FindFirstChild(ROBOT_NAME)
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

local COMMANDS = {
	{label = ".follow me", cmd = ".follow me"},
	{label = ".stop", cmd = ".stop"},
	{label = ".sit", cmd = ".sit"},
	{label = ".stand", cmd = ".stand"},
	{label = ".jump", cmd = ".jump"},
	{label = ".freeze", cmd = ".freeze"},
	{label = ".unfreeze", cmd = ".unfreeze"},
	{label = ".noclip on", cmd = ".noclip on"},
	{label = ".noclip off", cmd = ".noclip off"},
	{label = ".invisible on", cmd = ".invisible on"},
	{label = ".invisible off", cmd = ".invisible off"},
	{label = ".godmode on", cmd = ".godmode on"},
	{label = ".godmode off", cmd = ".godmode off"},
	{label = ".spin on", cmd = ".spin on"},
	{label = ".spin off", cmd = ".spin off"},
	{label = ".float on", cmd = ".float on"},
	{label = ".float off", cmd = ".float off"},
	{label = ".fling", cmd = ".fling"},
	{label = ".gravityoff", cmd = ".gravityoff"},
	{label = ".gravityreset", cmd = ".gravityreset"},
	{label = ".bighead on", cmd = ".bighead on"},
	{label = ".bighead off", cmd = ".bighead off"},
	{label = ".reset", cmd = ".reset"},
	{label = ".status", cmd = ".status"},
	{label = ".e wave", cmd = ".e wave"},
	{label = ".e dance", cmd = ".e dance"},
	{label = ".e dance2", cmd = ".e dance2"},
	{label = ".e dance3", cmd = ".e dance3"},
	{label = ".e laugh", cmd = ".e laugh"},
	{label = ".e cheer", cmd = ".e cheer"},
	{label = ".e point", cmd = ".e point"},
	{label = ".fw [n]", cmd = nil, input = true, base = ".fw"},
	{label = ".bw [n]", cmd = nil, input = true, base = ".bw"},
	{label = ".l [n]", cmd = nil, input = true, base = ".l"},
	{label = ".r [n]", cmd = nil, input = true, base = ".r"},
	{label = ".tl [deg]", cmd = nil, input = true, base = ".tl"},
	{label = ".tr [deg]", cmd = nil, input = true, base = ".tr"},
	{label = ".follow [name]", cmd = nil, input = true, base = ".follow"},
	{label = ".goto [name]", cmd = nil, input = true, base = ".goto"},
	{label = ".looptp [name]", cmd = nil, input = true, base = ".looptp"},
	{label = ".lookat [name]", cmd = nil, input = true, base = ".lookat"},
	{label = ".tp [name]", cmd = nil, input = true, base = ".tp"},
	{label = ".say [text]", cmd = nil, input = true, base = ".say"},
	{label = ".speed [n]", cmd = nil, input = true, base = ".speed"},
	{label = ".jumppower [n]", cmd = nil, input = true, base = ".jumppower"},
	{label = ".gravity [n]", cmd = nil, input = true, base = ".gravity"},
	{label = ".e [name]", cmd = nil, input = true, base = ".e"},
	{label = ".patrol [n1 n2]", cmd = nil, input = true, base = ".patrol"},
}

local speedPresets = {8, 16, 24, 50, 100}
local jumpPresets = {50, 100, 150, 200}
local stepPresets = {5, 10, 20, 50}

local function createQuickTab()
	if quickTabGui then quickTabGui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuickTab"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 360, 0, 480)
	frame.Position = UDim2.new(1, -375, 0.5, -240)
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
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "QUICK TAB"
	title.TextColor3 = Color3.fromRGB(255, 180, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -30, 0, 4)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 5)
	cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		quickTabGui:Destroy()
		quickTabGui = nil
		quickTabVisible = false
	end)

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -16, 0, 28)
	inputBox.Position = UDim2.new(0, 8, 0, 36)
	inputBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	inputBox.PlaceholderText = "type argument then click command..."
	inputBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	inputBox.Text = ""
	inputBox.TextScaled = true
	inputBox.Font = Enum.Font.Gotham
	inputBox.BorderSizePixel = 0
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = frame
	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, 6)
	ic.Parent = inputBox

	local function makePresetRow(parent, label, presets, buildCmd, yPos)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 55, 0, 22)
		lbl.Position = UDim2.new(0, 8, 0, yPos)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = parent
		for i, val in ipairs(presets) do
			local pb = Instance.new("TextButton")
			pb.Size = UDim2.new(0, 52, 0, 22)
			pb.Position = UDim2.new(0, 63 + (i - 1) * 58, 0, yPos)
			pb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
			pb.TextColor3 = Color3.fromRGB(220, 220, 255)
			pb.Text = tostring(val)
			pb.TextScaled = true
			pb.Font = Enum.Font.Gotham
			pb.BorderSizePixel = 0
			pb.Parent = parent
			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(0, 5)
			pc.Parent = pb
			pb.MouseButton1Click:Connect(function()
				local cmd = buildCmd(val)
				sendCommand(cmd)
				sendWhisper("Sent: " .. cmd)
			end)
		end
	end

	makePresetRow(frame, "Speed:", speedPresets, function(v) return ".speed " .. v end, 70)
	makePresetRow(frame, "Jump:", jumpPresets, function(v) return ".jumppower " .. v end, 96)
	makePresetRow(frame, "Step:", stepPresets, function(v) return ".fw " .. v end, 122)

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -16, 0, 1)
	divider.Position = UDim2.new(0, 8, 0, 150)
	divider.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -10, 1, -158)
	scrollFrame.Position = UDim2.new(0, 5, 0, 155)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 80)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 108, 0, 30)
	layout.CellPadding = UDim2.new(0, 5, 0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = scrollFrame

	for _, data in ipairs(COMMANDS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 108, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
		btn.TextColor3 = Color3.fromRGB(210, 210, 255)
		btn.Text = data.label
		btn.TextScaled = true
		btn.Font = Enum.Font.Gotham
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Parent = scrollFrame

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 5)
		bc.Parent = btn

		local bs = Instance.new("UIStroke")
		bs.Color = Color3.fromRGB(60, 60, 90)
		bs.Thickness = 1
		bs.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if data.cmd then
				sendCommand(data.cmd)
				sendWhisper("Sent: " .. data.cmd)
			elseif data.input then
				local arg = inputBox.Text
				if arg == "" then
					sendWhisper("Type argument in box first!")
					return
				end
				local full = data.base .. " " .. arg
				sendCommand(full)
				sendWhisper("Sent: " .. full)
			end
		end)
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
