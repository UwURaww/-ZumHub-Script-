local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local quickTabGui = nil
local settingsGui = nil
local helpGui = nil
local quickTabVisible = false
local settingsVisible = false
local viewConnection = nil
local viewingRobot = false
local savedCameraMode = nil
local useWhisper = false
local loopConnection = nil
local loopCmd = nil
local pingConnection = nil
local COOLDOWN = 0.8
local lastSent = 0
local guiWidth = 520
local guiHeight = 480
local statusDotRef = nil
local quickTabHidden = false
local loopLabelRef = nil

local BOTS_FILE = "robot_bots.txt"
local BOTS_KEY = "RobotBots_v8"
local ACTIVE_KEY = "RobotActive_v8"
local SEEN_KEY = "RobotSeen_v6"

local bots = {}
local activeBotIndex = 1

local cmdLog = {}
local MAX_LOG = 40

local function generateToken(name)
	local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local seed = 0
	for i = 1, #name do seed = seed + string.byte(name,i)*i*31 end
	math.randomseed(seed)
	local r = ""
	for s = 1, 3 do
		for i = 1, 4 do r = r..chars:sub(math.random(1,#chars),math.random(1,#chars)) end
		if s < 3 then r = r.."-" end
	end
	return r
end

local PLAYER_TOKEN = generateToken(localPlayer.Name..localPlayer.UserId)

local function saveBots()
	local lines = {}
	for i, bot in ipairs(bots) do lines[i] = bot.name.."|"..bot.nick end
	local data = table.concat(lines, "\n").."||"..tostring(activeBotIndex)
	pcall(function() writefile(BOTS_FILE, data) end)
	local encoded = {}
	for i, bot in ipairs(bots) do encoded[i] = bot.name.."|"..bot.nick end
	localPlayer:SetAttribute(BOTS_KEY, table.concat(encoded,";;"))
	localPlayer:SetAttribute(ACTIVE_KEY, tostring(activeBotIndex))
end

local function loadBots()
	bots = {}
	local ok, data = pcall(function() return readfile(BOTS_FILE) end)
	if ok and data and data ~= "" then
		local parts = data:split("||")
		local botData = parts[1]
		local activeRaw = parts[2]
		for line in botData:gmatch("[^\n]+") do
			local p = line:split("|")
			if p[1] and p[1] ~= "" then
				table.insert(bots, {name=p[1], nick=p[2] or p[1]})
			end
		end
		activeBotIndex = tonumber(activeRaw) or 1
		if #bots > 0 then return end
	end
	local raw = localPlayer:GetAttribute(BOTS_KEY)
	local activeRaw = localPlayer:GetAttribute(ACTIVE_KEY)
	if raw and raw ~= "" then
		for _, entry in ipairs(raw:split(";;")) do
			local p = entry:split("|")
			if p[1] and p[1] ~= "" then
				table.insert(bots, {name=p[1], nick=p[2] or p[1]})
			end
		end
	end
	if #bots == 0 then table.insert(bots, {name="", nick="Bot 1"}) end
	activeBotIndex = tonumber(activeRaw) or 1
	if activeBotIndex > #bots then activeBotIndex = 1 end
end

loadBots()
local hasSeenLanding = localPlayer:GetAttribute(SEEN_KEY) == true

local function getActiveBot() return bots[activeBotIndex] or bots[1] end
local function getRobotName() local b = getActiveBot() return b and b.name or "" end

local notifQueue = {}
local notifActive = false
local logScrollRef = nil

local function addToLog(text)
	local ts = os.date and os.date("%H:%M:%S") or tostring(math.floor(tick() % 86400))
	table.insert(cmdLog, 1, "["..ts.."]  "..text)
	if #cmdLog > MAX_LOG then table.remove(cmdLog) end
	if logScrollRef then
		for _, child in ipairs(logScrollRef:GetChildren()) do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
		end
		for i, entry in ipairs(cmdLog) do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1,-8,0,16)
			lbl.BackgroundTransparency = 1
			lbl.Text = entry
			lbl.TextColor3 = i == 1 and Color3.fromRGB(200,220,255) or Color3.fromRGB(120,120,150)
			lbl.TextScaled = true
			lbl.Font = Enum.Font.Gotham
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = logScrollRef
		end
	end
end

local function processNotifQueue()
	if notifActive or #notifQueue == 0 then return end
	notifActive = true
	local data = table.remove(notifQueue, 1)

	local sg = Instance.new("ScreenGui")
	sg.Name = "OpNotif" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,260,0,52) frame.Position = UDim2.new(0,16,1,80)
	frame.BackgroundColor3 = Color3.fromRGB(12,12,20) frame.BorderSizePixel = 0 frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,6) fc.Parent = frame
	local fs = Instance.new("UIStroke") fs.Color = data.color or Color3.fromRGB(255,180,80) fs.Thickness = 1.2 fs.Parent = frame
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0,3,1,0) accent.BackgroundColor3 = data.color or Color3.fromRGB(255,180,80)
	accent.BorderSizePixel = 0 accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0,6) ac.Parent = accent
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,-18,0,18) tl.Position = UDim2.new(0,10,0,4) tl.BackgroundTransparency = 1
	tl.Text = data.title tl.TextColor3 = data.color or Color3.fromRGB(255,180,80)
	tl.TextScaled = true tl.Font = Enum.Font.GothamBold tl.TextXAlignment = Enum.TextXAlignment.Left tl.Parent = frame
	local ml = Instance.new("TextLabel")
	ml.Size = UDim2.new(1,-18,0,24) ml.Position = UDim2.new(0,10,0,22) ml.BackgroundTransparency = 1
	ml.Text = data.message ml.TextColor3 = Color3.fromRGB(170,170,200)
	ml.TextScaled = true ml.Font = Enum.Font.Gotham ml.TextXAlignment = Enum.TextXAlignment.Left ml.TextWrapped = true ml.Parent = frame

	TweenService:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,16,1,-68)}):Play()
	task.delay(data.duration or 2.5, function()
		local t = TweenService:Create(frame,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0,16,1,80)})
		t:Play() t.Completed:Wait() sg:Destroy()
		notifActive = false processNotifQueue()
	end)
end

local function notify(title, message, duration, color)
	table.insert(notifQueue, {title=title,message=message,duration=duration or 2.5,color=color})
	processNotifQueue()
end

local function showBotAcceptRequest(botName)
	local sg = Instance.new("ScreenGui")
	sg.Name = "BotConnReq" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,300,0,96) frame.Position = UDim2.new(0,16,1,120)
	frame.BackgroundColor3 = Color3.fromRGB(12,12,20) frame.BorderSizePixel = 0 frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,7) fc.Parent = frame
	local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(100,200,255) fs.Thickness = 1.5 fs.Parent = frame
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0,3,1,0) accent.BackgroundColor3 = Color3.fromRGB(100,200,255)
	accent.BorderSizePixel = 0 accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0,7) ac.Parent = accent

	TweenService:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,16,1,-112)}):Play()

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,-14,0,18) tl.Position = UDim2.new(0,10,0,4) tl.BackgroundTransparency = 1
	tl.Text = "Bot Request" tl.TextColor3 = Color3.fromRGB(100,200,255) tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold tl.TextXAlignment = Enum.TextXAlignment.Left tl.Parent = frame
	local ml = Instance.new("TextLabel")
	ml.Size = UDim2.new(1,-14,0,18) ml.Position = UDim2.new(0,10,0,24) ml.BackgroundTransparency = 1
	ml.Text = botName.." wants you as their operator"
	ml.TextColor3 = Color3.fromRGB(200,200,230) ml.TextScaled = true ml.Font = Enum.Font.Gotham
	ml.TextXAlignment = Enum.TextXAlignment.Left ml.Parent = frame

	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Size = UDim2.new(0,110,0,28) acceptBtn.Position = UDim2.new(0,10,0,62)
	acceptBtn.BackgroundColor3 = Color3.fromRGB(30,120,50) acceptBtn.Text = "Add as Bot"
	acceptBtn.TextColor3 = Color3.fromRGB(255,255,255) acceptBtn.TextScaled = true acceptBtn.Font = Enum.Font.GothamBold acceptBtn.BorderSizePixel = 0 acceptBtn.Parent = frame
	local abc = Instance.new("UICorner") abc.CornerRadius = UDim.new(0,5) abc.Parent = acceptBtn
	local denyBtn = Instance.new("TextButton")
	denyBtn.Size = UDim2.new(0,82,0,28) denyBtn.Position = UDim2.new(0,128,0,62)
	denyBtn.BackgroundColor3 = Color3.fromRGB(140,30,30) denyBtn.Text = "Deny"
	denyBtn.TextColor3 = Color3.fromRGB(255,255,255) denyBtn.TextScaled = true denyBtn.Font = Enum.Font.GothamBold denyBtn.BorderSizePixel = 0 denyBtn.Parent = frame
	local dbc = Instance.new("UICorner") dbc.CornerRadius = UDim.new(0,5) dbc.Parent = denyBtn

	local function dismiss()
		local t = TweenService:Create(frame,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0,16,1,120)})
		t:Play() t.Completed:Wait() sg:Destroy()
	end

	acceptBtn.MouseButton1Click:Connect(function()
		local emptySlot = nil
		for i, bot in ipairs(bots) do if bot.name=="" then emptySlot=i break end end
		if emptySlot then bots[emptySlot].name=botName bots[emptySlot].nick=botName
		else table.insert(bots,{name=botName,nick=botName}) end
		saveBots()
		notify("Bot Added",botName.." added and saved.",3,Color3.fromRGB(80,255,120))
		addToLog("Bot added: "..botName)
		local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if ch then task.wait(0.2) ch:SendAsync("/w "..botName.." .cc accepted") end
		if quickTabGui then quickTabGui:Destroy() createQuickTab() end
		dismiss()
	end)
	denyBtn.MouseButton1Click:Connect(function()
		local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if ch then task.wait(0.2) ch:SendAsync("/w "..botName.." .cc denied") end
		dismiss()
	end)
	task.delay(20, function() if sg.Parent then dismiss() end end)
