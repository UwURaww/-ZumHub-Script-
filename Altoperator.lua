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
local loopConnection = nil
local loopCmd = nil
local pingConnection = nil
local COOLDOWN = 0.8
local lastSent = 0
local guiWidth = 300
local guiHeight = 460
local statusDotRef = nil
local quickTabHidden = false
local loopLabelRef = nil

local BOTS_SAVE_KEY = "RobotOperatorBots_v2"
local ACTIVE_BOT_KEY = "RobotOperatorActive_v2"

local bots = {}
local activeBotIndex = 1

local function saveBots()
	local encoded = {}
	for i, bot in ipairs(bots) do
		encoded[i] = bot.name .. "|" .. bot.nick
	end
	localPlayer:SetAttribute(BOTS_SAVE_KEY, table.concat(encoded, ";;"))
	localPlayer:SetAttribute(ACTIVE_BOT_KEY, tostring(activeBotIndex))
end

local function loadBots()
	local raw = localPlayer:GetAttribute(BOTS_SAVE_KEY)
	local activeRaw = localPlayer:GetAttribute(ACTIVE_BOT_KEY)
	bots = {}
	if raw and raw ~= "" then
		for _, entry in ipairs(raw:split(";;")) do
			local parts = entry:split("|")
			if parts[1] and parts[1] ~= "" then
				table.insert(bots, {name = parts[1], nick = parts[2] or parts[1]})
			end
		end
	end
	if #bots == 0 then
		table.insert(bots, {name = "", nick = "Bot 1"})
	end
	activeBotIndex = tonumber(activeRaw) or 1
	if activeBotIndex > #bots then activeBotIndex = 1 end
end

loadBots()

local function getActiveBot()
	return bots[activeBotIndex] or bots[1]
end

local function getRobotName()
	local bot = getActiveBot()
	return bot and bot.name or ""
end

local function sendWhisper(message)
	game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
		Text = "[Operator] " .. message,
		Color = Color3.fromRGB(255, 180, 80),
		FontSize = Enum.FontSize.Size18,
	})
end

local function parsePrefix(cmd)
	local s = cmd:gsub("^%s+", ""):gsub("%s+$", "")
	if s:sub(1,2) == ". " then s = "." .. s:sub(3) end
	return s
end

local function sendCommandToBot(cmd, botName)
	local now = tick()
	if now - lastSent < COOLDOWN then return end
	lastSent = now
	local channel = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if not channel then return end
	local cleaned = parsePrefix(cmd)
	if useWhisper and botName ~= "" then
		channel:SendAsync("/w " .. botName .. " " .. cleaned)
	else
		channel:SendAsync(cleaned)
	end
end

local function sendCommand(cmd)
	sendCommandToBot(cmd, getRobotName())
end

local function sendCommandToAll(cmd)
	for _, bot in ipairs(bots) do
		if bot.name ~= "" then
			task.spawn(function()
				task.wait(0.1)
				sendCommandToBot(cmd, bot.name)
			end)
		end
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
			local cleaned = parsePrefix(loopCmd)
			local rn = getRobotName()
			if useWhisper and rn ~= "" then
				channel:SendAsync("/w " .. rn .. " " .. cleaned)
			else
				channel:SendAsync(cleaned)
			end
		end
	end)
	if loopLabelRef then
		loopLabelRef.Text = "⟳ " .. cmd
		loopLabelRef.TextColor3 = Color3.fromRGB(255, 120, 120)
	end
	sendWhisper("Looping: " .. cmd)
end

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection = nil end
	loopCmd = nil
	if loopLabelRef then
		loopLabelRef.Text = "⟳ No loop"
		loopLabelRef.TextColor3 = Color3.fromRGB(120, 120, 150)
	end
	sendWhisper("Loop stopped.")
end

