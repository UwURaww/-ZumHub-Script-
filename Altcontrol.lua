local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

local OPERATOR = "zumartengge6no10"
local OPERATOR_DISPLAY = "mop"

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

local function isOperator(name)
	return name == OPERATOR or name == OPERATOR_DISPLAY
end

local function sendWhisper(message)
	game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
		Text = "[Bot] " .. message,
		Color = Color3.fromRGB(100, 200, 255),
		FontSize = Enum.FontSize.Size18,
	})
end

local function getCharacterRig()
	local char = localPlayer.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	if hum.RigType == Enum.HumanoidRigType.R15 then return "R15" end
	return "R6"
end

local function doEmote(emoteName)
	local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if general then general:SendAsync("/e " .. emoteName) end
end

local function sendChat(message)
	task.wait(math.random(4, 12) / 10)
	local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if general then general:SendAsync(message) end
end

local function stopFollowing()
	following = nil
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
end

local function findPlayer(name)
	if name == "me" then
		local t = Players:FindFirstChild(OPERATOR)
		if not t then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.DisplayName:lower() == OPERATOR_DISPLAY:lower() then return p end
			end
		end
		return t
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(name:lower()) or p.DisplayName:lower():find(name:lower()) then
			return p
		end
	end
	return nil
end

local function lockControl(enabled)
	controlLocked = enabled
	local ok, PlayerModule = pcall(function()
		return require(localPlayer.PlayerScripts:WaitForChild("PlayerModule"))
	end)
	if ok and PlayerModule then
		local controls = PlayerModule:GetControls()
		pcall(function()
			if enabled then controls:Disable() else controls:Enable() end
		end)
	end
	local char = localPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = enabled and 0 or speedValue
			hum.JumpPower = enabled and 0 or jumpValue
		end
	end
	sendWhisper(enabled and "Control locked." or "Control unlocked.")
end

local function startMirror()
	if mirrorConnection then mirrorConnection:Disconnect() mirrorConnection = nil end
	local operator = findPlayer(OPERATOR)
	if not operator then sendWhisper("Operator not found.") return end
	mirrorEnabled = true
	sendWhisper("Mirror enabled.")
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
	sendWhisper("Mirror disabled.")
end

local function followPlayer(targetName)
	stopFollowing()
	local target = findPlayer(targetName)
	if not target then sendWhisper("Player not found.") return end
	following = target
	followConnection = RunService.Heartbeat:Connect(function()
		if not following then return end
		local targetChar = following.Character
		local myChar = localPlayer.Character
		if not myChar or not targetChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if not myRoot or not targetRoot or not myHum then return end
		local myPos = myRoot.Position
		local targetPos = targetRoot.Position
		local dist = (myPos - targetPos).Magnitude
		if dist > 5 then
			local direction = (targetPos - myPos).Unit
			myHum:MoveTo(targetPos - direction * 4)
		else
			myHum:MoveTo(myPos)
		end
	end)
end

local function goToPosition(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end
	local myChar = localPlayer.Character
	if not myChar then return end
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
		if myRoot and targetRoot then
			myRoot.CFrame = targetRoot.CFrame + Vector3.new(3, 0, 0)
		end
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
end

local function freezePlayer(enabled)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if enabled then
		hum.WalkSpeed = 0 hum.JumpPower = 0 root.Anchored = true
	else
		hum.WalkSpeed = speedValue hum.JumpPower = jumpValue root.Anchored = false
	end
end

local function tpToPlayer(targetName)
	local target = findPlayer(targetName)
	if not target or not target.Character then return end
	local myChar = localPlayer.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and targetRoot then
		myRoot.CFrame = targetRoot.CFrame + Vector3.new(3, 0, 0)
	end
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
end

local function moveDirection(dir, studs)
	local char = localPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local cf = root.CFrame
	local target
	if dir == "forward" then target = cf * CFrame.new(0, 0, -(studs or 10))
	elseif dir == "back" then target = cf * CFrame.new(0, 0, (studs or 10))
	elseif dir == "left" then target = cf * CFrame.new(-(studs or 10), 0, 0)
	elseif dir == "right" then target = cf * CFrame.new((studs or 10), 0, 0)
	end
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
	if myRoot and targetRoot then
		myRoot.CFrame = CFrame.lookAt(myRoot.Position, targetRoot.Position)
	end
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
	if root then
		root.AssemblyLinearVelocity = Vector3.new(math.random(-100,100), 200, math.random(-100,100))
	end
end

local function setGravity(amount)
	game:GetService("Workspace").Gravity = amount
end

local function floatMode(enabled)
	if enabled then game:GetService("Workspace").Gravity = 5
	else game:GetService("Workspace").Gravity = 196.2 end
end

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
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.Transparency = amount
		end
	end
end

local function setSize(scale)
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.BodyDepthScale.Value = scale
	hum.BodyHeightScale.Value = scale
	hum.BodyWidthScale.Value = scale
	hum.HeadScale.Value = scale
end

local function dance(style)
	local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if general then general:SendAsync("/e dance" .. (style or "")) end
end

local function savePosition()
	local char = localPlayer.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then return root.CFrame end
	return nil
end

local savedPosition = nil

local function stopLoop()
	if loopConnection then loopConnection:Disconnect() loopConnection = nil end
	loopCmd = nil
	sendWhisper("Loop stopped.")
end

local processCommand

local function startLoop(cmd, interval)
	stopLoop()
	loopCmd = cmd
	local iv = interval or 1
	loopConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastLoopSent >= iv then
			lastLoopSent = now
			processCommand("." .. cmd, OPERATOR)
		end
	end)
	sendWhisper("Looping: " .. cmd .. " every " .. iv .. "s")