end

local function parsePrefix(cmd)
	local s = cmd:gsub("^%s+",""):gsub("%s+$","")
	if s:sub(1,2) == ". " then s = "."..s:sub(3) end
	return s
end

local function sendCommandToBot(cmd, botName)
	local now = tick()
	if now - lastSent < COOLDOWN then return end
	lastSent = now
	local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if not ch then return end
	local cleaned = parsePrefix(cmd)
	if useWhisper and botName ~= "" then
		ch:SendAsync("/w "..botName.." "..cleaned)
	else
		ch:SendAsync(cleaned)
	end
	addToLog(cleaned..(botName~="" and " -> "..botName or ""))
end

local function sendCommand(cmd) sendCommandToBot(cmd, getRobotName()) end

local function sendCommandToAll(cmd)
	for _, bot in ipairs(bots) do
		if bot.name ~= "" then
			task.spawn(function() task.wait(0.1) sendCommandToBot(cmd, bot.name) end)
		end
	end
	addToLog("[ALL] "..cmd)
end

local function startLoop(cmd)
	if loopConnection then loopConnection:Disconnect() loopConnection=nil end
	loopCmd = cmd
	loopConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastSent >= COOLDOWN then
			lastSent = now
			local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
			if not ch then return end
			local cleaned = parsePrefix(loopCmd)
			local rn = getRobotName()
			if useWhisper and rn ~= "" then ch:SendAsync("/w "..rn.." "..cleaned)
			else ch:SendAsync(cleaned) end
		end
	end)
	if loopLabelRef then loopLabelRef.Text = "Loop: "..cmd loopLabelRef.TextColor3 = Color3.fromRGB(255,120,120) end
	notify("Loop",cmd,2,Color3.fromRGB(255,120,120))
end

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection=nil end
	loopCmd = nil
	if loopLabelRef then loopLabelRef.Text = "No loop" loopLabelRef.TextColor3 = Color3.fromRGB(120,120,150) end
	notify("Loop","Stopped.",2,Color3.fromRGB(200,200,255))
end

local function startView()
	local rn = getRobotName()
	if rn=="" then notify("View","Set robot name first.",2,Color3.fromRGB(255,180,80)) return end
	local robot = Players:FindFirstChild(rn)
	if not robot or not robot.Character then notify("View","Robot not found.",2,Color3.fromRGB(255,80,80)) return end
	local cam = workspace.CurrentCamera
	savedCameraMode = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	viewingRobot = true
	notify("View","Viewing "..rn,2,Color3.fromRGB(100,180,255))
	viewConnection = RunService.Heartbeat:Connect(function()
		if not viewingRobot then return end
		local r = Players:FindFirstChild(rn)
		if not r or not r.Character then return end
		local rp = r.Character:FindFirstChild("HumanoidRootPart") if not rp then return end
		cam.CFrame = CFrame.new(rp.Position+Vector3.new(0,8,14), rp.Position)
	end)
end

local function stopView()
	viewingRobot = false
	if viewConnection then viewConnection:Disconnect() viewConnection=nil end
	workspace.CurrentCamera.CameraType = savedCameraMode or Enum.CameraType.Custom
	notify("View","Stopped.",2,Color3.fromRGB(100,180,255))
end

local function updateStatusDot()
	if not statusDotRef then return end
	local rn = getRobotName()
	local robot = rn~="" and Players:FindFirstChild(rn)
	local connected = robot~=nil and robot.Character~=nil
	statusDotRef.BackgroundColor3 = connected and Color3.fromRGB(20,80,30) or Color3.fromRGB(80,20,20)
	local nick = getActiveBot().nick
	statusDotRef.Text = connected and ((nick~="" and nick or rn).." - ONLINE") or ((nick~="" and nick or "Bot").." - OFFLINE")
	statusDotRef.TextColor3 = connected and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,80,80)
end

local toggleStates = {}

local COMMAND_CATEGORIES = {
	{
		name = "Movement",
		color = Color3.fromRGB(100,220,100),
		cmds = {
			{label="follow me", alias="flw me", cmd=".follow me"},
			{label="stop", alias="stop", cmd=".stop"},
			{label="jump", alias="jump", cmd=".jump"},
			{label="sit", alias="sit", cmd=".sit"},
			{label="stand", alias="stand", cmd=".stand"},
			{label="tpme", alias="tpme", cmd=".tpme"},
			{label="fling", alias="fling", cmd=".fling"},
			{label="forward", alias="fw", input=true, base=".fw"},
			{label="back", alias="bk", input=true, base=".bk"},
			{label="left", alias="lt", input=true, base=".lt"},
			{label="right", alias="rt", input=true, base=".rt"},
			{label="turnleft", alias="tl", input=true, base=".tl"},
			{label="turnright", alias="tr", input=true, base=".tr"},
			{label="follow", alias="flw", input=true, base=".flw"},
			{label="goto", alias="gt", input=true, base=".gt"},
			{label="orbit", alias="orb", input=true, base=".orb"},
			{label="looptp", alias="ltp", input=true, base=".ltp"},
			{label="lookat", alias="lk", input=true, base=".lk"},
			{label="tp", alias="tp", input=true, base=".tp"},
			{label="patrol", alias="ptr", input=true, base=".ptr"},
		}
	},
	{
		name = "Physics",
		color = Color3.fromRGB(180,100,255),
		cmds = {
			{label="speed", alias="spd", input=true, base=".spd"},
			{label="jumppower", alias="jp", input=true, base=".jp"},
			{label="gravity", alias="grv", input=true, base=".grv"},
			{label="gravityoff", alias="goff", cmd=".gravityoff"},
			{label="gravityreset", alias="grst", cmd=".gravityreset"},
			{label="freeze", alias="frz", toggle=true, on=".frz", off=".ufrz"},
			{label="float", alias="fl", toggle=true, on=".fl on", off=".fl off"},
			{label="noclip", alias="nc", toggle=true, on=".nc on", off=".nc off"},
			{label="spin", alias="spin", toggle=true, on=".spin on", off=".spin off"},
		}
	},
	{
		name = "Appearance",
		color = Color3.fromRGB(255,220,80),
		cmds = {
			{label="invisible", alias="inv", toggle=true, on=".inv on", off=".inv off"},
			{label="godmode", alias="gm", toggle=true, on=".gm on", off=".gm off"},
			{label="bighead", alias="bh", toggle=true, on=".bh on", off=".bh off"},
			{label="headless", alias="hd", toggle=true, on=".hd on", off=".hd off"},
			{label="crouch", alias="cr", toggle=true, on=".cr on", off=".cr off"},
			{label="walkanim", alias="wa", toggle=true, on=".wa on", off=".wa off"},
			{label="transparency", alias="trp", input=true, base=".trp"},
			{label="size", alias="sz", input=true, base=".sz"},
			{label="fov", alias="fov", input=true, base=".fov"},
		}
	},
	{
		name = "Effects",
		color = Color3.fromRGB(255,120,80),
		cmds = {
			{label="glitch", alias="gl", toggle=true, on=".gl on", off=".gl off"},
			{label="ragdoll", alias="rg", toggle=true, on=".rg on", off=".rg off"},
			{label="mirror", alias="mir", toggle=true, on=".mir on", off=".mir off"},
			{label="lockcontrol", alias="lck", toggle=true, on=".lck on", off=".lck off"},
			{label="antiafk", alias="aafk", toggle=true, on=".aafk on", off=".aafk off"},
			{label="conn lock", alias="lcc", toggle=true, on=".lcc on", off=".lcc off"},
			{label="reset", alias="rst", cmd=".reset"},
		}
	},
	{
		name = "Emotes",
		color = Color3.fromRGB(80,220,180),
		cmds = {
			{label="wave", alias="wave", cmd=".wave"},
			{label="laugh", alias="laugh", cmd=".laugh"},
			{label="cheer", alias="cheer", cmd=".cheer"},
			{label="point", alias="point", cmd=".point"},
			{label="dance", alias="dance", cmd=".dance"},
			{label="dance2", alias="dance2", cmd=".dance2"},
			{label="dance3", alias="dance3", cmd=".dance3"},
			{label="emote", alias="e", input=true, base=".e"},
		}
	},
	{
		name = "Info",
		color = Color3.fromRGB(160,160,220),
		cmds = {
			{label="health", alias="hlth", cmd=".health"},
			{label="position", alias="pos", cmd=".pos"},
			{label="rig type", alias="rig", cmd=".rig"},
			{label="operators", alias="ops", cmd=".ops"},
			{label="status", alias="status", cmd=".status"},
			{label="aliases", alias="aliases", cmd=".aliases"},
			{label="unloop", alias="ul", cmd=".unloop"},
			{label="savepos 1", alias="sav 1", cmd=".savepos 1"},
			{label="savepos 2", alias="sav 2", cmd=".savepos 2"},
			{label="savepos 3", alias="sav 3", cmd=".savepos 3"},
			{label="loadpos 1", alias="lod 1", cmd=".loadpos 1"},
			{label="loadpos 2", alias="lod 2", cmd=".loadpos 2"},
			{label="loadpos 3", alias="lod 3", cmd=".loadpos 3"},
			{label="sethealth", alias="hlth", input=true, base=".sethealth"},
			{label="say", alias="say", input=true, base=".say"},
			{label="connect", alias=".c", input=true, base=".c"},
			{label="removeop", alias="rmop", input=true, base=".removeop"},
			{label="loop cmd", alias="loop", input=true, base=".loop"},
		}
	},
}

