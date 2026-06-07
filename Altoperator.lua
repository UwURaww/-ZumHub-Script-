local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local quickTabGui = nil
local quickTabVisible = false

local function sendWhisper(message)
	game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
		Text = "[Operator] " .. message,
		Color = Color3.fromRGB(255, 180, 80),
		FontSize = Enum.FontSize.Size18,
	})
end

local lastSent = 0
local COOLDOWN = 0.8

local function sendCommand(cmd)
	local now = tick()
	if now - lastSent < COOLDOWN then return end
	lastSent = now
	local general = game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
	if general then general:SendAsync(cmd) end
end

local COMMANDS = {
	{label = ".follow me", cmd = ".follow me"},
	{label = ".follow [name]", cmd = nil, input = true},
	{label = ".goto [name]", cmd = nil, input = true},
	{label = ".patrol [n1 n2]", cmd = nil, input = true},
	{label = ".looptp [name]", cmd = nil, input = true},
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
	{label = ".fw 10", cmd = ".fw 10"},
	{label = ".bw 10", cmd = ".bw 10"},
	{label = ".l 10", cmd = ".l 10"},
	{label = ".r 10", cmd = ".r 10"},
	{label = ".tl 90", cmd = ".tl 90"},
	{label = ".tr 90", cmd = ".tr 90"},
	{label = ".speed 16", cmd = ".speed 16"},
	{label = ".speed 50", cmd = ".speed 50"},
	{label = ".jumppower 50", cmd = ".jumppower 50"},
	{label = ".jumppower 150", cmd = ".jumppower 150"},
	{label = ".status", cmd = ".status"},
	{label = ".e wave", cmd = ".e wave"},
	{label = ".e dance", cmd = ".e dance"},
	{label = ".e laugh", cmd = ".e laugh"},
	{label = ".e cheer", cmd = ".e cheer"},
	{label = ".lookat [name]", cmd = nil, input = true},
	{label = ".say [text]", cmd = nil, input = true},
	{label = ".tp [name]", cmd = nil, input = true},
	{label = ".gravity [num]", cmd = nil, input = true},
}

local function createQuickTab()
	if quickTabGui then quickTabGui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuickTab"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = localPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 500)
	frame.Position = UDim2.new(0.5, -210, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -10, 0, 35)
	title.Position = UDim2.new(0, 5, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = "QUICK TAB"
	title.TextColor3 = Color3.fromRGB(255, 180, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -35, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		quickTabGui:Destroy()
		quickTabGui = nil
		quickTabVisible = false
	end)

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -20, 0, 32)
	inputBox.Position = UDim2.new(0, 10, 0, 42)
	inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	inputBox.PlaceholderText = "type argument here then click command..."
	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
	inputBox.Text = ""
	inputBox.TextScaled = true
	inputBox.Font = Enum.Font.Gotham
	inputBox.BorderSizePixel = 0
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = frame
	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, 6)
	ic.Parent = inputBox

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -10, 1, -90)
	scrollFrame.Position = UDim2.new(0, 5, 0, 82)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 180, 80)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 125, 0, 36)
	layout.CellPadding = UDim2.new(0, 6, 0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = scrollFrame

	for _, data in ipairs(COMMANDS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 125, 0, 36)
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		btn.TextColor3 = Color3.fromRGB(220, 220, 255)
		btn.Text = data.label
		btn.TextScaled = true
		btn.Font = Enum.Font.Gotham
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Parent = scrollFrame

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if data.cmd then
				sendCommand(data.cmd)
				sendWhisper("Sent: " .. data.cmd)
			elseif data.input then
				local arg = inputBox.Text
				if arg == "" then
					sendWhisper("Type argument in the box first!")
					return
				end
				local base = data.label:match("^(%.[%a]+)")
				if base then
					local full = base .. " " .. arg
					sendCommand(full)
					sendWhisper("Sent: " .. full)
				end
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
	elseif lower == ".commands" then
		for _, data in ipairs(COMMANDS) do
			sendWhisper(data.label)
		end
	end
end)

print("Operator ready. Type .quicktab or .commands")