end

processCommand = function(message, speaker)
	if not isOperator(speaker) then return end

	if controlLocked then
		local cleaned2 = message
		if cleaned2:lower():sub(1,3) == "/w " then
			local s = cleaned2:find(" ", 4)
			if s then cleaned2 = cleaned2:sub(s+1) end
		end
		local firstWord = cleaned2:match("%.(%S+)")
		if firstWord and firstWord:lower() ~= "lockcontrol" then return end
	end

	local cleaned = message
	if cleaned:lower():sub(1,3) == "/w " then
		local spaceAfterName = cleaned:find(" ", 4)
		if spaceAfterName then cleaned = cleaned:sub(spaceAfterName+1) end
	end

	if cleaned:sub(1,1) ~= "." then return end

	local args = {}
	for word in cleaned:sub(2):gmatch("%S+") do table.insert(args, word) end

	local cmd = args[1] and args[1]:lower()
	if not cmd then return end
	table.remove(args, 1)
	local rest = table.concat(args, " ")

	if cmd == "follow" then
		if rest ~= "" then followPlayer(rest) end
	elseif cmd == "goto" then
		if rest ~= "" then goToPosition(rest) end
	elseif cmd == "patrol" then
		if #args > 0 then patrol(args) end
	elseif cmd == "looptp" then
		if rest ~= "" then loopTp(rest) end
	elseif cmd == "stop" then
		stopFollowing()
	elseif cmd == "say" then
		if rest ~= "" then sendChat(rest) end
	elseif cmd == "sit" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Sit = true end end
	elseif cmd == "stand" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Sit = false end end
	elseif cmd == "emote" or cmd == "e" then
		if rest ~= "" then doEmote(rest) end
	elseif cmd == "emotes" then
		local rig = getCharacterRig()
		if rig == "R6" then sendWhisper("R6: wave laugh dance dance2 dance3 cheer point")
		else sendWhisper("R15: any ugc emote you own") end
	elseif cmd == "speed" then
		local num = tonumber(args[1]) if num then setSpeed(num) end
	elseif cmd == "jump" then
		doJump()
	elseif cmd == "jumppower" then
		local num = tonumber(args[1]) if num then setJump(num) end
	elseif cmd == "noclip" then
		if rest == "on" then setNoclip(true) elseif rest == "off" then setNoclip(false) end
	elseif cmd == "freeze" then
		freezePlayer(true)
	elseif cmd == "unfreeze" then
		freezePlayer(false)
	elseif cmd == "tp" then
		if args[1] and not tonumber(args[1]) then
			tpToPlayer(rest)
		elseif args[1] and args[2] and args[3] then
			local x,y,z = tonumber(args[1]),tonumber(args[2]),tonumber(args[3])
			if x and y and z then tpToCoords(x,y,z) end
		end
	elseif cmd == "invisible" then
		if rest == "on" then setInvisibleFE(true) elseif rest == "off" then setInvisibleFE(false) end
	elseif cmd == "godmode" then
		if rest == "on" then setGodMode(true) elseif rest == "off" then setGodMode(false) end
	elseif cmd == "reset" then
		local char = localPlayer.Character
		if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.Health = 0 end end
	elseif cmd == "forward" or cmd == "fw" then
		moveDirection("forward", tonumber(args[1]) or 10)
	elseif cmd == "back" or cmd == "bw" then
		moveDirection("back", tonumber(args[1]) or 10)
	elseif cmd == "left" or cmd == "l" then
		moveDirection("left", tonumber(args[1]) or 10)
	elseif cmd == "right" or cmd == "r" then
		moveDirection("right", tonumber(args[1]) or 10)
	elseif cmd == "turnleft" or cmd == "tl" then
		turnDirection("left", tonumber(args[1]) or 90)
	elseif cmd == "turnright" or cmd == "tr" then
		turnDirection("right", tonumber(args[1]) or 90)
	elseif cmd == "lookat" then
		if rest ~= "" then lookAt(rest) end
	elseif cmd == "spin" then
		if rest == "on" then spinLoop(true) elseif rest == "off" then spinLoop(false) end
	elseif cmd == "fling" then fling()
	elseif cmd == "gravity" then
		local num = tonumber(args[1]) if num then setGravity(num) end
	elseif cmd == "gravityoff" then setGravity(0)
	elseif cmd == "gravityreset" then setGravity(196.2)
	elseif cmd == "float" then
		if rest == "on" then floatMode(true) elseif rest == "off" then floatMode(false) end
	elseif cmd == "bighead" then
		if rest == "on" then bigHead(true) elseif rest == "off" then bigHead(false) end
	elseif cmd == "crouch" then
		if rest == "on" then crouchMode(true) elseif rest == "off" then crouchMode(false) end
	elseif cmd == "lockcontrol" then
		if rest == "on" then lockControl(true) elseif rest == "off" then lockControl(false) end
	elseif cmd == "mirror" then
		if rest == "on" then startMirror() elseif rest == "off" then stopMirror() end
	elseif cmd == "transparency" then
		local num = tonumber(args[1])
		if num then setTransparency(math.clamp(num, 0, 1)) end
	elseif cmd == "size" then
		local num = tonumber(args[1])
		if num then setSize(num) end
	elseif cmd == "savepos" then
		savedPosition = savePosition()
		if savedPosition then sendWhisper("Position saved.") end
	elseif cmd == "loadpos" then
		if savedPosition then
			local char = localPlayer.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then root.CFrame = savedPosition end
			end
		else
			sendWhisper("No saved position.")
		end
	elseif cmd == "tpme" then
		local operator = findPlayer(OPERATOR)
		if operator and operator.Character then
			local opRoot = operator.Character:FindFirstChild("HumanoidRootPart")
			local myChar = localPlayer.Character
			if myChar and opRoot then
				local myRoot = myChar:FindFirstChild("HumanoidRootPart")
				if myRoot then myRoot.CFrame = opRoot.CFrame + Vector3.new(3, 0, 0) end
			end
		end
	elseif cmd == "orbit" then
		stopFollowing()
		local target = findPlayer(rest ~= "" and rest or OPERATOR)
		if not target then return end
		following = target
		local angle = 0
		local radius = 8
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
			local x = targetRoot.Position.X + math.cos(angle) * radius
			local z = targetRoot.Position.Z + math.sin(angle) * radius
			myHum:MoveTo(Vector3.new(x, targetRoot.Position.Y, z))
		end)
	elseif cmd == "dance" then
		dance(args[1] or "")
	elseif cmd == "wave" then
		doEmote("wave")
	elseif cmd == "laugh" then
		doEmote("laugh")
	elseif cmd == "cheer" then
		doEmote("cheer")
	elseif cmd == "point" then
		doEmote("point")
	elseif cmd == "health" then
		local char = localPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then sendWhisper("HP: " .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) end
		end
	elseif cmd == "pos" then
		local char = localPlayer.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				local p = root.Position
				sendWhisper("Pos: " .. math.floor(p.X) .. ", " .. math.floor(p.Y) .. ", " .. math.floor(p.Z))
			end
		end
	elseif cmd == "rig" then
		sendWhisper("Rig: " .. (getCharacterRig() or "Unknown"))
	elseif cmd == "loop" then
		if rest ~= "" then
			local parts = {}
			for w in rest:gmatch("%S+") do table.insert(parts, w) end
			local interval = tonumber(parts[#parts])
			local cmdPart
			if interval then
				table.remove(parts, #parts)
				cmdPart = table.concat(parts, " ")
			else
				interval = 1
				cmdPart = rest
			end
			if cmdPart ~= "" then startLoop(cmdPart, interval) end
		end
	elseif cmd == "loopstop" then
		stopLoop()
	elseif cmd == "status" then
		sendWhisper(
			(following and "Following." or "Idle.") .. " " ..
			(loopCmd and ("Loop: " .. loopCmd) or "No loop.") .. " " ..
			(controlLocked and "LOCKED." or "Unlocked.") .. " " ..
			(mirrorEnabled and "Mirroring." or "No mirror.")
		)
	elseif cmd == "commands" then
		sendWhisper(".follow .goto .patrol .looptp .orbit .stop .say .sit .stand .e .wave .laugh .cheer .point .dance .speed .jump .jumppower .noclip .freeze .unfreeze .tp .tpme .invisible .godmode .reset .fw .bw .l .r .tl .tr .lookat .spin .fling .gravity .gravityoff .gravityreset .float .bighead .crouch .lockcontrol .mirror .transparency .size .savepos .loadpos .health .pos .rig .loop .loopstop .status")
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		processCommand(message, player.Name)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		processCommand(message, player.Name)
	end)
end

sendWhisper("Robot ready. Listening to " .. OPERATOR)
