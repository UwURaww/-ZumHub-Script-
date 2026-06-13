local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local OPERATORS = {}
local pendingRequests = {}
local connectionLocked = false

local following = nil
local followConnection = nil
local speedValue = 16
local jumpValue = 50
local noclipEnabled = false
local godModeEnabled = false
local loopConnection = nil
local loopCmd = nil
local lastLoopSent = 0
local controlLocked = false
local mirrorConnection = nil
local mirrorEnabled = false
local antiAFKConnection = nil
local glitchConnection = nil
local savedPositions = {}
local spinEnabled = false

local OPS_FILE = "robot_operators.txt"
local OPS_ATTR = "RobotOps_v6"

local function saveOperators()
	local data = table.concat(OPERATORS, "\n")
	pcall(function() writefile(OPS_FILE, data) end)
	pcall(function() localPlayer:SetAttribute(OPS_ATTR, table.concat(OPERATORS, ";;")) end)
end

local function loadOperators()
	OPERATORS = {}
	local ok, data = pcall(function() return readfile(OPS_FILE) end)
	if ok and data and data ~= "" then
		for line in data:gmatch("[^\n]+") do
			if line ~= "" then table.insert(OPERATORS, line) end
		end
		if #OPERATORS > 0 then return end
	end
	local raw = pcall(function() return localPlayer:GetAttribute(OPS_ATTR) end) and localPlayer:GetAttribute(OPS_ATTR)
	if raw and raw ~= "" then
		for _, name in ipairs(raw:split(";;")) do
			if name ~= "" then table.insert(OPERATORS, name) end
		end
	end
end

loadOperators()

local function isOperator(name)
	for _, op in ipairs(OPERATORS) do
		if op:lower() == name:lower() then return true end
	end
	return false
end

local notifQueue = {}
local notifActive = false

local function processNotifQueue()
	if notifActive or #notifQueue == 0 then return end
	notifActive = true
	local data = table.remove(notifQueue, 1)

	local sg = Instance.new("ScreenGui")
	sg.Name = "RobotNotif" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,260,0,52) frame.Position = UDim2.new(0,16,1,80)
	frame.BackgroundColor3 = Color3.fromRGB(12,12,20) frame.BorderSizePixel = 0 frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,6) fc.Parent = frame
	local fs = Instance.new("UIStroke") fs.Color = data.color or Color3.fromRGB(100,200,255) fs.Thickness = 1.2 fs.Parent = frame
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0,3,1,0) accent.BackgroundColor3 = data.color or Color3.fromRGB(100,200,255)
	accent.BorderSizePixel = 0 accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0,6) ac.Parent = accent
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,-18,0,18) tl.Position = UDim2.new(0,10,0,4) tl.BackgroundTransparency = 1
	tl.Text = data.title tl.TextColor3 = data.color or Color3.fromRGB(100,200,255)
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

local function showConnectionRequest(requesterName)
	if connectionLocked then
		local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if g then task.wait(0.2) g:SendAsync("/w "..requesterName.." .cc denied") end
		notify("Locked", requesterName.." auto-denied.", 3, Color3.fromRGB(255,80,80))
		pendingRequests[requesterName] = nil
		return
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "RobotConnReq" sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,300,0,90) frame.Position = UDim2.new(0,16,1,110)
	frame.BackgroundColor3 = Color3.fromRGB(12,12,20) frame.BorderSizePixel = 0 frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0,7) fc.Parent = frame
	local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(255,180,80) fs.Thickness = 1.5 fs.Parent = frame
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0,3,1,0) accent.BackgroundColor3 = Color3.fromRGB(255,180,80)
	accent.BorderSizePixel = 0 accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0,7) ac.Parent = accent

	TweenService:Create(frame,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,16,1,-106)}):Play()

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1,-14,0,18) tl.Position = UDim2.new(0,10,0,4) tl.BackgroundTransparency = 1
	tl.Text = "Operator Request" tl.TextColor3 = Color3.fromRGB(255,180,80) tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold tl.TextXAlignment = Enum.TextXAlignment.Left tl.Parent = frame
	local ml = Instance.new("TextLabel")
	ml.Size = UDim2.new(1,-14,0,18) ml.Position = UDim2.new(0,10,0,24) ml.BackgroundTransparency = 1
	ml.Text = requesterName.." wants to control this robot"
	ml.TextColor3 = Color3.fromRGB(200,200,230) ml.TextScaled = true ml.Font = Enum.Font.Gotham
	ml.TextXAlignment = Enum.TextXAlignment.Left ml.Parent = frame

	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Size = UDim2.new(0,110,0,26) acceptBtn.Position = UDim2.new(0,10,0,58)
	acceptBtn.BackgroundColor3 = Color3.fromRGB(30,120,50) acceptBtn.Text = "Accept"
	acceptBtn.TextColor3 = Color3.fromRGB(255,255,255) acceptBtn.TextScaled = true acceptBtn.Font = Enum.Font.GothamBold acceptBtn.BorderSizePixel = 0 acceptBtn.Parent = frame
	local abc = Instance.new("UICorner") abc.CornerRadius = UDim.new(0,5) abc.Parent = acceptBtn
	local denyBtn = Instance.new("TextButton")
	denyBtn.Size = UDim2.new(0,90,0,26) denyBtn.Position = UDim2.new(0,126,0,58)
	denyBtn.BackgroundColor3 = Color3.fromRGB(140,30,30) denyBtn.Text = "Deny"
	denyBtn.TextColor3 = Color3.fromRGB(255,255,255) denyBtn.TextScaled = true denyBtn.Font = Enum.Font.GothamBold denyBtn.BorderSizePixel = 0 denyBtn.Parent = frame
	local dbc = Instance.new("UICorner") dbc.CornerRadius = UDim.new(0,5) dbc.Parent = denyBtn

	local function dismiss()
		local t = TweenService:Create(frame,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0,16,1,110)})
		t:Play() t.Completed:Wait() sg:Destroy() pendingRequests[requesterName] = nil
	end

	acceptBtn.MouseButton1Click:Connect(function()
		table.insert(OPERATORS, requesterName) saveOperators()
		notify("Connected", requesterName.." added as operator.", 3, Color3.fromRGB(80,255,120))
		local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if g then task.wait(0.2) g:SendAsync("/w "..requesterName.." .cc accepted") end
		dismiss()
	end)
	denyBtn.MouseButton1Click:Connect(function()
		notify("Denied", requesterName.." was denied.", 2, Color3.fromRGB(255,80,80))
		local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if g then task.wait(0.2) g:SendAsync("/w "..requesterName.." .cc denied") end
		dismiss()
	end)
	task.delay(20, function() if sg.Parent then dismiss() end end)
