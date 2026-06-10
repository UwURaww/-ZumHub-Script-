local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

local OPERATORS = {}
local pendingRequests = {}

local following = nil
local followConnection = nil
local speedValue = 16
local jumpValue = 50
local noclipConnection = nil
local godModeConnection = nil
local loopConnection = nil
local loopCmd = nil
local lastLoopSent = 0
local controlLocked = false
local mirrorConnection = nil
local mirrorEnabled = false
local antiAFKConnection = nil
local chatSpamConnection = nil
local glitchConnection = nil
local savedPosition = nil
local savedPosition2 = nil
local savedPosition3 = nil

local OPS_SAVE_KEY = "RobotSavedOperators_v2"

local function saveOperators()
	localPlayer:SetAttribute(OPS_SAVE_KEY, table.concat(OPERATORS, ";;"))
end

local function loadOperators()
	local raw = localPlayer:GetAttribute(OPS_SAVE_KEY)
	OPERATORS = {}
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
	sg.Name = "RobotNotif"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 56)
	frame.Position = UDim2.new(0, 16, 1, 80)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
	frame.BorderSizePixel = 0
	frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 7) fc.Parent = frame
	local fs = Instance.new("UIStroke")
	fs.Color = data.color or Color3.fromRGB(100, 200, 255)
	fs.Thickness = 1.5
	fs.Parent = frame

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, 0)
	accent.BackgroundColor3 = data.color or Color3.fromRGB(100, 200, 255)
	accent.BorderSizePixel = 0
	accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0, 7) ac.Parent = accent

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -20, 0, 20)
	titleLbl.Position = UDim2.new(0, 12, 0, 4)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = data.title
	titleLbl.TextColor3 = data.color or Color3.fromRGB(100, 200, 255)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = frame

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = UDim2.new(1, -20, 0, 26)
	msgLbl.Position = UDim2.new(0, 12, 0, 24)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Text = data.message
	msgLbl.TextColor3 = Color3.fromRGB(180, 180, 210)
	msgLbl.TextScaled = true
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextWrapped = true
	msgLbl.Parent = frame

	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 16, 1, -72)})
	tweenIn:Play()

	task.delay(data.duration or 3, function()
		local tweenOut = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, 16, 1, 80)})
		tweenOut:Play()
		tweenOut.Completed:Wait()
		sg:Destroy()
		notifActive = false
		processNotifQueue()
	end)
end

local function notify(title, message, duration, color)
	table.insert(notifQueue, {title=title, message=message, duration=duration or 3, color=color})
	processNotifQueue()
end