local function startView()
	local rn = getRobotName()
	if rn == "" then sendWhisper("Set robot name first!") return end
	local robot = Players:FindFirstChild(rn)
	if not robot or not robot.Character then sendWhisper("Robot not found.") return end
	local cam = game:GetService("Workspace").CurrentCamera
	savedCameraMode = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	viewingRobot = true
	viewConnection = RunService.Heartbeat:Connect(function()
		if not viewingRobot then return end
		local r = Players:FindFirstChild(rn)
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
	local rn = getRobotName()
	local robot = rn ~= "" and Players:FindFirstChild(rn)
	local connected = robot ~= nil and robot.Character ~= nil
	statusDotRef.BackgroundColor3 = connected and Color3.fromRGB(20, 80, 30) or Color3.fromRGB(80, 20, 20)
	statusDotRef.Text = connected and ("● " .. (getActiveBot().nick or rn) .. " ONLINE") or ("● " .. (getActiveBot().nick or "Bot") .. " OFFLINE")
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
	{label = ".wave", cmd = ".wave"},
	{label = ".laugh", cmd = ".laugh"},
	{label = ".cheer", cmd = ".cheer"},
	{label = ".point", cmd = ".point"},
	{label = ".dance", cmd = ".dance"},
	{label = ".dance2", cmd = ".dance2"},
	{label = ".dance3", cmd = ".dance3"},
	{label = ".gravityoff", cmd = ".gravityoff"},
	{label = ".gravityreset", cmd = ".gravityreset"},
	{label = ".tpme", cmd = ".tpme"},
	{label = ".savepos", cmd = ".savepos"},
	{label = ".loadpos", cmd = ".loadpos"},
	{label = ".health", cmd = ".health"},
	{label = ".pos", cmd = ".pos"},
	{label = ".rig", cmd = ".rig"},
	{label = ".unloop", cmd = ".unloop"},
	{label = ".status", cmd = ".status"},
	{label = ".aliases", cmd = ".aliases"},
	{label = "noclip", toggle = true, on = ".nc on", off = ".nc off"},
	{label = "invisible", toggle = true, on = ".inv on", off = ".inv off"},
	{label = "godmode", toggle = true, on = ".gm on", off = ".gm off"},
	{label = "spin", toggle = true, on = ".spin on", off = ".spin off"},
	{label = "float", toggle = true, on = ".fl on", off = ".fl off"},
	{label = "bighead", toggle = true, on = ".bh on", off = ".bh off"},
	{label = "freeze", toggle = true, on = ".frz", off = ".ufrz"},
	{label = "crouch", toggle = true, on = ".cr on", off = ".cr off"},
	{label = "lockcontrol", toggle = true, on = ".lck on", off = ".lck off"},
	{label = "mirror", toggle = true, on = ".mir on", off = ".mir off"},
	{label = ".fw [n]", cmd = nil, input = true, base = ".fw"},
	{label = ".bk [n]", cmd = nil, input = true, base = ".bk"},
	{label = ".lt [n]", cmd = nil, input = true, base = ".lt"},
	{label = ".rt [n]", cmd = nil, input = true, base = ".rt"},
	{label = ".tl [deg]", cmd = nil, input = true, base = ".tl"},
	{label = ".tr [deg]", cmd = nil, input = true, base = ".tr"},
	{label = ".flw [n]", cmd = nil, input = true, base = ".flw"},
	{label = ".orb [n]", cmd = nil, input = true, base = ".orb"},
	{label = ".gt [n]", cmd = nil, input = true, base = ".gt"},
	{label = ".ltp [n]", cmd = nil, input = true, base = ".ltp"},
	{label = ".lk [n]", cmd = nil, input = true, base = ".lk"},
	{label = ".tp [n]", cmd = nil, input = true, base = ".tp"},
	{label = ".say [txt]", cmd = nil, input = true, base = ".say"},
	{label = ".e [name]", cmd = nil, input = true, base = ".e"},
	{label = ".ptr [n1 n2]", cmd = nil, input = true, base = ".ptr"},
	{label = ".grv [n]", cmd = nil, input = true, base = ".grv"},
	{label = ".trp [n]", cmd = nil, input = true, base = ".trp"},
	{label = ".sz [n]", cmd = nil, input = true, base = ".sz"},
	{label = ".spd [n]", cmd = nil, input = true, base = ".spd"},
	{label = ".jp [n]", cmd = nil, input = true, base = ".jp"},
	{label = ".loop [cmd]", cmd = nil, input = true, base = ".loop"},
}

local stepPresets = {5, 10, 20, 50}

local botsScrollRef = nil