end

local function stopFollowing()
	following = nil
	if followConnection then followConnection:Disconnect() followConnection = nil end
end

local function findPlayer(name)
	if name == "me" then
		local t = Players:FindFirstChild(OPERATORS[1] or "")
		if t then return t end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name:lower(), 1, true) or p.DisplayName:lower():find(name:lower(), 1, true) then return p end
	end
	return nil
end

local function parseCommand(raw)
	local s = raw:gsub("^%s+",""):gsub("%s+$","")
	if s:sub(1,2) == ". " then s = "."..s:sub(3) end
	return s
end

RunService.Heartbeat:Connect(function()
	local char = localPlayer.Character if not char then return end
	if noclipEnabled then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end
	if godModeEnabled then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local parts = workspace:GetPartBoundsInRadius(root.Position, 10)
			for _, part in ipairs(parts) do if part.CanTouch then part.CanTouch = false end end
		end
	end
	if spinEnabled then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(4), 0) end
	end
end)

local function lockControl(enabled)
	controlLocked = enabled
	local ok, PlayerModule = pcall(function() return require(localPlayer.PlayerScripts:WaitForChild("PlayerModule")) end)
	if ok and PlayerModule then
		local controls = PlayerModule:GetControls()
		pcall(function() if enabled then controls:Disable() else controls:Enable() end end)
	end
	local char = localPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = enabled and 0 or speedValue hum.JumpPower = enabled and 0 or jumpValue end
	end
	notify(enabled and "Control Locked" or "Control Unlocked", enabled and "Movement disabled." or "Movement enabled.", 2, enabled and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,255,120))
end

local function startMirror()
	if mirrorConnection then mirrorConnection:Disconnect() mirrorConnection = nil end
	local operator = OPERATORS[1] and findPlayer(OPERATORS[1])
	if not operator then notify("Mirror", "No operator found.", 2, Color3.fromRGB(255,180,80)) return end
	mirrorEnabled = true
	mirrorConnection = RunService.Heartbeat:Connect(function()
		if not mirrorEnabled then return end
		local opChar = operator.Character local myChar = localPlayer.Character
		if not opChar or not myChar then return end
		local opRoot = opChar:FindFirstChild("HumanoidRootPart") local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local opHum = opChar:FindFirstChildOfClass("Humanoid") local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if not opRoot or not myRoot or not opHum or not myHum then return end
		myHum.WalkSpeed = opHum.WalkSpeed myHum.JumpPower = opHum.JumpPower
		if opHum.Jump then myHum.Jump = true end
		local opVel = opRoot.AssemblyLinearVelocity
		if opVel.Magnitude > 1 then myHum:MoveTo(myRoot.Position + Vector3.new(opVel.X,0,opVel.Z).Unit * 3) end
		local look = opRoot.CFrame.LookVector
		myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.lookAt(Vector3.new(0,0,0), Vector3.new(look.X,0,look.Z))
	end)
	notify("Mirror", "On", 2, Color3.fromRGB(180,100,255))
end

local function stopMirror()
	mirrorEnabled = false
	if mirrorConnection then mirrorConnection:Disconnect() mirrorConnection = nil end
	notify("Mirror", "Off", 2, Color3.fromRGB(180,100,255))