local function showConnectionRequest(requesterName)
	local sg = Instance.new("ScreenGui")
	sg.Name = "RobotConnReq"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 88)
	frame.Position = UDim2.new(0, 16, 1, 110)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
	frame.BorderSizePixel = 0
	frame.Parent = sg
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 7) fc.Parent = frame
	local fs = Instance.new("UIStroke") fs.Color = Color3.fromRGB(255, 180, 80) fs.Thickness = 1.5 fs.Parent = frame

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, 0)
	accent.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
	accent.BorderSizePixel = 0
	accent.Parent = frame
	local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0, 7) ac.Parent = accent

	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 16, 1, -104)})
	tweenIn:Play()

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -16, 0, 20)
	titleLbl.Position = UDim2.new(0, 12, 0, 4)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Operator Request"
	titleLbl.TextColor3 = Color3.fromRGB(255, 180, 80)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = frame

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = UDim2.new(1, -16, 0, 20)
	msgLbl.Position = UDim2.new(0, 12, 0, 24)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Text = requesterName .. " wants to control you"
	msgLbl.TextColor3 = Color3.fromRGB(200, 200, 230)
	msgLbl.TextScaled = true
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.Parent = frame

	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Size = UDim2.new(0, 110, 0, 26)
	acceptBtn.Position = UDim2.new(0, 12, 0, 56)
	acceptBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 50)
	acceptBtn.Text = "Accept"
	acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	acceptBtn.TextScaled = true
	acceptBtn.Font = Enum.Font.GothamBold
	acceptBtn.BorderSizePixel = 0
	acceptBtn.Parent = frame
	local abc = Instance.new("UICorner") abc.CornerRadius = UDim.new(0, 5) abc.Parent = acceptBtn

	local denyBtn = Instance.new("TextButton")
	denyBtn.Size = UDim2.new(0, 90, 0, 26)
	denyBtn.Position = UDim2.new(0, 130, 0, 56)
	denyBtn.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
	denyBtn.Text = "Deny"
	denyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	denyBtn.TextScaled = true
	denyBtn.Font = Enum.Font.GothamBold
	denyBtn.BorderSizePixel = 0
	denyBtn.Parent = frame
	local dbc = Instance.new("UICorner") dbc.CornerRadius = UDim.new(0, 5) dbc.Parent = denyBtn

	local function dismiss()
		local tweenOut = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, 16, 1, 110)})
		tweenOut:Play()
		tweenOut.Completed:Wait()
		sg:Destroy()
		pendingRequests[requesterName] = nil
	end

	acceptBtn.MouseButton1Click:Connect(function()
		table.insert(OPERATORS, requesterName)
		saveOperators()
		notify("Connected", requesterName .. " is now your operator.", 3, Color3.fromRGB(80, 255, 120))
		local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if general then task.wait(0.2) general:SendAsync("/w " .. requesterName .. " .cc accepted") end
		dismiss()
	end)

	denyBtn.MouseButton1Click:Connect(function()
		notify("Denied", requesterName .. " was denied.", 2, Color3.fromRGB(255, 80, 80))
		local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
		if general then task.wait(0.2) general:SendAsync("/w " .. requesterName .. " .cc denied") end
		dismiss()
	end)

	task.delay(20, function() if sg.Parent then dismiss() end end)
end

local function stopFollowing()
	following = nil
	if followConnection then followConnection:Disconnect() followConnection = nil end
end

local function findPlayer(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name:lower()) or p.DisplayName:lower():find(name:lower()) then return p end
	end
	return nil
end

local function parseCommand(raw)
	local s = raw:gsub("^%s+", ""):gsub("%s+$", "")
	if s:sub(1,2) == ". " then s = "." .. s:sub(3) end
	return s
end

local function lockControl(enabled)
	controlLocked = enabled
	local ok, PlayerModule = pcall(function()
		return require(localPlayer.PlayerScripts:WaitForChild("PlayerModule"))
	end)
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
	notify("Mirror", "Mirroring " .. operator.Name, 2, Color3.fromRGB(180,100,255))
	mirrorConnection = RunService.Heartbeat:Connect(function()
		if not mirrorEnabled then return end
		local opChar = operator.Character
		local myChar = localPlayer.Character
		if not opChar or not myChar then return end
		local opRoot = opChar:FindFirstChild("HumanoidRootPart")
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local opHum = opChar:FindFirstChildOfClass("Humanoid")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if not opRoot or not myRoot or not opHum or not myHum then return end
		myHum.WalkSpeed = opHum.WalkSpeed
		myHum.JumpPower = opHum.JumpPower
		if opHum.Jump then myHum.Jump = true end
		local opVel = opRoot.AssemblyLinearVelocity
		if opVel.Magnitude > 1 then
			local moveDir = Vector3.new(opVel.X, 0, opVel.Z).Unit
			myHum:MoveTo(myRoot.Position + moveDir * 3)
		end
		local opLook = opRoot.CFrame.LookVector
		myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.lookAt(Vector3.new(0,0,0), Vector3.new(opLook.X, 0, opLook.Z))
	end)
end

local function stopMirror()
	mirrorEnabled = false
	if mirrorConnection then mirrorConnection:Disconnect() mirrorConnection = nil end
	local char = localPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = speedValue hum.JumpPower = jumpValue end
	end
	notify("Mirror", "Mirror disabled.", 2, Color3.fromRGB(180,100,255))
