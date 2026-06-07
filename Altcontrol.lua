local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local OPERATOR = "zumartengge6no10"
local OPERATOR_DISPLAY = "mop"

local following = nil
local followConnection = nil
local speedValue = 16
local jumpValue = 50
local noclipConnection = nil
local godModeConnection = nil

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
			local desiredPos = targetPos - direction * 4
			myHum:MoveTo(desiredPos)
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
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		root.Anchored = true
	else
		hum.WalkSpeed = speedValue
		hum.JumpPower = jumpValue
		root.Anchored = false
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
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.Transparency = 0
			end
		end
	end
end

local function setGodMode(enabled)
	if godModeConnection then
		godModeConnection:Disconnect()
		godModeConnection = nil
	end
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
		root.Velocity = Vector3.new(math.random(-100, 100), 200, math.random(-100, 100))
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
	if head then
		head.Size = enabled and Vector3.new(4, 4, 4) or Vector3.new(2, 1, 1)
	end
end

local function processCommand(message, speaker)
	if not isOperator(speaker) then return end

	local cleaned = message
	if cleaned:lower():sub(1, 3) == "/w " then
		local spaceAfterName = cleaned:find(" ", 4)
		if spaceAfterName then
			cleaned = cleaned:sub(spaceAfterName + 1)
		end
	end

	if cleaned:sub(1, 1) ~= "." then return end

	local args = {}
	for word in cleaned:sub(2):gmatch("%S+") do
		table.insert(args, word)
	end

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
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Sit = true end
		end
	elseif cmd == "stand" then
		local char = localPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Sit = false end
		end
	elseif cmd == "emote" or cmd == "e" then
		if rest ~= "" then doEmote(rest) end
	elseif cmd == "emotes" then
		local rig = getCharacterRig()
		if rig == "R6" then sendWhisper("R6: wave laugh dance dance2 dance3 cheer point")
		else sendWhisper("R15: any ugc emote you own") end
	elseif cmd == "speed" then
		local num = tonumber(args[1])
		if num then setSpeed(num) end
	elseif cmd == "jump" then
		doJump()
	elseif cmd == "jumppower" then
		local num = tonumber(args[1])
		if num then setJump(num) end
	elseif cmd == "noclip" then
		if rest == "on" then setNoclip(true)
		elseif rest == "off" then setNoclip(false) end
	elseif cmd == "freeze" then
		freezePlayer(true)
	elseif cmd == "unfreeze" then
		freezePlayer(false)
	elseif cmd == "tp" then
		if args[1] and not tonumber(args[1]) then
			tpToPlayer(rest)
		elseif args[1] and args[2] and args[3] then
			local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
			if x and y and z then tpToCoords(x, y, z) end
		end
	elseif cmd == "invisible" then
		if rest == "on" then setInvisibleFE(true)
		elseif rest == "off" then setInvisibleFE(false) end
	elseif cmd == "godmode" then
		if rest == "on" then setGodMode(true)
		elseif rest == "off" then setGodMode(false) end
	elseif cmd == "reset" then
		local char = localPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end
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
		if rest == "on" then spinLoop(true)
		elseif rest == "off" then spinLoop(false) end
	elseif cmd == "fling" then
		fling()
	elseif cmd == "gravity" then
		local num = tonumber(args[1])
		if num then setGravity(num) end
	elseif cmd == "gravityoff" then
		setGravity(0)
	elseif cmd == "gravityreset" then
		setGravity(196.2)
	elseif cmd == "float" then
		if rest == "on" then floatMode(true)
		elseif rest == "off" then floatMode(false) end
	elseif cmd == "bighead" then
		if rest == "on" then bigHead(true)
		elseif rest == "off" then bigHead(false) end
	elseif cmd == "status" then
		if following then sendWhisper("Active.")
		else sendWhisper("Idle.") end
	elseif cmd == "commands" then
		sendWhisper(".follow .goto .patrol .looptp .stop .say .sit .stand .e .emotes .speed .jump .jumppower .noclip .freeze .unfreeze .tp .invisible .godmode .reset .fw .bw .l .r .tl .tr .lookat .spin .fling .gravity .gravityoff .gravityreset .float .bighead .status")
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