end

local function followPlayer(targetName)
	stopFollowing()
	local target = findPlayer(targetName)
	if not target then notify("Follow", "Not found.", 2, Color3.fromRGB(255,100,100)) return end
	following = target
	notify("Follow", "Following "..target.Name, 2, Color3.fromRGB(100,200,255))
	followConnection = RunService.Heartbeat:Connect(function()
		if not following then return end
		local tc = following.Character local mc = localPlayer.Character
		if not mc or not tc then return end
		local mr = mc:FindFirstChild("HumanoidRootPart") local tr = tc:FindFirstChild("HumanoidRootPart")
		local mh = mc:FindFirstChildOfClass("Humanoid")
		if not mr or not tr or not mh then return end
		local dist = (mr.Position - tr.Position).Magnitude
		if dist > 5 then mh:MoveTo(tr.Position - (tr.Position - mr.Position).Unit * 4)
		else mh:MoveTo(mr.Position) end
	end)
end

local function goTo(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local tr = target.Character:FindFirstChild("HumanoidRootPart")
	local mc = localPlayer.Character if not mc or not tr then return end
	local mh = mc:FindFirstChildOfClass("Humanoid")
	if mh then mh:MoveTo(tr.Position) end
end

local function walkToCoords(x, y, z)
	local mc = localPlayer.Character if not mc then return end
	local mh = mc:FindFirstChildOfClass("Humanoid")
	if mh then mh:MoveTo(Vector3.new(x, y, z)) end
end

local function patrol(names)
	stopFollowing()
	local targets = {}
	for _, name in ipairs(names) do local p = findPlayer(name) if p then table.insert(targets, p) end end
	if #targets == 0 then return end
	following = targets[1]
	local index = 1 local cooldown = false
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or cooldown then return end
		local target = targets[index]
		if not target or not target.Character then return end
		local mc = localPlayer.Character if not mc then return end
		local mr = mc:FindFirstChild("HumanoidRootPart")
		local tr = target.Character:FindFirstChild("HumanoidRootPart")
		local mh = mc:FindFirstChildOfClass("Humanoid")
		if not mr or not tr or not mh then return end
		local dist = (mr.Position - tr.Position).Magnitude
		if dist <= 5 then cooldown = true index = (index % #targets) + 1 task.delay(1, function() cooldown = false end)
		else mh:MoveTo(tr.Position - (tr.Position - mr.Position).Unit * 4) end
	end)
end

local function loopTp(targetName)
	stopFollowing()
	local target = findPlayer(targetName) if not target then return end
	following = target
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or not following.Character then stopFollowing() return end
		local mc = localPlayer.Character local tc = following.Character
		if not mc or not tc then return end
		local mr = mc:FindFirstChild("HumanoidRootPart") local tr = tc:FindFirstChild("HumanoidRootPart")
		if mr and tr then mr.CFrame = tr.CFrame + Vector3.new(3,0,0) end
	end)
end

local function orbit(targetName)
	stopFollowing()
	local target = findPlayer(targetName) if not target then return end
	following = target
	local angle = 0
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or not following.Character then stopFollowing() return end
		local tc = following.Character local mc = localPlayer.Character
		if not mc or not tc then return end
		local tr = tc:FindFirstChild("HumanoidRootPart") local mr = mc:FindFirstChild("HumanoidRootPart")
		local mh = mc:FindFirstChildOfClass("Humanoid")
		if not tr or not mr or not mh then return end
		angle = angle + 0.02
		mh:MoveTo(Vector3.new(tr.Position.X+math.cos(angle)*8, tr.Position.Y, tr.Position.Z+math.sin(angle)*8))
	end)
end

local function setSpeed(n)
	local char = localPlayer.Character if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = n speedValue = n end
end

local function setJump(n)
	local char = localPlayer.Character if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = n jumpValue = n end
end

local function setNoclip(enabled)
	noclipEnabled = enabled
	if not enabled then
		local char = localPlayer.Character
		if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
	end
	notify("Noclip", enabled and "On" or "Off", 2, Color3.fromRGB(100,180,255))
end

local function freezePlayer(enabled)
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if enabled then hum.WalkSpeed=0 hum.JumpPower=0 root.Anchored=true
	else hum.WalkSpeed=speedValue hum.JumpPower=jumpValue root.Anchored=false end
end

local function tpToPlayer(name)
	local t = findPlayer(name) if not t or not t.Character then return end
	local mc = localPlayer.Character if not mc then return end
	local mr = mc:FindFirstChild("HumanoidRootPart") local tr = t.Character:FindFirstChild("HumanoidRootPart")
	if mr and tr then mr.CFrame = tr.CFrame + Vector3.new(3,0,0) end
end

local function tpToCoords(x,y,z)
	local mc = localPlayer.Character if not mc then return end
	local mr = mc:FindFirstChild("HumanoidRootPart")
	if mr then mr.CFrame = CFrame.new(x,y,z) end