local activeCategory = 1
local stepPresets = {5,10,20,50}
local botsScrollRef = nil

local function refreshBotsScroll()
	if not botsScrollRef then return end
	for _, child in ipairs(botsScrollRef:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
	for i, bot in ipairs(bots) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,-8,0,32)
		row.BackgroundColor3 = (i==activeBotIndex) and Color3.fromRGB(30,60,30) or Color3.fromRGB(20,20,32)
		row.BorderSizePixel = 0 row.Parent = botsScrollRef
		local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0,5) rc.Parent = row
		if i==activeBotIndex then local rs=Instance.new("UIStroke") rs.Color=Color3.fromRGB(80,200,100) rs.Thickness=1 rs.Parent=row end

		local nickBox = Instance.new("TextBox")
		nickBox.Size = UDim2.new(0,68,0,24) nickBox.Position = UDim2.new(0,4,0,4)
		nickBox.BackgroundColor3 = Color3.fromRGB(18,18,28) nickBox.TextColor3 = Color3.fromRGB(200,200,240)
		nickBox.PlaceholderText = "nick" nickBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
		nickBox.Text = bot.nick nickBox.TextScaled = true nickBox.Font = Enum.Font.Gotham nickBox.BorderSizePixel = 0 nickBox.ClearTextOnFocus = false nickBox.Parent = row
		local nc = Instance.new("UICorner") nc.CornerRadius = UDim.new(0,4) nc.Parent = nickBox
		nickBox:GetPropertyChangedSignal("Text"):Connect(function() bots[i].nick=nickBox.Text saveBots() end)

		local nameBox = Instance.new("TextBox")
		nameBox.Size = UDim2.new(0,88,0,24) nameBox.Position = UDim2.new(0,76,0,4)
		nameBox.BackgroundColor3 = Color3.fromRGB(18,18,28) nameBox.TextColor3 = Color3.fromRGB(220,220,255)
		nameBox.PlaceholderText = "username" nameBox.PlaceholderColor3 = Color3.fromRGB(80,80,110)
		nameBox.Text = bot.name nameBox.TextScaled = true nameBox.Font = Enum.Font.Gotham nameBox.BorderSizePixel = 0 nameBox.ClearTextOnFocus = false nameBox.Parent = row
		local nb = Instance.new("UICorner") nb.CornerRadius = UDim.new(0,4) nb.Parent = nameBox
		nameBox:GetPropertyChangedSignal("Text"):Connect(function() bots[i].name=nameBox.Text saveBots() updateStatusDot() end)

		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0,34,0,24) useBtn.Position = UDim2.new(0,168,0,4)
		useBtn.BackgroundColor3 = (i==activeBotIndex) and Color3.fromRGB(30,100,50) or Color3.fromRGB(40,40,60)
		useBtn.Text = i==activeBotIndex and "ON" or "USE"
		useBtn.TextColor3 = Color3.fromRGB(255,255,255) useBtn.TextScaled = true useBtn.Font = Enum.Font.GothamBold useBtn.BorderSizePixel = 0 useBtn.Parent = row
		local ub = Instance.new("UICorner") ub.CornerRadius = UDim.new(0,4) ub.Parent = useBtn
		useBtn.MouseButton1Click:Connect(function()
			activeBotIndex=i saveBots() updateStatusDot() refreshBotsScroll()
			notify("Active Bot",bot.nick~="" and bot.nick or bot.name,2,Color3.fromRGB(80,200,100))
		end)

		local connBtn = Instance.new("TextButton")
		connBtn.Size = UDim2.new(0,24,0,24) connBtn.Position = UDim2.new(0,206,0,4)
		connBtn.BackgroundColor3 = Color3.fromRGB(30,60,100) connBtn.Text = "C"
		connBtn.TextColor3 = Color3.fromRGB(255,255,255) connBtn.TextScaled = true connBtn.Font = Enum.Font.GothamBold connBtn.BorderSizePixel = 0 connBtn.Parent = row
		local cb = Instance.new("UICorner") cb.CornerRadius = UDim.new(0,4) cb.Parent = connBtn
		connBtn.MouseButton1Click:Connect(function()
			if bot.name~="" then
				local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
				if ch then
					if useWhisper then ch:SendAsync("/w "..bot.name.." .c") else ch:SendAsync(".c") end
					notify("Connecting","Sent to "..bot.name,2,Color3.fromRGB(100,180,255))
				end
			else notify("Error","Enter username first.",2,Color3.fromRGB(255,100,100)) end
		end)
	end
end

local createQuickTab