end

local function followPlayer(targetName)
	stopFollowing()
	local target = targetName == "me" and (OPERATORS[1] and findPlayer(OPERATORS[1])) or findPlayer(targetName)
	if not target then notify("Follow", "Player not found.", 2, Color3.fromRGB(255,100,100)) return end
	following = target
	notify("Follow", "Following " .. target.Name, 2, Color3.fromRGB(100,200,255))
	followConnection = RunService.Heartbeat:Connect(function()
		if not following then return end
		local targetChar = following.Character
		local myChar = localPlayer.Character
		if not myChar or not targetChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if not myRoot or not targetRoot or not myHum then return end
		local dist = (myRoot.Position - targetRoot.Position).Magnitude
		if dist > 5 then
			local direction = (targetRoot.Position - myRoot.Position).Unit
			myHum:MoveTo(targetRoot.Position - direction * 4)
		else
			myHum:MoveTo(myRoot.Position)
		end
	end)
end

local function goToPosition(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	local myChar = localPlayer.Character
	if not myChar or not targetRoot then return end
	local myHum = myChar:FindFirstChildOfClass("Humanoid")
	if myHum then myHum:MoveTo(targetRoot.Position) end
end

local function patrol(names)
	stopFollowing()
	local targets = {}
	for _, name in ipairs(names) do
		local p = findPlayer(name)
		if p then table.insert(targets, p) end
	end
	if #targets == 0 then return end
	following = targets[1]
	local index = 1
	local cooldown = false
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or cooldown then return end
		local target = targets[index]
		if not target or not target.Character then return end
		local myChar = localPlayer.Character
		if not myChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if not myRoot or not targetRoot or not myHum then return end
		local dist = (myRoot.Position - targetRoot.Position).Magnitude
		if dist <= 5 then
			cooldown = true
			index = (index % #targets) + 1
			task.delay(1, function() cooldown = false end)
		else
			local direction = (targetRoot.Position - myRoot.Position).Unit
			myHum:MoveTo(targetRoot.Position - direction * 4)
		end
	end)
end

local function loopTp(targetName)
	stopFollowing()
	local target = findPlayer(targetName)
	if not target then return end
	following = target
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or not following.Character then stopFollowing() return end
		local myChar = localPlayer.Character
		local targetChar = following.Character
		if not myChar or not targetChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		if myRoot and targetRoot then myRoot.CFrame = targetRoot.CFrame + Vector3.new(3, 0, 0) end
	end)
end

local function setSpeed(amount)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = amount speedValue = amount end
end

local function setJump(amount)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = amount jumpValue = amount end
end

local function setNoclip(enabled)
	if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
	if enabled then
		noclipConnection = RunService.Stepped:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end)
	else
		local char = localPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end
	notify("Noclip", enabled and "On" or "Off", 2, Color3.fromRGB(100,180,255))
end

local function freezePlayer(enabled)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if enabled then hum.WalkSpeed = 0 hum.JumpPower = 0 root.Anchored = true
	else hum.WalkSpeed = speedValue hum.JumpPower = jumpValue root.Anchored = false end
end

local function tpToPlayer(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local myChar = localPlayer.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and targetRoot then myRoot.CFrame = targetRoot.CFrame + Vector3.new(3, 0, 0) end
end

local function tpToCoords(x, y, z)
	local myChar = localPlayer.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if myRoot then myRoot.CFrame = CFrame.new(x, y, z) end
end

local function setInvisibleFE(enabled)
	if enabled then
		loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-fe-invisible-OPEN-SOURCE-53560"))()
	else
		local char = localPlayer.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency = 0 end
		end
	end
	notify("Invisible", enabled and "On" or "Off", 2, Color3.fromRGB(180,180,255))
end

local function setGodMode(enabled)
	if godModeConnection then godModeConnection:Disconnect() godModeConnection = nil end
	if enabled then
		godModeConnection = RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local parts = game:GetService("Workspace"):GetPartBoundsInRadius(root.Position, 10)
			for _, part in ipairs(parts) do
				if part.CanTouch then part.CanTouch = false end
			end
		end)
	end
	notify("Godmode", enabled and "On" or "Off", 2, Color3.fromRGB(255,220,80))