end

local function setInvisibleFE(enabled)
	if enabled then loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-fe-invisible-OPEN-SOURCE-53560"))()
	else
		local char = localPlayer.Character if not char then return end
		for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency=0 end end
	end
	notify("Invisible", enabled and "On" or "Off", 2, Color3.fromRGB(180,180,255))
end

local function setGodMode(enabled)
	godModeEnabled = enabled
	notify("Godmode", enabled and "On" or "Off", 2, Color3.fromRGB(255,220,80))
end

local function moveDir(dir, studs)
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local cf = root.CFrame local t
	if dir=="forward" then t=cf*CFrame.new(0,0,-(studs or 10))
	elseif dir=="back" then t=cf*CFrame.new(0,0,(studs or 10))
	elseif dir=="left" then t=cf*CFrame.new(-(studs or 10),0,0)
	elseif dir=="right" then t=cf*CFrame.new((studs or 10),0,0) end
	if t then hum:MoveTo(t.Position) end
end

local function doJump()
	local char = localPlayer.Character if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Jump = true end
end

local function turnDir(dir, amount)
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") if not root then return end
	local angle = math.rad(amount or 90)
	if dir=="left" then root.CFrame = root.CFrame * CFrame.Angles(0,angle,0)
	elseif dir=="right" then root.CFrame = root.CFrame * CFrame.Angles(0,-angle,0) end
end

local function lookAt(name)
	local t = findPlayer(name) if not t or not t.Character then return end
	local mc = localPlayer.Character if not mc then return end
	local mr = mc:FindFirstChild("HumanoidRootPart") local tr = t.Character:FindFirstChild("HumanoidRootPart")
	if mr and tr then mr.CFrame = CFrame.lookAt(mr.Position, tr.Position) end
end

local function setSpin(e) spinEnabled = e end

local function fling()
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.new(math.random(-100,100),200,math.random(-100,100)) end
end

local function setGravity(n) workspace.Gravity = n end
local function floatMode(e) if e then workspace.Gravity=5 else workspace.Gravity=196.2 end end
local function bigHead(e) local char=localPlayer.Character if not char then return end local head=char:FindFirstChild("Head") if head then head.Size=e and Vector3.new(4,4,4) or Vector3.new(2,1,1) end end
local function crouchMode(e) local char=localPlayer.Character if not char then return end local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.HipHeight=e and 0.5 or 2 end end
local function setTransparency(n) local char=localPlayer.Character if not char then return end for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency=n end end end
local function setSize(n) local char=localPlayer.Character if not char then return end local hum=char:FindFirstChildOfClass("Humanoid") if not hum then return end pcall(function() hum.BodyDepthScale.Value=n hum.BodyHeightScale.Value=n hum.BodyWidthScale.Value=n hum.HeadScale.Value=n end) end
local function antiAFK(e) if antiAFKConnection then antiAFKConnection:Disconnect() antiAFKConnection=nil end if e then local VU=game:GetService("VirtualUser") antiAFKConnection=localPlayer.Idled:Connect(function() VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame) task.wait(1) VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame) end) end notify("Anti AFK",e and "On" or "Off",2,Color3.fromRGB(100,255,180)) end
local function setWalkAnim(e) local char=localPlayer.Character if not char then return end local animate=char:FindFirstChild("Animate") if animate then animate.Disabled=not e end end
local function glitchEffect(e) if glitchConnection then glitchConnection:Disconnect() glitchConnection=nil end if e then glitchConnection=RunService.Heartbeat:Connect(function() local char=localPlayer.Character if not char then return end local root=char:FindFirstChild("HumanoidRootPart") if root then root.CFrame=root.CFrame*CFrame.new(math.random(-2,2)*0.08,0,math.random(-2,2)*0.08) end end) end end
local function setHealth(n) local char=localPlayer.Character if not char then return end local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.Health=math.clamp(n,0,hum.MaxHealth) end end
local function ragdoll(e) local char=localPlayer.Character if not char then return end local hum=char:FindFirstChildOfClass("Humanoid") if not hum then return end if e then hum:ChangeState(Enum.HumanoidStateType.Ragdoll) else hum:ChangeState(Enum.HumanoidStateType.GettingUp) end end
local function setFOV(n) workspace.CurrentCamera.FieldOfView=math.clamp(n,1,120) end
local function headless(e) local char=localPlayer.Character if not char then return end local head=char:FindFirstChild("Head") local hrp=char:FindFirstChild("HumanoidRootPart") if head then head.Transparency=e and 1 or 0 end if hrp then hrp.Transparency=e and 1 or 0 end end
local function emote(name) local g=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e "..name) end end
local function sayChat(msg) task.wait(math.random(4,12)/10) local g=game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync(msg) end end

local function setLightingTime(h)
	local Lighting = game:GetService("Lighting")
	Lighting.TimeOfDay = tostring(math.clamp(h,0,24))..":00:00"
	notify("Time", "Set to "..tostring(h).."h", 2, Color3.fromRGB(200,200,255))
