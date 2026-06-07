print("IT work") 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local OPERATOR = "zumartengge6no10"

local following = nil
local followConnection = nil
local speedValue = 16
local jumpValue = 50
local noclipConnection = nil

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
	if general then
		general:SendAsync("/e " .. emoteName)
	end
end

local function sendChat(message)
	task.wait(math.random(4, 12) / 10)
	local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if general then
		general:SendAsync(message)
	end
end

local function stopFollowing()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	following = nil
end

local function followPlayer(targetName)
	stopFollowing()
	local target = nil
	if targetName == "me" then
		target = Players:FindFirstChild(OPERATOR)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower():find(targetName:lower()) or p.DisplayName:lower():find(targetName:lower()) then
				target = p
				break
			end
		end
	end
	if not target or not target.Character then return end
	following = target
	followConnection = RunService.Heartbeat:Connect(function()
		if not following or not following.Character then stopFollowing() return end
		local myChar = localPlayer.Character
		local targetChar = following.Character
		if not myChar or not targetChar then return end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
		local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
		if not myRoot or not targetRoot or not myHumanoid then return end
		local distance = (myRoot.Position - targetRoot.Position).Magnitude
		if distance > 5 then
			myHumanoid:MoveTo(targetRoot.Position)
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
	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(targetName:lower()) or p.DisplayName:lower():find(targetName:lower()) then
			target = p
			break
		end
	end
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

local function setInvisible(enabled)
	local char = localPlayer.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.Transparency = enabled and 1 or 0
		end
	end
end

local function loopTp(targetName)
	stopFollowing()
	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(targetName:lower()) or p.DisplayName:lower():find(targetName:lower()) then
			target = p
			break
		end
	end
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

local function processCommand(message, speaker)
	if speaker ~= OPERATOR then return end
	if message:sub(1, 1) ~= "." then return end

	local args = {}
	for word in message:sub(2):gmatch("%S+") do
		table.insert(args, word)
	end

	local cmd = args[1] and args[1]:lower()
	if not cmd then return end
	table.remove(args, 1)
	local rest = table.concat(args, " ")

	if cmd == "follow" then
		if rest ~= "" then followPlayer(rest) end

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
		if rig == "R6" then
			sendWhisper("R6: wave laugh dance dance2 dance3 cheer point")
		else
			sendWhisper("R15: any ugc emote you own")
		end

	elseif cmd == "speed" then
		local num = tonumber(args[1])
		if num then setSpeed(num) end

	elseif cmd == "jump" then
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
		if rest == "on" then setInvisible(true)
		elseif rest == "off" then setInvisible(false) end

	elseif cmd == "reset" then
		local char = localPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end

	elseif cmd == "status" then
		if following then
			sendWhisper("Tracking: " .. following.DisplayName)
		else
			sendWhisper("Idle.")
		end

	elseif cmd == "commands" then
		sendWhisper(".follow .looptp .stop .say .sit .stand .e .speed .jump .noclip .freeze .unfreeze .tp .invisible .reset .status")
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
