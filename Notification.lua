-- SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

-- CONFIG
local youtubeLink = "https://youtube.com/@zmh.j?si=6AM8ohF_7NQqP1K4"
local duration = 6
local maxStack = 3

-- SAFE CALL
local function safeCall(f) pcall(f) end

-- GUI ROOT
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "ProNotifSystem"
gui.IgnoreGuiInset = false

-- SAFE AREA (hindari top bar)
local inset = GuiService:GetGuiInset()

-- CONTAINER (top right, aman dari jump button)
local container = Instance.new("Frame", gui)
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, -10, 0, inset.Y + 10)
container.Size = UDim2.new(0.35, 0, 1, 0)
container.BackgroundTransparency = 1

-- LAYOUT STACK
local layout = Instance.new("UIListLayout", container)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.VerticalAlignment = Enum.VerticalAlignment.Top

-- SCALE (responsif semua DPI)
local scale = Instance.new("UIScale", container)
scale.Scale = 1

-- AUTO SCALE BASED ON SCREEN
local function updateScale()
    local size = workspace.CurrentCamera.ViewportSize
    if size.X < 600 then
        scale.Scale = 0.8
    elseif size.X > 1200 then
        scale.Scale = 1.2
    else
        scale.Scale = 1
    end
end

updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- NOTIFICATION CREATE
local function createNotif(text)
    -- LIMIT STACK
    if #container:GetChildren() > maxStack then
        container:GetChildren()[1]:Destroy()
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 110)
    frame.BackgroundColor3 = Color3.fromRGB(12,12,12)
    frame.BorderSizePixel = 0
    frame.Parent = container

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    -- GLOW
    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 2

    local glow = Instance.new("UIStroke", frame)
    glow.Thickness = 6
    glow.Transparency = 0.7

    -- RAINBOW LOOP
    task.spawn(function()
        while frame.Parent do
            for i = 0,1,0.02 do
                local c = Color3.fromHSV(i,1,1)
                stroke.Color = c
                glow.Color = c
                task.wait(0.03)
            end
        end
    end)

    -- TITLE
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -20, 0.3, 0)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.Text = "SUBSCRIBE"
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(0,255,255)
    title.BackgroundTransparency = 1

    -- DESC
    local desc = Instance.new("TextLabel", frame)
    desc.Size = UDim2.new(1, -20, 0.4, 0)
    desc.Position = UDim2.new(0, 10, 0.3, 0)
    desc.Text = text
    desc.TextWrapped = true
    desc.TextScaled = true
    desc.TextColor3 = Color3.fromRGB(200,200,200)
    desc.BackgroundTransparency = 1

    -- PROGRESS
    local barBg = Instance.new("Frame", frame)
    barBg.Size = UDim2.new(1, -20, 0.06, 0)
    barBg.Position = UDim2.new(0, 10, 0.7, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)

    local bar = Instance.new("Frame", barBg)
    bar.Size = UDim2.new(1,0,1,0)
    bar.BackgroundColor3 = Color3.fromRGB(0,255,255)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    -- BUTTONS
    local yes = Instance.new("TextButton", frame)
    yes.Size = UDim2.new(0.45,0,0.25,0)
    yes.Position = UDim2.new(0.05,0,0.75,0)
    yes.Text = "Sure!"
    yes.TextScaled = true
    yes.BackgroundColor3 = Color3.fromRGB(0,200,255)
    yes.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", yes)

    local no = Instance.new("TextButton", frame)
    no.Size = UDim2.new(0.45,0,0.25,0)
    no.Position = UDim2.new(0.5,0,0.75,0)
    no.Text = "No thanks"
    no.TextScaled = true
    no.BackgroundColor3 = Color3.fromRGB(40,40,40)
    no.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", no)

    -- SOUND
    local sound = Instance.new("Sound", frame)
    sound.SoundId = "rbxassetid://9118823103"
    sound.Volume = 2
    sound:Play()

    -- PROGRESS ANIM
    TweenService:Create(bar, TweenInfo.new(duration), {
        Size = UDim2.new(0,0,1,0)
    }):Play()

    -- CLOSE
    local function close()
        local t = TweenService:Create(frame, TweenInfo.new(0.3), {
            BackgroundTransparency = 1
        })
        t:Play()
        t.Completed:Wait()
        frame:Destroy()
    end

    yes.MouseButton1Click:Connect(function()
        safeCall(function()
            setclipboard(youtubeLink)
        end)
        desc.Text = "Link copied!"
        safeCall(function()
            openbrowser(youtubeLink)
        end)
    end)

    no.MouseButton1Click:Connect(close)

    task.delay(duration, function()
        if frame.Parent then
            close()
        end
    end)
end

-- TEST CALL
createNotif("Support me by subscribing to my YouTube channel!")