local function refreshBotsScroll()
	if not botsScrollRef then return end
	for _, child in ipairs(botsScrollRef:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	for i, bot in ipairs(bots) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Size = UDim2.new(1, -8, 0, 32)
		rowFrame.BackgroundColor3 = (i == activeBotIndex) and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(20, 20, 32)
		rowFrame.BorderSizePixel = 0
		rowFrame.Parent = botsScrollRef
		local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0,5) rc.Parent = rowFrame
		if i == activeBotIndex then
			local rs = Instance.new("UIStroke") rs.Color = Color3.fromRGB(80,200,100) rs.Thickness = 1 rs.Parent = rowFrame
		end

		local nickBox = Instance.new("TextBox")
		nickBox.Size = UDim2.new(0, 70, 0, 24)
		nickBox.Position = UDim2.new(0, 4, 0, 4)
		nickBox.BackgroundColor3 = Color3.fromRGB(18,18,28)
		nickBox.TextColor3 = Color3.fromRGB(200,200,240)
		nickBox.PlaceholderText = "nick"
		nickBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
		nickBox.Text = bot.nick
		nickBox.TextScaled = true
		nickBox.Font = Enum.Font.Gotham
		nickBox.BorderSizePixel = 0
		nickBox.ClearTextOnFocus = false
		nickBox.Parent = rowFrame
		local nc2 = Instance.new("UICorner") nc2.CornerRadius = UDim.new(0,4) nc2.Parent = nickBox
		nickBox:GetPropertyChangedSignal("Text"):Connect(function()
			bots[i].nick = nickBox.Text
			saveBots()
		end)

		local nameBox = Instance.new("TextBox")
		nameBox.Size = UDim2.new(0, 90, 0, 24)
		nameBox.Position = UDim2.new(0, 78, 0, 4)
		nameBox.BackgroundColor3 = Color3.fromRGB(18,18,28)
		nameBox.TextColor3 = Color3.fromRGB(220,220,255)
		nameBox.PlaceholderText = "username"
		nameBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
		nameBox.Text = bot.name
		nameBox.TextScaled = true
		nameBox.Font = Enum.Font.Gotham
		nameBox.BorderSizePixel = 0
		nameBox.ClearTextOnFocus = false
		nameBox.Parent = rowFrame
		local nbc = Instance.new("UICorner") nbc.CornerRadius = UDim.new(0,4) nbc.Parent = nameBox
		nameBox:GetPropertyChangedSignal("Text"):Connect(function()
			bots[i].name = nameBox.Text
			saveBots()
			updateStatusDot()
		end)

		local selectBtn = Instance.new("TextButton")
		selectBtn.Size = UDim2.new(0, 36, 0, 24)
		selectBtn.Position = UDim2.new(0, 172, 0, 4)
		selectBtn.BackgroundColor3 = (i == activeBotIndex) and Color3.fromRGB(30,100,50) or Color3.fromRGB(40,40,60)
		selectBtn.Text = i == activeBotIndex and "✓" or "USE"
		selectBtn.TextColor3 = Color3.fromRGB(255,255,255)
		selectBtn.TextScaled = true
		selectBtn.Font = Enum.Font.GothamBold
		selectBtn.BorderSizePixel = 0
		selectBtn.Parent = rowFrame
		local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0,4) sbc.Parent = selectBtn
		selectBtn.MouseButton1Click:Connect(function()
			activeBotIndex = i
			saveBots()
			updateStatusDot()
			refreshBotsScroll()
			sendWhisper("Active bot: " .. (bot.nick ~= "" and bot.nick or bot.name))
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.new(0, 24, 0, 24)
		delBtn.Position = UDim2.new(0, 212, 0, 4)
		delBtn.BackgroundColor3 = Color3.fromRGB(120,30,30)
		delBtn.Text = "✕"
		delBtn.TextColor3 = Color3.fromRGB(255,255,255)
		delBtn.TextScaled = true
		delBtn.Font = Enum.Font.GothamBold
		delBtn.BorderSizePixel = 0
		delBtn.Parent = rowFrame
		local dbc = Instance.new("UICorner") dbc.CornerRadius = UDim.new(0,4) dbc.Parent = delBtn
		delBtn.MouseButton1Click:Connect(function()
			if #bots > 1 then
				table.remove(bots, i)
				if activeBotIndex > #bots then activeBotIndex = #bots end
				saveBots()
				updateStatusDot()
				refreshBotsScroll()
			else
				sendWhisper("Need at least one bot slot.")
			end
		end)
	end
end

local function createSettingsGui()
	if settingsGui then settingsGui:Destroy() settingsGui = nil end
	if pingConnection then pingConnection:Disconnect() pingConnection = nil end
	if not settingsVisible then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "SettingsPanel"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = localPlayer.PlayerGui

	local panelW = 260
	local panelH = 580

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, panelW, 0, panelH)
	panel.Position = UDim2.new(1, -(guiWidth + panelW + 24), 0.5, -(panelH / 2))
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Draggable = true
	panel.Parent = sg

	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,10) pc.Parent = panel
	local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(100,100,160) ps.Thickness = 1.5 ps.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 28)
	titleBar.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel
	local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0,10) tbc.Parent = titleBar

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
	local csc = Instance.new("UICorner") csc.CornerRadius = UDim.new(0,4) csc.Parent = closeS
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
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,160)
	scroll.CanvasSize = UDim2.new(0,0,0,0)
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
		lbl.TextColor3 = Color3.fromRGB(120,120,180)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = scroll
	end

	local function makeSettBtn(text, color, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, sw, 0, 26)
		btn.BackgroundColor3 = color
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255,255,255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.BorderSizePixel = 0
		btn.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = btn
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	local function makeBox(placeholder, default)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0, sw, 0, 26)
		box.BackgroundColor3 = Color3.fromRGB(20,20,32)
		box.TextColor3 = Color3.fromRGB(220,220,255)
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(80,80,110)
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

	local function makeSettToggle(text, initState, onColor, offColor, callback)
		local state = initState
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, sw, 0, 26)
		btn.BackgroundColor3 = state and onColor or offColor
		btn.Text = text .. (state and ": ON" or ": OFF")
		btn.TextColor3 = Color3.fromRGB(255,255,255)
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
	statusDot.BackgroundColor3 = Color3.fromRGB(80,20,20)
	statusDot.Text = "● OFFLINE"
	statusDot.TextColor3 = Color3.fromRGB(255,80,80)
	statusDot.TextScaled = true
	statusDot.Font = Enum.Font.GothamBold
	statusDot.BorderSizePixel = 0
	statusDot.Parent = scroll
	local sdc = Instance.new("UICorner") sdc.CornerRadius = UDim.new(0,5) sdc.Parent = statusDot
	statusDotRef = statusDot
	updateStatusDot()

	sectionLabel("Bot Management")

	local botsScroll = Instance.new("ScrollingFrame")
	botsScroll.Size = UDim2.new(0, sw, 0, 140)
	botsScroll.BackgroundColor3 = Color3.fromRGB(16,16,24)
	botsScroll.BorderSizePixel = 0
	botsScroll.ScrollBarThickness = 3
	botsScroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,160)
	botsScroll.CanvasSize = UDim2.new(0,0,0,0)
	botsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	botsScroll.Parent = scroll
	local bsc = Instance.new("UICorner") bsc.CornerRadius = UDim.new(0,5) bsc.Parent = botsScroll
	local bsLayout = Instance.new("UIListLayout")
	bsLayout.Padding = UDim.new(0, 3)
	bsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bsLayout.Parent = botsScroll
	local bsPad = Instance.new("UIPadding")
	bsPad.PaddingTop = UDim.new(0,3) bsPad.PaddingLeft = UDim.new(0,3) bsPad.PaddingRight = UDim.new(0,3)
	bsPad.Parent = botsScroll
	botsScrollRef = botsScroll
	refreshBotsScroll()

	makeSettBtn("+ Add Bot Slot", Color3.fromRGB(30,70,30), function()
		local num = #bots + 1
		table.insert(bots, {name = "", nick = "Bot " .. num})
		saveBots()
		refreshBotsScroll()
	end)

	makeSettBtn("Send to ALL bots", Color3.fromRGB(60,40,80), function()
		sendWhisper("Broadcast mode — next cmd goes to all bots. Use .all [cmd] in chat.")
	end)

	sectionLabel("Quick Send Command")
	local quickCmdBox = makeBox("e.g. .spd 60 or .follow me")
	makeSettBtn("Send to Active Bot", Color3.fromRGB(50,80,50), function()
		local txt = parsePrefix(quickCmdBox.Text)
		if txt ~= "" and txt:sub(1,1) == "." then
			sendCommand(txt)
			sendWhisper("Sent: " .. txt)
		else
			sendWhisper("Start with a dot!")
		end
	end)
	makeSettBtn("Send to ALL Bots", Color3.fromRGB(60,40,80), function()
		local txt = parsePrefix(quickCmdBox.Text)
		if txt ~= "" and txt:sub(1,1) == "." then
			sendCommandToAll(txt)
			sendWhisper("Broadcast: " .. txt)
		else
			sendWhisper("Start with a dot!")
		end
	end)

	sectionLabel("Loop Command")
	local loopCmdBox = makeBox("e.g. .spd 60   or   .follow me")
	makeSettBtn("Start Loop", Color3.fromRGB(80,40,100), function()
		local txt = parsePrefix(loopCmdBox.Text)
		if txt ~= "" and txt:sub(1,1) == "." then
			startLoop(txt)
		else
			sendWhisper("Start with a dot!")
		end
	end)
	makeSettBtn("Stop Loop (Unloop)", Color3.fromRGB(120,40,40), function()
		stopLoop()
	end)

	sectionLabel("Communication")
	makeSettToggle("Whisper", useWhisper, Color3.fromRGB(30,120,60), Color3.fromRGB(120,40,40), function(state)
		useWhisper = state
		sendWhisper("Whisper: " .. (state and "ON" or "OFF"))
	end)

	sectionLabel("View Robot Camera")
	makeSettToggle("View Robot", viewingRobot, Color3.fromRGB(40,80,160), Color3.fromRGB(40,50,80), function(state)
		if state then startView() else stopView() end
	end)

	sectionLabel("Quicktab Visibility")
	makeSettBtn(quickTabHidden and "Show Quicktab" or "Hide Quicktab", Color3.fromRGB(60,60,80), function()
		if quickTabGui then
			local mainFrame = quickTabGui:FindFirstChildOfClass("Frame")
			if mainFrame then
				quickTabHidden = not quickTabHidden
				mainFrame.Visible = not quickTabHidden
			end
		end
		createSettingsGui()
	end)

	sectionLabel("Command Cooldown (s)")
	local coolBox = makeBox("0.8", tostring(COOLDOWN))
	makeSettBtn("Apply Cooldown", Color3.fromRGB(50,50,90), function()
		local v = tonumber(coolBox.Text)
		if v and v >= 0.3 then
			COOLDOWN = v
			sendWhisper("Cooldown: " .. v .. "s")
		else
			sendWhisper("Min: 0.3s")
		end
	end)

	sectionLabel("GUI Size Presets")
	local sizesFrame = Instance.new("Frame")
	sizesFrame.Size = UDim2.new(0, sw, 0, 26)
	sizesFrame.BackgroundTransparency = 1
	sizesFrame.Parent = scroll
	local sizePresets = {{"S",220,380},{"M",300,460},{"L",360,520},{"XL",420,580}}
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
	local hw = math.floor(sw/2) - 2
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
	frame.Position = UDim2.new(1, -(guiWidth+15), 0.5, -(guiHeight/2))
	frame.BackgroundColor3 = Color3.fromRGB(11,11,17)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Visible = not quickTabHidden
	frame.Parent = screenGui

	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,10) corner.Parent = frame
	local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255,180,80) stroke.Thickness = 1.5 stroke.Parent = frame

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1,0,0,28)
	titleBar.BackgroundColor3 = Color3.fromRGB(16,14,22)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = frame
	local tbc2 = Instance.new("UICorner") tbc2.CornerRadius = UDim.new(0,10) tbc2.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1,-80,1,0)
	titleLbl.Position = UDim2.new(0,10,0,0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "QUICK TAB"
	titleLbl.TextColor3 = Color3.fromRGB(255,180,80)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = titleBar

	local cogBtn = Instance.new("TextButton")
	cogBtn.Size = UDim2.new(0,24,0,24)
	cogBtn.Position = UDim2.new(1,-52,0,2)
	cogBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
	cogBtn.Text = "⚙"
	cogBtn.TextColor3 = Color3.fromRGB(180,180,220)
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
	closeBtn.Size = UDim2.new(0,24,0,24)
	closeBtn.Position = UDim2.new(1,-26,0,2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
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

	local botSelectFrame = Instance.new("Frame")
	botSelectFrame.Size = UDim2.new(0, innerSw, 0, 24)
	botSelectFrame.Position = UDim2.new(0, 8, 0, yOff)
	botSelectFrame.BackgroundTransparency = 1
	botSelectFrame.Parent = frame

	local botLabel = Instance.new("TextLabel")
	botLabel.Size = UDim2.new(0, 40, 1, 0)
	botLabel.BackgroundTransparency = 1
	botLabel.Text = "Bot:"
	botLabel.TextColor3 = Color3.fromRGB(150,150,180)
	botLabel.TextScaled = true
	botLabel.Font = Enum.Font.Gotham
	botLabel.TextXAlignment = Enum.TextXAlignment.Left
	botLabel.Parent = botSelectFrame

	local botBtnW = math.floor((innerSw - 44) / math.max(#bots, 1))
	for i, bot in ipairs(bots) do
		local bb = Instance.new("TextButton")
		bb.Size = UDim2.new(0, math.min(botBtnW, 60), 1, 0)
		bb.Position = UDim2.new(0, 42 + (i-1) * (math.min(botBtnW,60)+3), 0, 0)
		bb.BackgroundColor3 = (i == activeBotIndex) and Color3.fromRGB(30,100,50) or Color3.fromRGB(35,35,55)
		bb.Text = bot.nick ~= "" and bot.nick or ("B"..i)
		bb.TextColor3 = Color3.fromRGB(220,220,255)
		bb.TextScaled = true
		bb.Font = Enum.Font.Gotham
		bb.BorderSizePixel = 0
		bb.Parent = botSelectFrame
		local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(0,4) bbc.Parent = bb
		bb.MouseButton1Click:Connect(function()
			activeBotIndex = i
			saveBots()
			updateStatusDot()
			createQuickTab()
		end)
	end
	yOff = yOff + 28

	local argInput = Instance.new("TextBox")
	argInput.Size = UDim2.new(0, innerSw, 0, 22)
	argInput.Position = UDim2.new(0, 8, 0, yOff)
	argInput.BackgroundColor3 = Color3.fromRGB(20,20,32)
	argInput.TextColor3 = Color3.fromRGB(220,220,255)
	argInput.PlaceholderText = "argument / name / text..."
	argInput.PlaceholderColor3 = Color3.fromRGB(80,80,110)
	argInput.Text = ""
	argInput.TextScaled = true
	argInput.Font = Enum.Font.Gotham
	argInput.BorderSizePixel = 0
	argInput.ClearTextOnFocus = false
	argInput.Parent = frame
	local aic = Instance.new("UICorner") aic.CornerRadius = UDim.new(0,5) aic.Parent = argInput
	local ais = Instance.new("UIStroke") ais.Color = Color3.fromRGB(60,60,100) ais.Thickness = 1 ais.Parent = argInput
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
	stopLoopBtn.Text = "Unloop"
	stopLoopBtn.TextColor3 = Color3.fromRGB(255,255,255)
	stopLoopBtn.TextScaled = true
	stopLoopBtn.Font = Enum.Font.Gotham
	stopLoopBtn.BorderSizePixel = 0
	stopLoopBtn.Parent = loopFrame
	local slc = Instance.new("UICorner") slc.CornerRadius = UDim.new(0,4) slc.Parent = stopLoopBtn
	stopLoopBtn.MouseButton1Click:Connect(function() stopLoop() end)
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
				if loopCmd then stopLoop()
				else startLoop(full) end
			end)
		end
	end

	quickTabGui = screenGui
	quickTabVisible = true

	local rn = getRobotName()
	sendWhisper("Ready. Active: " .. (getActiveBot().nick ~= "" and getActiveBot().nick or (rn ~= "" and rn or "not set")))
end

localPlayer.Chatted:Connect(function(message)
	local parsed = parsePrefix(message)
	local lower = parsed:lower()
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
	elseif lower:sub(1,5) == ".all " then
		local cmd = parsed:sub(6)
		if cmd ~= "" then
			sendCommandToAll(cmd)
			sendWhisper("Broadcast: " .. cmd)
		end
	elseif lower == ".commands" then
		for _, data in ipairs(COMMANDS) do
			sendWhisper(data.label)
		end
	end
end)

sendWhisper("Operator ready. .quicktab to open | Bots: " .. #bots .. " | Active: " .. (getActiveBot().nick ~= "" and getActiveBot().nick or (getRobotName() ~= "" and getRobotName() or "not set")))