end

local function setLightingBrightness(n)
	local Lighting = game:GetService("Lighting")
	Lighting.Brightness = math.clamp(n, 0, 10)
	notify("Brightness", tostring(n), 2, Color3.fromRGB(200,200,255))
end

local function setFog(n)
	local Lighting = game:GetService("Lighting")
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then atmo.Density = math.clamp(n/100, 0, 1)
	else
		local a = Instance.new("Atmosphere") a.Density = math.clamp(n/100,0,1) a.Parent = Lighting
	end
	notify("Fog", tostring(n), 2, Color3.fromRGB(200,200,255))
end

local function clearOperators()
	OPERATORS = {}
	saveOperators()
	notify("Operators", "All operators removed.", 3, Color3.fromRGB(255,180,80))
end

local function pingBack(operatorName)
	local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if g then task.wait(0.2) g:SendAsync("/w "..operatorName.." .cc pong") end
	notify("Ping", "Pong sent to "..operatorName, 2, Color3.fromRGB(100,200,255))
end

local function flyMode(enabled)
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if enabled then
		hum.PlatformStand = true
		local bg = Instance.new("BodyGyro") bg.P=1e5 bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.CFrame=root.CFrame bg.Parent=root
		local bv = Instance.new("BodyVelocity") bv.Velocity=Vector3.new(0,0,0) bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.Parent=root
		notify("Fly", "On - use noclip too", 3, Color3.fromRGB(100,200,255))
	else
		hum.PlatformStand = false
		for _, v in ipairs(root:GetChildren()) do
			if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
		end
		notify("Fly", "Off", 2, Color3.fromRGB(100,200,255))
	end
end

local function swimMode(enabled)
	local char = localPlayer.Character if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = enabled and 30 or speedValue end
	workspace.Gravity = enabled and 50 or 196.2
	notify("Swim Mode", enabled and "On" or "Off", 2, Color3.fromRGB(80,160,255))
end

local function setNameVisibility(visible)
	local char = localPlayer.Character if not char then return end
	local humanoidDesc = localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoidDesc then
		pcall(function() humanoidDesc.DisplayDistanceType = visible and Enum.HumanoidDisplayDistanceType.Auto or Enum.HumanoidDisplayDistanceType.None end)
	end
	notify("Nametag", visible and "Visible" or "Hidden", 2, Color3.fromRGB(200,200,255))
end

local function jumpBoost(force)
	local char = localPlayer.Character if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, force or 100, root.AssemblyLinearVelocity.Z) end
	notify("Jump Boost", "Force: "..(force or 100), 2, Color3.fromRGB(100,220,255))
end

local function setAmbient(r, g, b)
	local Lighting = game:GetService("Lighting")
	Lighting.Ambient = Color3.fromRGB(math.clamp(r,0,255), math.clamp(g,0,255), math.clamp(b,0,255))
	notify("Ambient", r.." "..g.." "..b, 2, Color3.fromRGB(200,200,255))
end

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection=nil end
	loopCmd = nil
	notify("Loop", "Stopped.", 2, Color3.fromRGB(255,120,120))
end

local processCommand

local function startLoop(cmdToLoop, interval)
	stopLoop()
	loopCmd = cmdToLoop
	local iv = math.max(interval or 1, 0.5)
	loopConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastLoopSent >= iv then lastLoopSent=now processCommand(cmdToLoop, OPERATORS[1] or "") end
	end)
	notify("Loop", cmdToLoop, 2, Color3.fromRGB(255,120,120))
end

local ALIASES = {
	spd="speed",sp="speed",jp="jumppower",jmp="jumppower",
	fw="forward",bk="back",bw="back",lt="left",rt="right",
	tl="turnleft",tr="turnright",flw="follow",gt="goto",
	inv="invisible",gm="godmode",nc="noclip",frz="freeze",
	ufrz="unfreeze",rst="reset",lk="lookat",ltp="looptp",
	mir="mirror",lck="lockcontrol",sav="savepos",lod="loadpos",
	trp="transparency",sz="size",ul="unloop",ls="loopstop",
	grv="gravity",goff="gravityoff",grst="gravityreset",
	fl="float",bh="bighead",cr="crouch",orb="orbit",ptr="patrol",
	hlth="health",hd="headless",rg="ragdoll",gl="glitch",
	aafk="antiafk",wa="walkanim",lockconn="lcc",wt="walkto",
	br="brightness",nmt="nametag",jb="jumpboost",
}