local function createHelpPage()
	if helpGui then helpGui:Destroy() helpGui=nil end

	local sg = Instance.new("ScreenGui")
	sg.Name = "RobotHelp" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1,0,1,0) overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
	overlay.BackgroundTransparency = 0.5 overlay.BorderSizePixel = 0 overlay.Parent = sg

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0,520,0,620)
	panel.Position = UDim2.new(0.5,-260,0.5,-310)
	panel.BackgroundColor3 = Color3.fromRGB(10,10,16) panel.BorderSizePixel = 0
	panel.Active = true panel.Draggable = true panel.Parent = sg
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,12) pc.Parent = panel
	local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(255,180,80) ps.Thickness = 2 ps.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1,0,0,40) titleBar.BackgroundColor3 = Color3.fromRGB(16,14,22)
	titleBar.BorderSizePixel = 0 titleBar.Parent = panel
	local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0,12) tbc.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1,-50,1,0) titleLbl.Position = UDim2.new(0,16,0,0)
	titleLbl.BackgroundTransparency = 1 titleLbl.Text = "ROBOT CONTROL  /  Help & Reference"
	titleLbl.TextColor3 = Color3.fromRGB(255,180,80) titleLbl.TextScaled = true titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0,28,0,28) closeBtn.Position = UDim2.new(1,-34,0,6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180,40,40) closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255,255,255) closeBtn.TextScaled = true closeBtn.Font = Enum.Font.GothamBold closeBtn.BorderSizePixel = 0 closeBtn.Parent = titleBar
	local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0,5) cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function() sg:Destroy() helpGui=nil end)

	local tokenBar = Instance.new("Frame")
	tokenBar.Size = UDim2.new(1,-32,0,26) tokenBar.Position = UDim2.new(0,16,0,46)
	tokenBar.BackgroundColor3 = Color3.fromRGB(16,14,26) tokenBar.BorderSizePixel = 0 tokenBar.Parent = panel
	local tbc2 = Instance.new("UICorner") tbc2.CornerRadius = UDim.new(0,5) tbc2.Parent = tokenBar
	local tokenLbl = Instance.new("TextLabel")
	tokenLbl.Size = UDim2.new(1,-10,1,0) tokenLbl.Position = UDim2.new(0,8,0,0)
	tokenLbl.BackgroundTransparency = 1 tokenLbl.Text = "Session: "..localPlayer.Name.."  /  "..PLAYER_TOKEN.."  (local only)"
	tokenLbl.TextColor3 = Color3.fromRGB(180,140,60) tokenLbl.TextScaled = true tokenLbl.Font = Enum.Font.GothamBold
	tokenLbl.TextXAlignment = Enum.TextXAlignment.Left tokenLbl.Parent = tokenBar

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1,-16,1,-82) scroll.Position = UDim2.new(0,8,0,78)
	scroll.BackgroundTransparency = 1 scroll.BorderSizePixel = 0 scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255,180,80) scroll.CanvasSize = UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y scroll.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0,7) listLayout.SortOrder = Enum.SortOrder.LayoutOrder listLayout.Parent = scroll
	local lpad = Instance.new("UIPadding")
	lpad.PaddingTop = UDim.new(0,6) lpad.PaddingLeft = UDim.new(0,6) lpad.PaddingRight = UDim.new(0,6) lpad.Parent = scroll

	local sw = 488

	local function addSection(title, color)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0,sw,0,18) lbl.BackgroundTransparency = 1
		lbl.Text = title lbl.TextColor3 = color or Color3.fromRGB(255,180,80)
		lbl.TextScaled = true lbl.Font = Enum.Font.GothamBold lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Parent = scroll
	end

	local function addBlock(content, color)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0,sw,0,1) f.AutomaticSize = Enum.AutomaticSize.Y
		f.BackgroundColor3 = Color3.fromRGB(16,16,26) f.BorderSizePixel = 0 f.Parent = scroll
		local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,6) fc.Parent = f
		local fs = Instance.new("UIStroke") fs.Color = color or Color3.fromRGB(50,50,80) fs.Thickness = 1 fs.Transparency = 0.5 fs.Parent = f
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1,-16,0,0) lbl.Position = UDim2.new(0,10,0,6)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.BackgroundTransparency = 1 lbl.Text = content lbl.TextColor3 = Color3.fromRGB(170,170,200)
		lbl.TextScaled = false lbl.TextSize = 13 lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.TextWrapped = true lbl.Parent = f
		local pad = Instance.new("UIPadding") pad.PaddingBottom = UDim.new(0,6) pad.Parent = f
	end

	addSection("GETTING STARTED", Color3.fromRGB(255,180,80))
	addBlock("1. Run ROBOT script on your alt/bot account.\n2. On main account type .c BotUsername in chat.\n3. Bot gets a popup showing your name - click Accept.\n4. Type .quicktab to open the control panel.\n5. Use .help to open this page anytime.", Color3.fromRGB(255,180,80))

	addSection("CONNECTION", Color3.fromRGB(100,200,255))
	addBlock(".c [name]  —  Send connect request to a bot (they see your name)\n.cc  —  Accept/Deny (handled via popup button)\n.lcc on/off  (lockconn)  —  Lock so no new operators can connect\n.ops  —  List all connected operators on the bot\n.removeop [name]  (rmop)  —  Remove an operator from bot\n.all [cmd]  —  Broadcast a command to every bot at once", Color3.fromRGB(100,200,255))

	addSection("MOVEMENT", Color3.fromRGB(100,220,100))
	addBlock(".follow [name/me]  (flw)  —  Follow a player continuously\n.stop  —  Stop all movement\n.goto [name]  (gt)  —  Walk to player once\n.orbit [name]  (orb)  —  Orbit around a player in circles\n.patrol [n1] [n2]  (ptr)  —  Patrol between players\n.looptp [name]  (ltp)  —  Continuously teleport onto player\n.fw / .bk / .lt / .rt [n]  —  Move directionally n studs\n.tl / .tr [deg]  —  Turn left/right by degrees\n.lookat [name]  (lk)  —  Face a player\n.tp [name or x y z]  —  Teleport to player or coordinates\n.tpme  —  Teleport bot to operator position\n.spin on/off  —  Continuously spin\n.jump  —  Make bot jump", Color3.fromRGB(100,220,100))

	addSection("PHYSICS & WORLD", Color3.fromRGB(180,100,255))
	addBlock(".speed [n]  (spd)  —  Set walk speed. Default 16\n.jumppower [n]  (jp)  —  Set jump power. Default 50\n.gravity [n]  (grv)  —  Set world gravity\n.gravityoff  (goff)  —  Zero gravity\n.gravityreset  (grst)  —  Reset gravity to 196.2\n.float on/off  (fl)  —  Low gravity mode\n.noclip on/off  (nc)  —  Walk through walls\n.freeze  (frz)  /  .unfreeze  (ufrz)  —  Freeze or unfreeze bot\n.fling  —  Launch bot into the air", Color3.fromRGB(180,100,255))

	addSection("APPEARANCE", Color3.fromRGB(255,220,80))
	addBlock(".invisible on/off  (inv)  —  FE invisible\n.transparency [0-1]  (trp)  —  Set body transparency\n.size [n]  (sz)  —  Scale character. 1 = normal\n.bighead on/off  (bh)  —  Large head\n.headless on/off  (hd)  —  Hide head\n.crouch on/off  (cr)  —  Crouch mode\n.walkanim on/off  (wa)  —  Toggle walk animation\n.fov [n]  —  Set field of view 1 to 120", Color3.fromRGB(255,220,80))

	addSection("EFFECTS & CONTROL", Color3.fromRGB(255,120,80))
	addBlock(".godmode on/off  (gm)  —  Disable killbricks nearby\n.glitch on/off  (gl)  —  Glitch movement effect\n.ragdoll on/off  (rg)  —  Ragdoll state\n.mirror on/off  (mir)  —  Copy operator movement\n.lockcontrol on/off  (lck)  —  Disable bot input\n.antiafk on/off  (aafk)  —  Prevent AFK kick\n.reset  (rst)  —  Kill and respawn\n.sethealth [n]  —  Set HP directly", Color3.fromRGB(255,120,80))

	addSection("EMOTES", Color3.fromRGB(80,220,180))
	addBlock(".wave  .laugh  .cheer  .point  .dance  .dance2  .dance3\n.e [name]  —  Play any emote by name", Color3.fromRGB(80,220,180))

	addSection("INFO COMMANDS", Color3.fromRGB(160,160,220))
	addBlock(".health  (hlth)  —  Show current HP\n.pos  —  Show position coordinates\n.rig  —  Show R6 or R15\n.savepos [1/2/3]  (sav)  —  Save position to slot\n.loadpos [1/2/3]  (lod)  —  Return to saved position\n.status  —  Full bot status\n.aliases  —  List all short aliases\n.serverid  —  Show current server ID\n.gameid  —  Show current game name and ID", Color3.fromRGB(160,160,220))

	addSection("CHAT & LOOP", Color3.fromRGB(100,200,150))
	addBlock(".say [text]  —  Bot sends message in public chat\n.loop [cmd]  —  Loop a command on bot side, no chat spam\n.loop [cmd] [interval]  —  Loop with custom interval in seconds\n.unloop  (ul)  —  Stop the current loop\nRight-click any Quick Tab button to start or stop looping it.", Color3.fromRGB(100,200,150))

	addSection("PREFIX & ALIASES", Color3.fromRGB(200,200,255))
	addBlock("Both .cmd and . cmd (dot space) work as prefix.\nWhisper mode: commands sent as private messages, nobody sees them.\nShort aliases are shown on every Quick Tab button as [alias].\nAll aliases: spd sp jp jmp fw bk bw lt rt tl tr flw gt inv gm nc frz ufrz rst lk ltp mir lck sav lod trp sz ul grv goff grst fl bh cr orb ptr hlth hd rg gl aafk wa lcc lockconn", Color3.fromRGB(200,200,255))

	addSection("QUICK TAB GUIDE", Color3.fromRGB(255,160,60))
	addBlock("Type .quicktab to open or close the panel.\nCategories across the top — click to switch.\nLeft-click: send command once.\nRight-click: toggle loop on/off for that command.\nToggle buttons: green = on, grey = off.\nArgument box: type name/number then click [n] buttons.\nBot row: click bot name to switch active bot.\nS = Settings panel.  ? = This help page.", Color3.fromRGB(255,160,60))

	addSection("LEGAL & CREDITS", Color3.fromRGB(150,150,170))
	addBlock("Robot Control Script\nCreated by zumartengge6no10 for personal use.\nPersonal use only. Do not redistribute or claim as your own.\nAll features are client-side on your own character only.\nUse responsibly and within Roblox Terms of Service.\nThe author is not responsible for any account actions taken by Roblox.\n(c) 2025 zumartengge6no10 - All rights reserved.", Color3.fromRGB(150,150,170))

	local closeBottomBtn = Instance.new("TextButton")
	closeBottomBtn.Size = UDim2.new(0,sw,0,32)
	closeBottomBtn.BackgroundColor3 = Color3.fromRGB(255,150,40) closeBottomBtn.Text = "Close Help"
	closeBottomBtn.TextColor3 = Color3.fromRGB(20,10,0) closeBottomBtn.TextScaled = true closeBottomBtn.Font = Enum.Font.GothamBold closeBottomBtn.BorderSizePixel = 0 closeBottomBtn.Parent = scroll
	local clbc = Instance.new("UICorner") clbc.CornerRadius = UDim.new(0,6) clbc.Parent = closeBottomBtn
	closeBottomBtn.MouseButton1Click:Connect(function() sg:Destroy() helpGui=nil end)

	helpGui = sg
