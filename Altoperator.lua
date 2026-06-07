print("operator ready") 

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local function sendWhisper(message)
	game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
		Text = "[Operator] " .. message,
		Color = Color3.fromRGB(255, 180, 80),
		FontSize = Enum.FontSize.Size18,
	})
end

local COMMANDS = {
	".follow [name/me]", ".goto [name]", ".patrol [n1] [n2]",
	".looptp [name]", ".stop",
	".say [text]", ".sit", ".stand",
	".e [emote]", ".emotes",
	".speed [num]", ".jump", ".jumppower [num]",
	".noclip on/off", ".freeze", ".unfreeze",
	".tp [name] or [x y z]", ".invisible on/off",
	".reset", ".fw [studs]", ".bw [studs]",
	".l [studs]", ".r [studs]",
	".tl [deg]", ".tr [deg]",
	".lookat [name]", ".spin on/off", ".status"
}

localPlayer.Chatted:Connect(function(message)
	if message:lower() == ".commands" then
		for _, cmd in ipairs(COMMANDS) do
			sendWhisper(cmd)
		end
	end
end)

sendWhisper("Operator ready. Type .commands to see all.")