end

local function moveDirection(dir, studs)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local cf = root.CFrame
	local target
	if dir == "forward" then target = cf * CFrame.new(0,0,-(studs or 10))
	elseif dir == "back" then target = cf * CFrame.new(0,0,(studs or 10))
	elseif dir == "left" then target = cf * CFrame.new(-(studs or 10),0,0)
	elseif dir == "right" then target = cf * CFrame.new((studs or 10),0,0) end
	if target then hum:MoveTo(target.Position) end
end

local function doJump()
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Jump = true end
end

local function turnDirection(dir, amount)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local angle = math.rad(amount or 90)
	if dir == "left" then root.CFrame = root.CFrame * CFrame.Angles(0, angle, 0)
	elseif dir == "right" then root.CFrame = root.CFrame * CFrame.Angles(0, -angle, 0) end
end

local function lookAt(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local myChar = localPlayer.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and targetRoot then myRoot.CFrame = CFrame.lookAt(myRoot.Position, targetRoot.Position) end
end

local function spinLoop(enabled)
	stopFollowing()
	if enabled then
		following = true
		followConnection = RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(5), 0) end
		end)
	end
end

local function fling()
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.new(math.random(-100,100), 200, math.random(-100,100)) end
end

local function setGravity(amount) game:GetService("Workspace").Gravity = amount end
local function floatMode(enabled) if enabled then game:GetService("Workspace").Gravity = 5 else game:GetService("Workspace").Gravity = 196.2 end end

local function bigHead(enabled)
	local char = localPlayer.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if head then head.Size = enabled and Vector3.new(4,4,4) or Vector3.new(2,1,1) end
end

local function crouchMode(enabled)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.HipHeight = enabled and 0.5 or 2 end
end

local function setTransparency(amount)
	local char = localPlayer.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency = amount end
	end
end

local function setSize(scale)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	pcall(function()
		hum.BodyDepthScale.Value = scale hum.BodyHeightScale.Value = scale
		hum.BodyWidthScale.Value = scale hum.HeadScale.Value = scale
	end)
end

local function antiAFK(enabled)
	if antiAFKConnection then antiAFKConnection:Disconnect() antiAFKConnection = nil end
	if enabled then
		local VirtualUser = game:GetService("VirtualUser")
		antiAFKConnection = localPlayer.Idled:Connect(function()
			VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
		end)
		notify("Anti AFK", "Enabled.", 2, Color3.fromRGB(100,255,180))
	else
		notify("Anti AFK", "Disabled.", 2, Color3.fromRGB(255,180,100))
	end
end

local function setWalkAnim(enabled)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if not enabled then
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = true end
	else
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
	end
end

local function glitchEffect(enabled)
	if glitchConnection then glitchConnection:Disconnect() glitchConnection = nil end
	if enabled then
		glitchConnection = RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = root.CFrame * CFrame.new(math.random(-2,2)*0.1, 0, math.random(-2,2)*0.1)
			end
		end)
	end
end

local function setHealth(amount)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = math.clamp(amount, 0, hum.MaxHealth) end
end

local function ragdoll(enabled)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if enabled then
		hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
	else
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function setFOV(amount)
	game:GetService("Workspace").CurrentCamera.FieldOfView = math.clamp(amount, 1, 120)
end

local function headless(enabled)
	local char = localPlayer.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if head then head.Transparency = enabled and 1 or 0 end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and enabled then hrp.Transparency = 1 end
end