end

local function createSettingsGui()
	if settingsGui then settingsGui:Destroy() settingsGui=nil end
	if pingConnection then pingConnection:Disconnect() pingConnection=nil end
	if not settingsVisible then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "SettingsPanel" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local panelW = 260
	local panelH = 600

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0,panelW,0,panelH)
	panel.Position = UDim2.new(1,-(guiWidth+panelW+24),0.5,-(panelH/2))
	panel.BackgroundColor3 = Color3.fromRGB(10,10,16)
	panel.BorderSizePixel = 0 panel.Active = true panel.Draggable = true panel.Parent = sg
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,10) pc.Parent = panel
	local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(100,100,160) ps.Thickness = 1.5 ps.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1,0,0,28) titleBar.BackgroundColor3 = Color3.fromRGB(16,16,26) titleBar.BorderSizePixel = 0 titleBar.Parent = panel
	local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0,10) tbc.Parent = titleBar
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1,-36,1,0) titleLbl.Position = UDim2.new(0,10,0,0) titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "SETTINGS" titleLbl.TextColor3 = Color3.fromRGB(160,160,220) titleLbl.TextScaled = true titleLbl.Font = Enum.Font.GothamBold titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Parent = titleBar
	local closeS = Instance.new("TextButton")
	closeS.Size = UDim2.new(0,22,0,22) closeS.Position = UDim2.new(1,-26,0,3) closeS.BackgroundColor3 = Color3.fromRGB(160,40,40)
	closeS.Text = "X" closeS.TextColor3 = Color3.fromRGB(255,255,255) closeS.TextScaled = true closeS.Font = Enum.Font.GothamBold closeS.BorderSizePixel = 0 closeS.Parent = titleBar
	local csc = Instance.new("UICorner") csc.CornerRadius = UDim.new(0,4) csc.Parent = closeS
	closeS.MouseButton1Click:Connect(function()
		settingsVisible = false
		if pingConnection then pingConnection:Disconnect() pingConnection=nil end
		sg:Destroy() settingsGui=nil
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1,-8,1,-34) scroll.Position = UDim2.new(0,4,0,30)
	scroll.BackgroundTransparency = 1 scroll.BorderSizePixel = 0 scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,160) scroll.CanvasSize = UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y scroll.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0,6) listLayout.SortOrder = Enum.SortOrder.LayoutOrder listLayout.Parent = scroll
	local lpad = Instance.new("UIPadding")
	lpad.PaddingTop = UDim.new(0,6) lpad.PaddingLeft = UDim.new(0,6) lpad.PaddingRight = UDim.new(0,6) lpad.Parent = scroll

	local sw = panelW - 24

	local function sectionLabel(text)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0,sw,0,16) lbl.BackgroundTransparency = 1 lbl.Text = text
		lbl.TextColor3 = Color3.fromRGB(120,120,180) lbl.TextScaled = true lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Parent = scroll
	end

	local function makeSettBtn(text, color, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0,sw,0,26) btn.BackgroundColor3 = color btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255,255,255) btn.TextScaled = true btn.Font = Enum.Font.GothamBold btn.BorderSizePixel = 0 btn.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = btn
		btn.MouseButton1Click:Connect(callback) return btn
	end

	local function makeBox(placeholder, default)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0,sw,0,26) box.BackgroundColor3 = Color3.fromRGB(20,20,32) box.TextColor3 = Color3.fromRGB(220,220,255)
		box.PlaceholderText = placeholder box.PlaceholderColor3 = Color3.fromRGB(80,80,110) box.Text = default or ""
		box.TextScaled = true box.Font = Enum.Font.Gotham box.BorderSizePixel = 0 box.ClearTextOnFocus = false box.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = box
		local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(60,60,100) bs.Thickness = 1 bs.Parent = box
		return box
	end

	local function makeSettToggle(text, initState, onColor, offColor, callback)
		local state = initState
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0,sw,0,26) btn.BackgroundColor3 = state and onColor or offColor
		btn.Text = text..(state and ": ON" or ": OFF") btn.TextColor3 = Color3.fromRGB(255,255,255)
		btn.TextScaled = true btn.Font = Enum.Font.GothamBold btn.BorderSizePixel = 0 btn.Parent = scroll
		local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,5) bc.Parent = btn
		btn.MouseButton1Click:Connect(function()
			state = not state
			btn.BackgroundColor3 = state and onColor or offColor
			btn.Text = text..(state and ": ON" or ": OFF")
			callback(state)
		end) return btn
	end

	local statusDot = Instance.new("TextLabel")
	statusDot.Size = UDim2.new(0,sw,0,26) statusDot.BackgroundColor3 = Color3.fromRGB(80,20,20)
	statusDot.Text = "OFFLINE" statusDot.TextColor3 = Color3.fromRGB(255,80,80)
	statusDot.TextScaled = true statusDot.Font = Enum.Font.GothamBold statusDot.BorderSizePixel = 0 statusDot.Parent = scroll
	local sdc = Instance.new("UICorner") sdc.CornerRadius = UDim.new(0,5) sdc.Parent = statusDot
	statusDotRef = statusDot
	updateStatusDot()

	sectionLabel("Bot Management")
	local botsScroll = Instance.new("ScrollingFrame")
	botsScroll.Size = UDim2.new(0,sw,0,130) botsScroll.BackgroundColor3 = Color3.fromRGB(16,16,24)
	botsScroll.BorderSizePixel = 0 botsScroll.ScrollBarThickness = 3 botsScroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,160)
	botsScroll.CanvasSize = UDim2.new(0,0,0,0) botsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y botsScroll.Parent = scroll
	local bsc = Instance.new("UICorner") bsc.CornerRadius = UDim.new(0,5) bsc.Parent = botsScroll
	local bsL = Instance.new("UIListLayout") bsL.Padding = UDim.new(0,3) bsL.SortOrder = Enum.SortOrder.LayoutOrder bsL.Parent = botsScroll
	local bsPad = Instance.new("UIPadding") bsPad.PaddingTop = UDim.new(0,3) bsPad.PaddingLeft = UDim.new(0,3) bsPad.PaddingRight = UDim.new(0,3) bsPad.Parent = botsScroll
	botsScrollRef = botsScroll
	refreshBotsScroll()
	makeSettBtn("Add Bot Slot", Color3.fromRGB(30,70,30), function()
		table.insert(bots,{name="",nick="Bot "..(#bots+1)}) saveBots() refreshBotsScroll()
	end)

	sectionLabel("Quick Connect")
	local connectBox = makeBox("bot username...")
	makeSettBtn("Send Connect Request", Color3.fromRGB(30,60,100), function()
		local botName = connectBox.Text:gsub("%s","")
		if botName~="" then
			local ch = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
			if ch then
				if useWhisper then ch:SendAsync("/w "..botName.." .c") else ch:SendAsync(".c") end
				notify("Connecting","Sent to "..botName,2,Color3.fromRGB(100,180,255))
			end
		else notify("Error","Enter username.",2,Color3.fromRGB(255,100,100)) end
	end)

	sectionLabel("Quick Send")
	local quickCmdBox = makeBox("e.g. .spd 60")
	makeSettBtn("Send to Active Bot", Color3.fromRGB(50,80,50), function()
		local txt = parsePrefix(quickCmdBox.Text)
		if txt~="" and txt:sub(1,1)=="." then sendCommand(txt) notify("Sent",txt,2,Color3.fromRGB(100,220,100))
		else notify("Error","Start with a dot.",2,Color3.fromRGB(255,100,100)) end
	end)
	makeSettBtn("Send to ALL Bots", Color3.fromRGB(60,40,80), function()
		local txt = parsePrefix(quickCmdBox.Text)
		if txt~="" and txt:sub(1,1)=="." then sendCommandToAll(txt) notify("Broadcast",txt,2,Color3.fromRGB(180,100,255))
		else notify("Error","Start with a dot.",2,Color3.fromRGB(255,100,100)) end
	end)

	sectionLabel("Loop Command")
	local loopCmdBox = makeBox("e.g. .spd 60")
	makeSettBtn("Start Loop", Color3.fromRGB(80,40,100), function()
		local txt = parsePrefix(loopCmdBox.Text)
		if txt~="" and txt:sub(1,1)=="." then startLoop(txt)
		else notify("Error","Start with a dot.",2,Color3.fromRGB(255,100,100)) end
	end)
	makeSettBtn("Stop Loop", Color3.fromRGB(120,40,40), stopLoop)

	sectionLabel("Communication")
	makeSettToggle("Whisper Mode", useWhisper, Color3.fromRGB(30,120,60), Color3.fromRGB(120,40,40), function(state)
		useWhisper = state
		notify("Whisper",state and "On - private" or "Off - public",2,Color3.fromRGB(100,220,100))
	end)

	sectionLabel("View Robot Camera")
	makeSettToggle("View Robot", viewingRobot, Color3.fromRGB(40,80,160), Color3.fromRGB(40,50,80), function(state)
		if state then startView() else stopView() end
	end)

	sectionLabel("Pages")
	makeSettBtn("Open Help Page", Color3.fromRGB(50,60,90), createHelpPage)
	makeSettBtn(quickTabHidden and "Show Quicktab" or "Hide Quicktab", Color3.fromRGB(60,60,80), function()
		if quickTabGui then
			local mf = quickTabGui:FindFirstChildOfClass("Frame")
			if mf then quickTabHidden=not quickTabHidden mf.Visible=not quickTabHidden end
		end
		notify("Quicktab",quickTabHidden and "Hidden." or "Visible.",2,Color3.fromRGB(200,200,255))
		createSettingsGui()
	end)

	sectionLabel("Cooldown (seconds)")
	local coolBox = makeBox("0.8", tostring(COOLDOWN))
	makeSettBtn("Apply", Color3.fromRGB(50,50,90), function()
		local v = tonumber(coolBox.Text)
		if v and v>=0.3 then COOLDOWN=v notify("Cooldown",v.."s",2,Color3.fromRGB(200,200,255))
		else notify("Error","Min 0.3s",2,Color3.fromRGB(255,100,100)) end
	end)

	sectionLabel("GUI Size Presets")
	local sizesFrame = Instance.new("Frame")
	sizesFrame.Size = UDim2.new(0,sw,0,26) sizesFrame.BackgroundTransparency = 1 sizesFrame.Parent = scroll
	local sizePresets = {{"Compact",400,440},{"Default",520,480},{"Large",640,520},{"XL",760,560}}
	local sBtnW = math.floor(sw/#sizePresets) - 3
	for i, s in ipairs(sizePresets) do
		local sb = Instance.new("TextButton")
		sb.Size = UDim2.new(0,sBtnW,0,26) sb.Position = UDim2.new(0,(i-1)*(sBtnW+3),0,0)
		sb.BackgroundColor3 = (guiWidth==s[2]) and Color3.fromRGB(80,80,40) or Color3.fromRGB(40,40,60)
		sb.Text = s[1] sb.TextColor3 = Color3.fromRGB(220,220,255) sb.TextScaled = true sb.Font = Enum.Font.GothamBold sb.BorderSizePixel = 0 sb.Parent = sizesFrame
		local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0,4) sc.Parent = sb
		sb.MouseButton1Click:Connect(function() guiWidth=s[2] guiHeight=s[3] createQuickTab() end)
	end

	pingConnection = RunService.Heartbeat:Connect(updateStatusDot)
	settingsGui = sg
end

createQuickTab = function()
	if quickTabGui then quickTabGui:Destroy() end
	toggleStates = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuickTab" screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling screenGui.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,guiWidth,0,guiHeight)
	frame.Position = UDim2.new(1,-(guiWidth+15),0.5,-(guiHeight/2))
	frame.BackgroundColor3 = Color3.fromRGB(11,11,17) frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0 frame.Active = true frame.Draggable = true
	frame.Visible = not quickTabHidden frame.Parent = screenGui
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,10) corner.Parent = frame
	local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255,180,80) stroke.Thickness = 1.5 stroke.Parent = frame

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1,0,0,28) titleBar.BackgroundColor3 = Color3.fromRGB(16,14,22) titleBar.BorderSizePixel = 0 titleBar.Parent = frame
	local tbc2 = Instance.new("UICorner") tbc2.CornerRadius = UDim.new(0,10) tbc2.Parent = titleBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0,160,1,0) titleLbl.Position = UDim2.new(0,10,0,0) titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "QUICK TAB" titleLbl.TextColor3 = Color3.fromRGB(255,180,80) titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Parent = titleBar

	local settBtn = Instance.new("TextButton")
	settBtn.Size = UDim2.new(0,24,0,24) settBtn.Position = UDim2.new(1,-78,0,2) settBtn.BackgroundColor3 = Color3.fromRGB(40,40,60)
	settBtn.Text = "S" settBtn.TextColor3 = Color3.fromRGB(180,180,220) settBtn.TextScaled = true settBtn.Font = Enum.Font.GothamBold settBtn.BorderSizePixel = 0 settBtn.Parent = titleBar
	local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0,4) sc.Parent = settBtn
	settBtn.MouseButton1Click:Connect(function()
		settingsVisible = not settingsVisible
		settBtn.BackgroundColor3 = settingsVisible and Color3.fromRGB(80,80,40) or Color3.fromRGB(40,40,60)
		createSettingsGui()
	end)

	local helpBtn = Instance.new("TextButton")
	helpBtn.Size = UDim2.new(0,24,0,24) helpBtn.Position = UDim2.new(1,-52,0,2) helpBtn.BackgroundColor3 = Color3.fromRGB(40,60,40)
	helpBtn.Text = "?" helpBtn.TextColor3 = Color3.fromRGB(180,220,180) helpBtn.TextScaled = true helpBtn.Font = Enum.Font.GothamBold helpBtn.BorderSizePixel = 0 helpBtn.Parent = titleBar
	local hc2 = Instance.new("UICorner") hc2.CornerRadius = UDim.new(0,4) hc2.Parent = helpBtn
	helpBtn.MouseButton1Click:Connect(createHelpPage)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0,24,0,24) closeBtn.Position = UDim2.new(1,-26,0,2) closeBtn.BackgroundColor3 = Color3.fromRGB(180,40,40)
	closeBtn.Text = "X" closeBtn.TextColor3 = Color3.fromRGB(255,255,255) closeBtn.TextScaled = true closeBtn.Font = Enum.Font.GothamBold closeBtn.BorderSizePixel = 0 closeBtn.Parent = titleBar
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,4) cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		if settingsGui then settingsGui:Destroy() settingsGui=nil end
		if pingConnection then pingConnection:Disconnect() pingConnection=nil end
		quickTabGui:Destroy() quickTabGui=nil quickTabVisible=false settingsVisible=false
	end)

	local innerW = guiWidth - 16
	local yOff = 34

	local tokenBar = Instance.new("Frame")
	tokenBar.Size = UDim2.new(0,innerW,0,16) tokenBar.Position = UDim2.new(0,8,0,yOff)
	tokenBar.BackgroundColor3 = Color3.fromRGB(16,14,26) tokenBar.BorderSizePixel = 0 tokenBar.Parent = frame
	local tbc3 = Instance.new("UICorner") tbc3.CornerRadius = UDim.new(0,4) tbc3.Parent = tokenBar
	local tokenDisplay = Instance.new("TextLabel")
	tokenDisplay.Size = UDim2.new(1,-8,1,0) tokenDisplay.Position = UDim2.new(0,6,0,0)
	tokenDisplay.BackgroundTransparency = 1 tokenDisplay.Text = localPlayer.Name.."  /  "..PLAYER_TOKEN
	tokenDisplay.TextColor3 = Color3.fromRGB(180,140,60) tokenDisplay.TextScaled = true tokenDisplay.Font = Enum.Font.GothamBold
	tokenDisplay.TextXAlignment = Enum.TextXAlignment.Left tokenDisplay.Parent = tokenBar
	yOff = yOff + 20

	local botRowFrame = Instance.new("Frame")
	botRowFrame.Size = UDim2.new(0,innerW,0,22) botRowFrame.Position = UDim2.new(0,8,0,yOff) botRowFrame.BackgroundTransparency = 1 botRowFrame.Parent = frame
	local botLbl = Instance.new("TextLabel")
	botLbl.Size = UDim2.new(0,30,1,0) botLbl.BackgroundTransparency = 1 botLbl.Text = "Bot:"
	botLbl.TextColor3 = Color3.fromRGB(150,150,180) botLbl.TextScaled = true botLbl.Font = Enum.Font.Gotham
	botLbl.TextXAlignment = Enum.TextXAlignment.Left botLbl.Parent = botRowFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0,120,1,0) statusLabel.Position = UDim2.new(1,-120,0,0)
	statusLabel.BackgroundTransparency = 1 statusLabel.Text = "OFFLINE"
	statusLabel.TextColor3 = Color3.fromRGB(255,80,80) statusLabel.TextScaled = true statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right statusLabel.Parent = botRowFrame
	statusDotRef = statusLabel
	updateStatusDot()

	local hasConnected = false
	for _, bot in ipairs(bots) do if bot.name~="" then hasConnected=true break end end

	if not hasConnected then
		local noBotBtn = Instance.new("TextButton")
		noBotBtn.Size = UDim2.new(0,innerW-160,1,0) noBotBtn.Position = UDim2.new(0,32,0,0)
		noBotBtn.BackgroundColor3 = Color3.fromRGB(60,40,20) noBotBtn.Text = "Connect a bot first - click here"
		noBotBtn.TextColor3 = Color3.fromRGB(255,180,80) noBotBtn.TextScaled = true noBotBtn.Font = Enum.Font.GothamBold noBotBtn.BorderSizePixel = 0 noBotBtn.Parent = botRowFrame
		local nbc = Instance.new("UICorner") nbc.CornerRadius = UDim.new(0,4) nbc.Parent = noBotBtn
		noBotBtn.MouseButton1Click:Connect(function() settingsVisible=true createSettingsGui() end)
	else
		local maxBots = math.floor((innerW-160)/64)
		local botBtnW = math.min(math.floor((innerW-160)/math.max(#bots,1)),60)
		for i, bot in ipairs(bots) do
			if bot.name~="" then
				local bb = Instance.new("TextButton")
				bb.Size = UDim2.new(0,botBtnW,1,0) bb.Position = UDim2.new(0,32+(i-1)*(botBtnW+3),0,0)
				bb.BackgroundColor3 = (i==activeBotIndex) and Color3.fromRGB(30,100,50) or Color3.fromRGB(35,35,55)
				bb.Text = bot.nick~="" and bot.nick or ("B"..i)
				bb.TextColor3 = Color3.fromRGB(220,220,255) bb.TextScaled = true bb.Font = Enum.Font.Gotham bb.BorderSizePixel = 0 bb.Parent = botRowFrame
				local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(0,4) bbc.Parent = bb
				bb.MouseButton1Click:Connect(function()
					activeBotIndex=i saveBots() updateStatusDot() createQuickTab()
				end)
			end
		end
	end
	yOff = yOff + 26

	local argInput = Instance.new("TextBox")
	argInput.Size = UDim2.new(0,innerW,0,20) argInput.Position = UDim2.new(0,8,0,yOff)
	argInput.BackgroundColor3 = Color3.fromRGB(20,20,32) argInput.TextColor3 = Color3.fromRGB(220,220,255)
	argInput.PlaceholderText = "argument / name / value..." argInput.PlaceholderColor3 = Color3.fromRGB(80,80,110)
	argInput.Text = "" argInput.TextScaled = true argInput.Font = Enum.Font.Gotham argInput.BorderSizePixel = 0
	argInput.ClearTextOnFocus = false argInput.Parent = frame
	local aic = Instance.new("UICorner") aic.CornerRadius = UDim.new(0,4) aic.Parent = argInput
	local ais = Instance.new("UIStroke") ais.Color = Color3.fromRGB(60,60,100) ais.Thickness = 1 ais.Parent = argInput
	yOff = yOff + 24

	local stepFrame = Instance.new("Frame")
	stepFrame.Size = UDim2.new(0,innerW,0,18) stepFrame.Position = UDim2.new(0,8,0,yOff) stepFrame.BackgroundTransparency = 1 stepFrame.Parent = frame
	local stepLbl = Instance.new("TextLabel")
	stepLbl.Size = UDim2.new(0,28,1,0) stepLbl.BackgroundTransparency = 1 stepLbl.Text = "Stp:"
	stepLbl.TextColor3 = Color3.fromRGB(150,150,180) stepLbl.TextScaled = true stepLbl.Font = Enum.Font.Gotham stepLbl.TextXAlignment = Enum.TextXAlignment.Left stepLbl.Parent = stepFrame
	local availW = innerW-32
	local btnW2 = math.floor(availW/#stepPresets)-2
	for i, val in ipairs(stepPresets) do
		local pb = Instance.new("TextButton")
		pb.Size = UDim2.new(0,btnW2,1,0) pb.Position = UDim2.new(0,30+(i-1)*(btnW2+2),0,0)
		pb.BackgroundColor3 = Color3.fromRGB(35,35,55) pb.TextColor3 = Color3.fromRGB(200,200,240)
		pb.Text = tostring(val) pb.TextScaled = true pb.Font = Enum.Font.Gotham pb.BorderSizePixel = 0 pb.Parent = stepFrame
		local pc2 = Instance.new("UICorner") pc2.CornerRadius = UDim.new(0,3) pc2.Parent = pb
		pb.MouseButton1Click:Connect(function() sendCommand(".fw "..val) end)
	end
	yOff = yOff + 22

	local loopFrame = Instance.new("Frame")
	loopFrame.Size = UDim2.new(0,innerW,0,18) loopFrame.Position = UDim2.new(0,8,0,yOff) loopFrame.BackgroundTransparency = 1 loopFrame.Parent = frame
	local loopLabel = Instance.new("TextLabel")
	loopLabel.Size = UDim2.new(1,-62,1,0) loopLabel.BackgroundTransparency = 1
	loopLabel.Text = loopCmd and ("Loop: "..loopCmd) or "No loop"
	loopLabel.TextColor3 = loopCmd and Color3.fromRGB(255,120,120) or Color3.fromRGB(120,120,150)
	loopLabel.TextScaled = true loopLabel.Font = Enum.Font.Gotham loopLabel.TextXAlignment = Enum.TextXAlignment.Left loopLabel.Parent = loopFrame
	loopLabelRef = loopLabel
	local stopLoopBtn = Instance.new("TextButton")
	stopLoopBtn.Size = UDim2.new(0,58,1,0) stopLoopBtn.Position = UDim2.new(1,-58,0,0) stopLoopBtn.BackgroundColor3 = Color3.fromRGB(140,40,40)
	stopLoopBtn.Text = "Unloop" stopLoopBtn.TextColor3 = Color3.fromRGB(255,255,255) stopLoopBtn.TextScaled = true stopLoopBtn.Font = Enum.Font.Gotham stopLoopBtn.BorderSizePixel = 0 stopLoopBtn.Parent = loopFrame
	local slc = Instance.new("UICorner") slc.CornerRadius = UDim.new(0,4) slc.Parent = stopLoopBtn
	stopLoopBtn.MouseButton1Click:Connect(stopLoop)
	yOff = yOff + 22

	local catBarFrame = Instance.new("Frame")
	catBarFrame.Size = UDim2.new(0,innerW,0,22) catBarFrame.Position = UDim2.new(0,8,0,yOff) catBarFrame.BackgroundTransparency = 1 catBarFrame.Parent = frame
	local catBtnW = math.floor(innerW / #COMMAND_CATEGORIES) - 2
	local catBtns = {}
	for i, cat in ipairs(COMMAND_CATEGORIES) do
		local cb = Instance.new("TextButton")
		cb.Size = UDim2.new(0,catBtnW,1,0) cb.Position = UDim2.new(0,(i-1)*(catBtnW+2),0,0)
		cb.BackgroundColor3 = (i==activeCategory) and Color3.fromRGB(30,30,50) or Color3.fromRGB(18,18,28)
		cb.Text = cat.name cb.TextColor3 = (i==activeCategory) and cat.color or Color3.fromRGB(100,100,130)
		cb.TextScaled = true cb.Font = Enum.Font.GothamBold cb.BorderSizePixel = 0 cb.Parent = catBarFrame
		local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0,4) cbc.Parent = cb
		if i==activeCategory then local cs=Instance.new("UIStroke") cs.Color=cat.color cs.Thickness=1 cs.Parent=cb end
		catBtns[i] = cb
	end
	yOff = yOff + 26

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0,innerW,0,1) divider.Position = UDim2.new(0,8,0,yOff)
	divider.BackgroundColor3 = Color3.fromRGB(255,180,80) divider.BackgroundTransparency = 0.7 divider.BorderSizePixel = 0 divider.Parent = frame
	yOff = yOff + 4

	local cmdAreaH = guiHeight - yOff - 6
	local cmdScrollFrame = Instance.new("ScrollingFrame")
	cmdScrollFrame.Size = UDim2.new(0,innerW,0,cmdAreaH) cmdScrollFrame.Position = UDim2.new(0,8,0,yOff)
	cmdScrollFrame.BackgroundTransparency = 1 cmdScrollFrame.BorderSizePixel = 0 cmdScrollFrame.ScrollBarThickness = 3
	cmdScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255,180,80) cmdScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
	cmdScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y cmdScrollFrame.Parent = frame

	local cellW = math.floor((innerW-6)/4)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0,cellW,0,26) gridLayout.CellPadding = UDim2.new(0,3,0,3) gridLayout.SortOrder = Enum.SortOrder.LayoutOrder gridLayout.Parent = cmdScrollFrame
	local gpad = Instance.new("UIPadding") gpad.PaddingTop = UDim.new(0,3) gpad.PaddingLeft = UDim.new(0,0) gpad.Parent = cmdScrollFrame

	local cmdButtons = {}

	local function populateCategory(catIndex)
		for _, child in ipairs(cmdScrollFrame:GetChildren()) do
			if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then child:Destroy() end
		end
		toggleStates = {}

		local cat = COMMAND_CATEGORIES[catIndex]
		if not cat then return end

		for j, catBtnRef in ipairs(catBtns) do
			catBtnRef.BackgroundColor3 = (j==catIndex) and Color3.fromRGB(30,30,50) or Color3.fromRGB(18,18,28)
			catBtnRef.TextColor3 = (j==catIndex) and COMMAND_CATEGORIES[j].color or Color3.fromRGB(100,100,130)
			for _, child in ipairs(catBtnRef:GetChildren()) do
				if child:IsA("UIStroke") then child:Destroy() end
			end
			if j==catIndex then local cs=Instance.new("UIStroke") cs.Color=COMMAND_CATEGORIES[j].color cs.Thickness=1 cs.Parent=catBtnRef end
		end

		for i, data in ipairs(cat.cmds) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0,cellW,0,26) btn.BorderSizePixel = 0 btn.AutoButtonColor = true btn.Parent = cmdScrollFrame
			local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,4) bc.Parent = btn
			local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(50,50,80) bs.Thickness = 1 bs.Parent = btn

			local displayText = data.label.."\n["..data.alias.."]"
			btn.Text = displayText btn.TextScaled = false btn.TextSize = 10 btn.Font = Enum.Font.Gotham

			if data.toggle then
				toggleStates[i] = false
				btn.BackgroundColor3 = Color3.fromRGB(40,40,58) btn.TextColor3 = Color3.fromRGB(160,160,190)
				btn.MouseButton1Click:Connect(function()
					toggleStates[i] = not toggleStates[i]
					local state = toggleStates[i]
					local cmd = state and data.on or data.off
					btn.BackgroundColor3 = state and Color3.fromRGB(25,90,45) or Color3.fromRGB(40,40,58)
					btn.TextColor3 = state and Color3.fromRGB(80,230,130) or Color3.fromRGB(160,160,190)
					sendCommand(cmd)
				end)
			else
				btn.BackgroundColor3 = Color3.fromRGB(22,22,38) btn.TextColor3 = Color3.fromRGB(200,200,240)
				btn.MouseButton1Click:Connect(function()
					local full = ""
					if data.cmd then full = data.cmd
					elseif data.input then
						local arg = argInput.Text
						if arg=="" then notify("Input","Type argument first.",2,Color3.fromRGB(255,180,80)) return end
						full = data.base.." "..arg
					end
					if full=="" then return end
					sendCommand(full)
				end)
				btn.MouseButton2Click:Connect(function()
					local full = ""
					if data.cmd then full = data.cmd
					elseif data.input then
						local arg = argInput.Text
						if arg=="" then notify("Input","Type argument first.",2,Color3.fromRGB(255,180,80)) return end
						full = data.base.." "..arg
					end
					if full=="" then return end
					if loopCmd then stopLoop() else startLoop(full) end
				end)
			end
		end
	end

	for i, cat in ipairs(COMMAND_CATEGORIES) do
		catBtns[i].MouseButton1Click:Connect(function()
			activeCategory = i
			populateCategory(i)
		end)
	end

	populateCategory(activeCategory)

	local logPanel = Instance.new("Frame")
	logPanel.Size = UDim2.new(0,innerW,0,0)
	logPanel.Position = UDim2.new(0,8,1,-4)
	logPanel.BackgroundColor3 = Color3.fromRGB(10,10,16) logPanel.BorderSizePixel = 0 logPanel.ClipsDescendants = true logPanel.Parent = frame
	local lpc = Instance.new("UICorner") lpc.CornerRadius = UDim.new(0,6) lpc.Parent = logPanel
	local lps = Instance.new("UIStroke") lps.Color = Color3.fromRGB(50,50,80) lps.Thickness = 1 lps.Parent = logPanel

	local logToggleBtn = Instance.new("TextButton")
	logToggleBtn.Size = UDim2.new(0,80,0,16) logToggleBtn.Position = UDim2.new(0,8,1,-20)
	logToggleBtn.BackgroundColor3 = Color3.fromRGB(20,20,32) logToggleBtn.Text = "Log"
	logToggleBtn.TextColor3 = Color3.fromRGB(120,120,160) logToggleBtn.TextScaled = true logToggleBtn.Font = Enum.Font.Gotham logToggleBtn.BorderSizePixel = 0 logToggleBtn.Parent = frame
	local ltbc = Instance.new("UICorner") ltbc.CornerRadius = UDim.new(0,4) ltbc.Parent = logToggleBtn
	local logOpen = false

	local logScroll = Instance.new("ScrollingFrame")
	logScroll.Size = UDim2.new(1,-8,1,-4) logScroll.Position = UDim2.new(0,4,0,2)
	logScroll.BackgroundTransparency = 1 logScroll.BorderSizePixel = 0 logScroll.ScrollBarThickness = 2
	logScroll.ScrollBarImageColor3 = Color3.fromRGB(80,80,120) logScroll.CanvasSize = UDim2.new(0,0,0,0)
	logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y logScroll.Parent = logPanel
	local logLayout = Instance.new("UIListLayout") logLayout.Padding = UDim.new(0,1) logLayout.SortOrder = Enum.SortOrder.LayoutOrder logLayout.Parent = logScroll
	logScrollRef = logScroll

	logToggleBtn.MouseButton1Click:Connect(function()
		logOpen = not logOpen
		TweenService:Create(logPanel,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(0,innerW,0,logOpen and 80 or 0)}):Play()
		TweenService:Create(logPanel,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,8,1,logOpen and -88 or -4)}):Play()
		logToggleBtn.TextColor3 = logOpen and Color3.fromRGB(180,180,255) or Color3.fromRGB(120,120,160)
	end)

	addToLog("QuickTab opened")

	quickTabGui = screenGui
	quickTabVisible = true