processCommand = function(message, speaker)
	if not isOperator(speaker) then return end

	if controlLocked then
		local c2=parseCommand(message)
		if c2:lower():sub(1,3)=="/w " then local s=c2:find(" ",4) if s then c2=c2:sub(s+1) end end
		c2=parseCommand(c2)
		local fw=c2:match("%.(%S+)")
		if fw then local res=ALIASES[fw:lower()] or fw:lower() if res~="lockcontrol" and res~="lck" and res~="lcc" then return end end
	end

	local cleaned=message
	if cleaned:lower():sub(1,3)=="/w " then local s=cleaned:find(" ",4) if s then cleaned=cleaned:sub(s+1) end end
	cleaned=parseCommand(cleaned)
	if cleaned:sub(1,1)~="." then return end

	local args={} for word in cleaned:sub(2):gmatch("%S+") do table.insert(args,word) end
	local rawCmd=args[1] and args[1]:lower() if not rawCmd then return end
	local cmd=ALIASES[rawCmd] or rawCmd
	table.remove(args,1)
	local rest=table.concat(args," ")

	if cmd=="follow" then if rest~="" then followPlayer(rest) end
	elseif cmd=="goto" then if rest~="" then goTo(rest) end
	elseif cmd=="walkto" then
		local x,y,z=tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
		if x and y and z then walkToCoords(x,y,z) notify("WalkTo",x.." "..y.." "..z,2,Color3.fromRGB(100,220,100)) end
	elseif cmd=="patrol" then if #args>0 then patrol(args) end
	elseif cmd=="looptp" then if rest~="" then loopTp(rest) end
	elseif cmd=="orbit" then orbit(rest~="" and rest or (OPERATORS[1] or ""))
	elseif cmd=="stop" then stopFollowing() notify("Stop","Stopped.",1,Color3.fromRGB(200,200,255))
	elseif cmd=="say" or cmd=="chat" then if rest~="" then sayChat(rest) end
	elseif cmd=="sit" then local char=localPlayer.Character if char then local h=char:FindFirstChildOfClass("Humanoid") if h then h.Sit=true end end notify("Sit","Sitting.",1,Color3.fromRGB(180,180,255))
	elseif cmd=="stand" then local char=localPlayer.Character if char then local h=char:FindFirstChildOfClass("Humanoid") if h then h.Sit=false end end notify("Stand","Standing.",1,Color3.fromRGB(180,180,255))
	elseif cmd=="emote" or cmd=="e" then if rest~="" then emote(rest) end
	elseif cmd=="wave" then emote("wave")
	elseif cmd=="laugh" then emote("laugh")
	elseif cmd=="cheer" then emote("cheer")
	elseif cmd=="point" then emote("point")
	elseif cmd=="dance" then emote("dance")
	elseif cmd=="dance2" then emote("dance2")
	elseif cmd=="dance3" then emote("dance3")
	elseif cmd=="speed" then
		if rest=="reset" then setSpeed(16) notify("Speed","Reset to 16",2,Color3.fromRGB(100,220,255))
		else local n=tonumber(args[1]) if n then setSpeed(n) notify("Speed",tostring(n),2,Color3.fromRGB(100,220,255)) end end
	elseif cmd=="jump" then doJump()
	elseif cmd=="jumppower" then
		if rest=="reset" then setJump(50) notify("JumpPower","Reset to 50",2,Color3.fromRGB(100,220,255))
		else local n=tonumber(args[1]) if n then setJump(n) notify("JumpPower",tostring(n),2,Color3.fromRGB(100,220,255)) end end
	elseif cmd=="jumpboost" then local n=tonumber(args[1]) jumpBoost(n)
	elseif cmd=="noclip" then if rest=="on" then setNoclip(true) elseif rest=="off" then setNoclip(false) end
	elseif cmd=="freeze" then freezePlayer(true) notify("Freeze","Frozen.",2,Color3.fromRGB(150,200,255))
	elseif cmd=="unfreeze" then freezePlayer(false) notify("Unfreeze","Unfrozen.",2,Color3.fromRGB(150,200,255))
	elseif cmd=="tp" then
		if args[1] and not tonumber(args[1]) then tpToPlayer(rest)
		elseif args[1] and args[2] and args[3] then local x,y,z=tonumber(args[1]),tonumber(args[2]),tonumber(args[3]) if x and y and z then tpToCoords(x,y,z) end end
	elseif cmd=="tpme" then
		local op=OPERATORS[1] and findPlayer(OPERATORS[1])
		if op and op.Character then local or2=op.Character:FindFirstChild("HumanoidRootPart") local mc=localPlayer.Character if mc and or2 then local mr=mc:FindFirstChild("HumanoidRootPart") if mr then mr.CFrame=or2.CFrame+Vector3.new(3,0,0) end end end
	elseif cmd=="invisible" then if rest=="on" then setInvisibleFE(true) elseif rest=="off" then setInvisibleFE(false) end
	elseif cmd=="godmode" then if rest=="on" then setGodMode(true) elseif rest=="off" then setGodMode(false) end
	elseif cmd=="fly" then if rest=="on" then flyMode(true) elseif rest=="off" then flyMode(false) end
	elseif cmd=="swim" then if rest=="on" then swimMode(true) elseif rest=="off" then swimMode(false) end
	elseif cmd=="reset" or cmd=="respawn" then
		local char=localPlayer.Character if char then local h=char:FindFirstChildOfClass("Humanoid") if h then h.Health=0 end end
		notify("Reset","Resetting.",2,Color3.fromRGB(255,100,100))
	elseif cmd=="forward" then moveDir("forward",tonumber(args[1]) or 10)
	elseif cmd=="back" then moveDir("back",tonumber(args[1]) or 10)
	elseif cmd=="left" then moveDir("left",tonumber(args[1]) or 10)
	elseif cmd=="right" then moveDir("right",tonumber(args[1]) or 10)
	elseif cmd=="turnleft" then turnDir("left",tonumber(args[1]) or 90)
	elseif cmd=="turnright" then turnDir("right",tonumber(args[1]) or 90)
	elseif cmd=="lookat" then if rest~="" then lookAt(rest) end
	elseif cmd=="spin" then if rest=="on" then setSpin(true) elseif rest=="off" then setSpin(false) end
	elseif cmd=="fling" then fling() notify("Fling","Flung.",2,Color3.fromRGB(255,150,80))
	elseif cmd=="gravity" then local n=tonumber(args[1]) if n then setGravity(n) notify("Gravity",tostring(n),2,Color3.fromRGB(180,180,255)) end
	elseif cmd=="gravityoff" then setGravity(0) notify("Gravity","Zero.",2,Color3.fromRGB(180,180,255))
	elseif cmd=="gravityreset" then setGravity(196.2) notify("Gravity","Reset.",2,Color3.fromRGB(180,180,255))
	elseif cmd=="float" then if rest=="on" then floatMode(true) elseif rest=="off" then floatMode(false) end
	elseif cmd=="bighead" then if rest=="on" then bigHead(true) elseif rest=="off" then bigHead(false) end
	elseif cmd=="crouch" then if rest=="on" then crouchMode(true) elseif rest=="off" then crouchMode(false) end
	elseif cmd=="lockcontrol" then if rest=="on" then lockControl(true) elseif rest=="off" then lockControl(false) end
	elseif cmd=="mirror" then if rest=="on" then startMirror() elseif rest=="off" then stopMirror() end
	elseif cmd=="transparency" then local n=tonumber(args[1]) if n then setTransparency(math.clamp(n,0,1)) end
	elseif cmd=="size" then
		if rest=="reset" then setSize(1) notify("Size","Reset to 1",2,Color3.fromRGB(200,200,255))
		else local n=tonumber(args[1]) if n then setSize(n) notify("Size",tostring(n),2,Color3.fromRGB(200,200,255)) end end
	elseif cmd=="savepos" then
		local slot=tonumber(args[1]) or 1
		local char=localPlayer.Character if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart") if not root then return end
		savedPositions[slot]=root.CFrame
		notify("Saved","Slot "..slot,2,Color3.fromRGB(100,200,255))
	elseif cmd=="loadpos" then
		local slot=tonumber(args[1]) or 1
		local cf=savedPositions[slot]
		if not cf then notify("Load","No slot "..slot,2,Color3.fromRGB(255,180,80)) return end
		local char=localPlayer.Character if not char then return end
		local root=char:FindFirstChild("HumanoidRootPart") if root then root.CFrame=cf end
	elseif cmd=="health" then local char=localPlayer.Character if char then local h=char:FindFirstChildOfClass("Humanoid") if h then notify("Health",math.floor(h.Health).."/"..math.floor(h.MaxHealth),3,Color3.fromRGB(255,100,100)) end end
	elseif cmd=="sethealth" then local n=tonumber(args[1]) if n then setHealth(n) notify("Health","Set "..n,2,Color3.fromRGB(255,100,100)) end
	elseif cmd=="pos" then local char=localPlayer.Character if char then local r=char:FindFirstChild("HumanoidRootPart") if r then local p=r.Position notify("Pos",math.floor(p.X).." "..math.floor(p.Y).." "..math.floor(p.Z),3,Color3.fromRGB(100,200,255)) end end
	elseif cmd=="rig" then local char=localPlayer.Character if char then local h=char:FindFirstChildOfClass("Humanoid") if h then notify("Rig",h.RigType==Enum.HumanoidRigType.R15 and "R15" or "R6",2,Color3.fromRGB(200,200,255)) end end
	elseif cmd=="antiafk" then if rest=="on" then antiAFK(true) elseif rest=="off" then antiAFK(false) end
	elseif cmd=="walkanim" then if rest=="on" then setWalkAnim(true) elseif rest=="off" then setWalkAnim(false) end
	elseif cmd=="glitch" then if rest=="on" then glitchEffect(true) elseif rest=="off" then glitchEffect(false) end
	elseif cmd=="ragdoll" then if rest=="on" then ragdoll(true) elseif rest=="off" then ragdoll(false) end
	elseif cmd=="headless" then if rest=="on" then headless(true) elseif rest=="off" then headless(false) end
	elseif cmd=="fov" then local n=tonumber(args[1]) if n then setFOV(n) notify("FOV",tostring(n),2,Color3.fromRGB(200,200,255)) end
	elseif cmd=="time" then local n=tonumber(args[1]) if n then setLightingTime(n) end
	elseif cmd=="brightness" then local n=tonumber(args[1]) if n then setLightingBrightness(n) end
	elseif cmd=="fog" then local n=tonumber(args[1]) if n then setFog(n) end
	elseif cmd=="ambient" then
		local r,g,b=tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
		if r and g and b then setAmbient(r,g,b) end
	elseif cmd=="nametag" then if rest=="on" then setNameVisibility(true) elseif rest=="off" then setNameVisibility(false) end
	elseif cmd=="ping" then pingBack(speaker)
	elseif cmd=="lcc" then
		if rest=="on" then connectionLocked=true notify("Conn Lock","Locked.",2,Color3.fromRGB(255,80,80))
		elseif rest=="off" then connectionLocked=false notify("Conn Lock","Open.",2,Color3.fromRGB(80,255,120))
		else notify("Conn Lock",connectionLocked and "LOCKED" or "OPEN",2,Color3.fromRGB(255,180,80)) end
	elseif cmd=="removeop" then
		if rest~="" then
			for i,op in ipairs(OPERATORS) do
				if op:lower()==rest:lower() then table.remove(OPERATORS,i) saveOperators() notify("Removed",rest.." removed.",2,Color3.fromRGB(255,180,80)) break end
			end
		end
	elseif cmd=="clearops" then clearOperators()
	elseif cmd=="ops" then notify("Operators",#OPERATORS>0 and table.concat(OPERATORS,", ") or "None",4,Color3.fromRGB(255,180,80))
	elseif cmd=="serverid" then notify("Server ID",tostring(game.JobId):sub(1,24),5,Color3.fromRGB(200,200,255))
	elseif cmd=="gameid" then notify("Game",game.Name.." / "..tostring(game.PlaceId),4,Color3.fromRGB(200,200,255))
	elseif cmd=="loop" then
		if rest~="" then
			local parts={} for w in rest:gmatch("%S+") do table.insert(parts,w) end
			local interval=1 local ln=tonumber(parts[#parts])
			if ln and #parts>1 then interval=math.max(ln,0.5) table.remove(parts,#parts) end
			local lt=table.concat(parts," ")
			if lt:sub(1,1)~="." then lt="."..lt end
			lt=parseCommand(lt) startLoop(lt,interval)
		end
	elseif cmd=="unloop" or cmd=="loopstop" then stopLoop()
	elseif cmd=="status" then
		local char=localPlayer.Character
		local pos="No char"
		if char then local r=char:FindFirstChild("HumanoidRootPart") if r then local p=r.Position pos=math.floor(p.X).." "..math.floor(p.Y).." "..math.floor(p.Z) end end
		notify("Status",
			(following and "Following" or "Idle").." | "..(loopCmd and "Loop:"..loopCmd or "No loop").." | "..(controlLocked and "CtrlLOCK" or "Free").." | "..(connectionLocked and "ConnLOCK" or "Open").." | Pos:"..pos,
			6,Color3.fromRGB(200,200,255))
	elseif cmd=="aliases" then
		notify("Aliases","spd jp fw bk lt rt tl tr flw gt inv gm nc frz ufrz rst lk ltp mir lck sav lod trp sz ul grv fl bh cr orb ptr hlth hd rg gl aafk wa lcc wt br nmt jb",6,Color3.fromRGB(200,200,255))
	end
end

local function handleChatMessage(message, player)
	local cleaned=message
	if cleaned:lower():sub(1,3)=="/w " then local s=cleaned:find(" ",4) if s then cleaned=cleaned:sub(s+1) end end
	cleaned=parseCommand(cleaned)
	if cleaned:lower():sub(1,2)==".c" then
		local parts={} for w in cleaned:sub(2):gmatch("%S+") do table.insert(parts,w) end
		local rc=parts[1] and parts[1]:lower()
		if rc=="c" then
			if pendingRequests[player.Name] then return end
			pendingRequests[player.Name]=true
			showConnectionRequest(player.Name)
			return
		end
		if rc=="cc" then
			local response=parts[2] and parts[2]:lower()
			if response=="accepted" then notify("Connected","Operator accepted.",3,Color3.fromRGB(80,255,120))
			elseif response=="denied" then notify("Denied","Operator denied.",3,Color3.fromRGB(255,80,80))
			elseif response=="pong" then notify("Pong","Pong from "..player.Name,2,Color3.fromRGB(100,200,255)) end
			return
		end
	end
	processCommand(message, player.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message) handleChatMessage(message,player) end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message) handleChatMessage(message,player) end)
end

notify("Robot Ready","Ops: "..(#OPERATORS>0 and table.concat(OPERATORS,", ") or "None - waiting for .c"),4,Color3.fromRGB(100,200,255))