local function savePos(slot)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if slot == 1 then savedPosition = root.CFrame
	elseif slot == 2 then savedPosition2 = root.CFrame
	elseif slot == 3 then savedPosition3 = root.CFrame end
	notify("Saved", "Position " .. slot .. " saved.", 2, Color3.fromRGB(100,200,255))
end

local function loadPos(slot)
	local cf = slot == 1 and savedPosition or slot == 2 and savedPosition2 or savedPosition3
	if not cf then notify("Load Pos", "No saved position " .. slot, 2, Color3.fromRGB(255,180,80)) return end
	local char = localPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame = cf end
	end
end

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection = nil end
	loopCmd = nil
	notify("Loop", "Loop stopped.", 2, Color3.fromRGB(255,120,120))
end

local processCommand

local function startLoop(cmdToLoop, interval)
	stopLoop()
	loopCmd = cmdToLoop
	local iv = math.max(interval or 1, 0.5)
	loopConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastLoopSent >= iv then
			lastLoopSent = now
			processCommand(cmdToLoop, OPERATORS[1] or "")
		end
	end)
	notify("Loop", cmdToLoop, 3, Color3.fromRGB(255,120,120))
end

local ALIASES = {
	spd="speed", sp="speed", jp="jumppower", jmp="jumppower",
	fw="forward", bk="back", bw="back", lt="left", rt="right",
	tl="turnleft", tr="turnright", flw="follow", gt="goto",
	inv="invisible", gm="godmode", nc="noclip", frz="freeze",
	ufrz="unfreeze", rst="reset", lk="lookat", ltp="looptp",
	mir="mirror", lck="lockcontrol", sav="savepos", lod="loadpos",
	trp="transparency", sz="size", ul="unloop", ls="loopstop",
	grv="gravity", goff="gravityoff", grst="gravityreset",
	fl="float", bh="bighead", cr="crouch", orb="orbit", ptr="patrol",
	hlth="health", hd="headless", rg="ragdoll", gl="glitch",
	aafk="antiafk", wa="walkanim",
}