end

local function handleChatMessage(message, player)
	local cleaned = message
	if cleaned:lower():sub(1,3)=="/w " then local s=cleaned:find(" ",4) if s then cleaned=cleaned:sub(s+1) end end
	cleaned = parsePrefix(cleaned)
	if cleaned:lower():sub(1,2)==".c" then
		local parts={} for w in cleaned:sub(2):gmatch("%S+") do table.insert(parts,w) end
		local rc = parts[1] and parts[1]:lower()
		if rc=="cc" then
			local response = parts[2] and parts[2]:lower()
			if response=="accepted" then
				notify("Connected",player.Name.." accepted.",3,Color3.fromRGB(80,255,120))
				addToLog("Connected: "..player.Name)
			elseif response=="denied" then
				notify("Denied",player.Name.." denied.",3,Color3.fromRGB(255,80,80))
			end
			return
		end
		if rc=="c" then showBotAcceptRequest(player.Name) return end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message) handleChatMessage(message,player) end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message) handleChatMessage(message,player) end)
end

localPlayer.Chatted:Connect(function(message)
	local parsed = parsePrefix(message)
	local lower = parsed:lower()
	if lower==".quicktab" then
		if quickTabVisible then
			if settingsGui then settingsGui:Destroy() settingsGui=nil end
			if pingConnection then pingConnection:Disconnect() pingConnection=nil end
			if quickTabGui then quickTabGui:Destroy() quickTabGui=nil end
			quickTabVisible=false settingsVisible=false
		else
			createQuickTab()
		end
	elseif lower==".help" then
		createHelpPage()
	elseif lower:sub(1,5)==".all " then
		local cmd = parsed:sub(6)
		if cmd~="" then sendCommandToAll(cmd) end
	end
end)

if not hasSeenLanding then
	localPlayer:SetAttribute(SEEN_KEY, true)
	task.wait(1)
	createHelpPage()
	notify("Operator Ready","Type .quicktab to open panel",4,Color3.fromRGB(255,180,80))
else
	notify("Operator Ready",".quicktab  /  "..PLAYER_TOKEN,4,Color3.fromRGB(255,180,80))
end