processCommand = function(message, speaker)
	if not isOperator(speaker) then return end

	if controlLocked then
		local cleaned2 = parseCommand(message)
		if cleaned2:lower():sub(1,3) == "/w " then
			local s = cleaned2:find(" ", 4)
			if s then cleaned2 = cleaned2:sub(s+1) end
		end
		cleaned2 = parseCommand(cleaned2)
		local firstWord = cleaned2:match("%.(%S+)")
		if firstWord then
			local resolved = ALIASES[firstWord:lower()] or firstWord:lower()
			if resolved ~= "lockcontrol" and resolved ~= "lck" then return end
		end
	end

	local cleaned = message
	if cleaned:lower():sub(1,3) == "/w " then
		local s = cleaned:find(" ", 4)
		if s then cleaned = cleaned:sub(s+1) end
	end
	cleaned = parseCommand(cleaned)
	if cleaned:sub(1,1) ~= "." then return end

	local args = {}
	for word in cleaned:sub(2):gmatch("%S+") do table.insert(args, word) end

	local rawCmd = args[1] and args[1]:lower()
	if not rawCmd then return end
	local cmd = ALIASES[rawCmd] or rawCmd
	table.remove(args, 1)
	local rest = table.concat(args, " ")

	if cmd == "follow" then if rest ~= "" then followPlayer(rest) end
	elseif cmd == "goto" then if rest ~= "" then goToPosition(rest) end
	elseif cmd == "patrol" then if #args > 0 then patrol(args) end
	elseif cmd == "looptp" then if rest ~= "" then loopTp(rest) end
	elseif cmd == "stop" then
		stopFollowing()
		notify("Stop", "Stopped.", 2, Color3.fromRGB(200,200,255))
	elseif cmd == "say" then
		if rest ~= "" then
			task.wait(math.random(4,12)/10)
			local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
			if g then g:SendAsync(rest) end
		end
	elseif cmd == "sit" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Sit = true end end
		notify("Sit", "Sitting.", 1, Color3.fromRGB(180,180,255))
	elseif cmd == "stand" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Sit = false end end
		notify("Stand", "Standing.", 1, Color3.fromRGB(180,180,255))
	elseif cmd == "emote" or cmd == "e" then
		if rest ~= "" then
			local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
			if g then g:SendAsync("/e " .. rest) end
		end
	elseif cmd == "wave" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e wave") end
	elseif cmd == "laugh" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e laugh") end
	elseif cmd == "cheer" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e cheer") end
	elseif cmd == "point" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e point") end
	elseif cmd == "dance" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e dance") end
	elseif cmd == "dance2" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e dance2") end
	elseif cmd == "dance3" then local g = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral") if g then g:SendAsync("/e dance3") end
	elseif cmd == "speed" then local num = tonumber(args[1]) if num then setSpeed(num) notify("Speed", tostring(num), 2, Color3.fromRGB(100,220,255)) end
	elseif cmd == "jump" then doJump()
	elseif cmd == "jumppower" then local num = tonumber(args[1]) if num then setJump(num) notify("JumpPower", tostring(num), 2, Color3.fromRGB(100,220,255)) end
	elseif cmd == "noclip" then if rest=="on" then setNoclip(true) elseif rest=="off" then setNoclip(false) end
	elseif cmd == "freeze" then freezePlayer(true) notify("Freeze", "Frozen.", 2, Color3.fromRGB(150,200,255))
	elseif cmd == "unfreeze" then freezePlayer(false) notify("Unfreeze", "Unfrozen.", 2, Color3.fromRGB(150,200,255))
	elseif cmd == "tp" then
		if args[1] and not tonumber(args[1]) then tpToPlayer(rest)
		elseif args[1] and args[2] and args[3] then
			local x,y,z = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
			if x and y and z then tpToCoords(x,y,z) end
		end
	elseif cmd == "tpme" then
		local op = OPERATORS[1] and findPlayer(OPERATORS[1])
		if op and op.Character then
			local opRoot = op.Character:FindFirstChild("HumanoidRootPart")
			local myChar = localPlayer.Character
			if myChar and opRoot then
				local myRoot = myChar:FindFirstChild("HumanoidRootPart")
				if myRoot then myRoot.CFrame = opRoot.CFrame + Vector3.new(3,0,0) end
			end
		end
	elseif cmd == "invisible" then if rest=="on" then setInvisibleFE(true) elseif rest=="off" then setInvisibleFE(false) end
	elseif cmd == "godmode" then if rest=="on" then setGodMode(true) elseif rest=="off" then setGodMode(false) end
	elseif cmd == "reset" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Health = 0 end end
		notify("Reset", "Resetting.", 2, Color3.fromRGB(255,100,100))
	elseif cmd == "forward" then moveDirection("forward", tonumber(args[1]) or 10)
	elseif cmd == "back" then moveDirection("back", tonumber(args[1]) or 10)
	elseif cmd == "left" then moveDirection("left", tonumber(args[1]) or 10)
	elseif cmd == "right" then moveDirection("right", tonumber(args[1]) or 10)
	elseif cmd == "turnleft" then turnDirection("left", tonumber(args[1]) or 90)
	elseif cmd == "turnright" then turnDirection("right", tonumber(args[1]) or 90)
	elseif cmd == "lookat" then if rest ~= "" then lookAt(rest) end
	elseif cmd == "spin" then if rest=="on" then spinLoop(true) elseif rest=="off" then spinLoop(false) end
	elseif cmd == "fling" then fling() notify("Fling", "Flung.", 2, Color3.fromRGB(255,150,80))
	elseif cmd == "gravity" then local num = tonumber(args[1]) if num then setGravity(num) notify("Gravity", tostring(num), 2, Color3.fromRGB(180,180,255)) end
	elseif cmd == "gravityoff" then setGravity(0) notify("Gravity", "Zero gravity.", 2, Color3.fromRGB(180,180,255))
	elseif cmd == "gravityreset" then setGravity(196.2) notify("Gravity", "Reset.", 2, Color3.fromRGB(180,180,255))
	elseif cmd == "float" then if rest=="on" then floatMode(true) elseif rest=="off" then floatMode(false) end
	elseif cmd == "bighead" then if rest=="on" then bigHead(true) elseif rest=="off" then bigHead(false) end
	elseif cmd == "crouch" then if rest=="on" then crouchMode(true) elseif rest=="off" then crouchMode(false) end
	elseif cmd == "lockcontrol" then if rest=="on" then lockControl(true) elseif rest=="off" then lockControl(false) end
	elseif cmd == "mirror" then if rest=="on" then startMirror() elseif rest=="off" then stopMirror() end
	elseif cmd == "transparency" then local num = tonumber(args[1]) if num then setTransparency(math.clamp(num,0,1)) end
	elseif cmd == "size" then local num = tonumber(args[1]) if num then setSize(num) notify("Size", tostring(num), 2, Color3.fromRGB(200,200,255)) end
	elseif cmd == "savepos" then
		local slot = tonumber(args[1]) or 1
		savePos(slot)
	elseif cmd == "loadpos" then
		local slot = tonumber(args[1]) or 1
		loadPos(slot)
	elseif cmd == "orbit" then
		stopFollowing()
		local target = rest ~= "" and findPlayer(rest) or (OPERATORS[1] and findPlayer(OPERATORS[1]))
		if not target then return end
		following = target
		local angle = 0
		followConnection = RunService.Heartbeat:Connect(function()
			if not following or not following.Character then stopFollowing() return end
			local targetChar = following.Character
			local myChar = localPlayer.Character
			if not myChar or not targetChar then return end
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			local myRoot = myChar:FindFirstChild("HumanoidRootPart")
			local myHum = myChar:FindFirstChildOfClass("Humanoid")
			if not targetRoot or not myRoot or not myHum then return end
			angle = angle + 0.02
			myHum:MoveTo(Vector3.new(targetRoot.Position.X + math.cos(angle)*8, targetRoot.Position.Y, targetRoot.Position.Z + math.sin(angle)*8))
		end)
	elseif cmd == "health" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then notify("Health", math.floor(hum.Health).."/"..math.floor(hum.MaxHealth), 3, Color3.fromRGB(255,100,100)) end end
	elseif cmd == "sethealth" then
		local num = tonumber(args[1]) if num then setHealth(num) notify("Health", "Set to "..num, 2, Color3.fromRGB(255,100,100)) end
	elseif cmd == "pos" then
		local char = localPlayer.Character
		if char then local root = char:FindFirstChild("HumanoidRootPart") if root then local p = root.Position notify("Position", math.floor(p.X).." "..math.floor(p.Y).." "..math.floor(p.Z), 3, Color3.fromRGB(100,200,255)) end end
	elseif cmd == "rig" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then notify("Rig", hum.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6", 2, Color3.fromRGB(200,200,255)) end end
	elseif cmd == "antiafk" then if rest=="on" then antiAFK(true) elseif rest=="off" then antiAFK(false) end
	elseif cmd == "walkanim" then if rest=="on" then setWalkAnim(true) elseif rest=="off" then setWalkAnim(false) end
	elseif cmd == "glitch" then if rest=="on" then glitchEffect(true) elseif rest=="off" then glitchEffect(false) end
	elseif cmd == "ragdoll" then if rest=="on" then ragdoll(true) elseif rest=="off" then ragdoll(false) end
	elseif cmd == "headless" then if rest=="on" then headless(true) elseif rest=="off" then headless(false) end
	elseif cmd == "fov" then local num = tonumber(args[1]) if num then setFOV(num) notify("FOV", tostring(num), 2, Color3.fromRGB(200,200,255)) end
	elseif cmd == "removeop" then
		if rest ~= "" then
			for i, op in ipairs(OPERATORS) do
				if op:lower() == rest:lower() then
					table.remove(OPERATORS, i) saveOperators()
					notify("Removed", rest .. " removed.", 2, Color3.fromRGB(255,180,80))
					break
				end
			end
		end
	elseif cmd == "ops" then
		notify("Operators", #OPERATORS > 0 and table.concat(OPERATORS, ", ") or "None", 4, Color3.fromRGB(255,180,80))
	elseif cmd == "loop" then
		if rest ~= "" then
			local parts = {}
			for w in rest:gmatch("%S+") do table.insert(parts, w) end
			local interval = 1
			local lastNum = tonumber(parts[#parts])
			if lastNum and #parts > 1 then interval = math.max(lastNum, 0.5) table.remove(parts, #parts) end
			local loopTarget = table.concat(parts, " ")
			if loopTarget:sub(1,1) ~= "." then loopTarget = "." .. loopTarget end
			loopTarget = parseCommand(loopTarget)
			startLoop(loopTarget, interval)
		end
	elseif cmd == "unloop" or cmd == "loopstop" then stopLoop()
	elseif cmd == "status" then
		notify("Status", (following and "Following" or "Idle").." | "..(loopCmd and "Loop: "..loopCmd or "No loop").." | "..(controlLocked and "LOCKED" or "Free"), 4, Color3.fromRGB(200,200,255))
	elseif cmd == "aliases" then
		notify("Aliases", "spd jp fw bk lt rt tl tr flw gt inv gm nc frz ufrz rst lk ltp mir lck sav lod trp sz ul grv fl bh cr orb ptr hlth hd rg gl aafk", 6, Color3.fromRGB(200,200,255))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local cleaned = message
		if cleaned:lower():sub(1,3) == "/w " then
			local s = cleaned:find(" ", 4)
			if s then cleaned = cleaned:sub(s+1) end
		end
		cleaned = parseCommand(cleaned)

		if cleaned:lower():sub(1,2) == ".c" then
			local parts = {}
			for w in cleaned:sub(2):gmatch("%S+") do table.insert(parts, w) end
			local requestCmd = parts[1] and parts[1]:lower()
			if requestCmd == "c" then
				if pendingRequests[player.Name] then return end
				pendingRequests[player.Name] = true
				showConnectionRequest(player.Name)
				return
			end
			if requestCmd == "cc" then
				local response = parts[2] and parts[2]:lower()
				if response == "accepted" then notify("Connected", "Bot accepted.", 3, Color3.fromRGB(80,255,120))
				elseif response == "denied" then notify("Denied", "Bot denied.", 3, Color3.fromRGB(255,80,80)) end
				return
			end
		end

		processCommand(message, player.Name)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		local cleaned = message
		if cleaned:lower():sub(1,3) == "/w " then
			local s = cleaned:find(" ", 4)
			if s then cleaned = cleaned:sub(s+1) end
		end
		cleaned = parseCommand(cleaned)

		if cleaned:lower():sub(1,2) == ".c" then
			local parts = {}
			for w in cleaned:sub(2):gmatch("%S+") do table.insert(parts, w) end
			local requestCmd = parts[1] and parts[1]:lower()
			if requestCmd == "c" then
				if pendingRequests[player.Name] then return end
				pendingRequests[player.Name] = true
				showConnectionRequest(player.Name)
				return
			end
			if requestCmd == "cc" then
				local response = parts[2] and parts[2]:lower()
				if response == "accepted" then notify("Connected", "Bot accepted.", 3, Color3.fromRGB(80,255,120))
				elseif response == "denied" then notify("Denied", "Bot denied.", 3, Color3.fromRGB(255,80,80)) end
				return
			end
		end

		processCommand(message, player.Name)
	end)
end

notify("Robot Ready", "Ops: " .. (#OPERATORS > 0 and table.concat(OPERATORS, ", ") or "None - waiting for .c"), 5, Color3.fromRGB(100,200,255))
