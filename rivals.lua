--[[
    Rivals — Xeno Compatible Version
    Aimbot + Simple ESP + GUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Config = {
    Aimbot = {
        Enabled = true,
        Key = Enum.KeyCode.E,
        FOV = 130,
        Smoothness = 0.2,
        TeamCheck = true,
        TargetPart = "Head",
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 800,
    },
}

local State = {
    AimbotActive = false,
    GUIVisible = true,
}

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isEnemy(player)
    if not Config.Aimbot.TeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getClosest()
    local best, bestDist = nil, Config.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and isEnemy(plr) then
            local char = plr.Character
            local part = char:FindFirstChild(Config.Aimbot.TargetPart) or char:FindFirstChild("HumanoidRootPart")
            if part then
                local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - mousePos).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
    end
    return best
end

-- 간단한 ESP (Highlight 사용 — Drawing 대신)
local highlights = {}

local function createESP(player)
    if highlights[player] then return end
    local hl = Instance.new("Highlight")
    hl.Name = "RivalsESP"
    hl.FillColor = Color3.fromRGB(255, 50, 50)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlights[player] = hl
end

local function removeESP(player)
    if highlights[player] then
        highlights[player]:Destroy()
        highlights[player] = nil
    end
end

local function updateESP()
    for plr, hl in pairs(highlights) do
        if not isAlive(plr) or (Config.ESP.TeamCheck and not isEnemy(plr)) then
            hl.Parent = nil
        else
            local char = plr.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - Camera.CFrame.Position).Magnitude
                    if dist <= Config.ESP.MaxDistance then
                        hl.Parent = char
                    else
                        hl.Parent = nil
                    end
                end
            end
        end
    end
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RivalsXeno"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 280, 0, 180)
Main.Position = UDim2.new(0.5, -140, 0.5, -90)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 6)
Corner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.Text = "Rivals  |  Xeno"
Title.TextColor3 = Color3.fromRGB(220, 220, 220)
Title.TextSize = 14
Title.Font = Enum.Font.GothamMedium
Title.Parent = Main

local TC = Instance.new("UICorner")
TC.CornerRadius = UDim.new(0, 6)
TC.Parent = Title

local function makeBtn(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 28)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.TextSize = 13
    btn.Font = Enum.Font.Gotham
    btn.Parent = Main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local aimBtn = makeBtn("Aimbot: ON", 40, function()
    Config.Aimbot.Enabled = not Config.Aimbot.Enabled
    aimBtn.Text = "Aimbot: " .. (Config.Aimbot.Enabled and "ON" or "OFF")
end)

local espBtn = makeBtn("ESP: ON", 75, function()
    Config.ESP.Enabled = not Config.ESP.Enabled
    espBtn.Text = "ESP: " .. (Config.ESP.Enabled and "ON" or "OFF")
end)

local teamBtn = makeBtn("TeamCheck: ON", 110, function()
    Config.Aimbot.TeamCheck = not Config.Aimbot.TeamCheck
    Config.ESP.TeamCheck = Config.Aimbot.TeamCheck
    teamBtn.Text = "TeamCheck: " .. (Config.Aimbot.TeamCheck and "ON" or "OFF")
end)

makeBtn("Close GUI (RightShift)", 145, function()
    Main.Visible = false
    State.GUIVisible = false
end)

-- Input
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.Aimbot.Key then
        State.AimbotActive = true
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        State.GUIVisible = not State.GUIVisible
        Main.Visible = State.GUIVisible
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Config.Aimbot.Key then
        State.AimbotActive = false
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function()
    if Config.Aimbot.Enabled and State.AimbotActive then
        local target = getClosest()
        if target then
            local pos = Camera:WorldToViewportPoint(target.Position)
            local mousePos = UserInputService:GetMouseLocation()
            local delta = Vector2.new(pos.X, pos.Y) - mousePos
            -- Xeno에서 mousemoverel이 없을 수 있어서 안전하게
            if mousemoverel then
                mousemoverel(delta.X * (1 - Config.Aimbot.Smoothness), delta.Y * (1 - Config.Aimbot.Smoothness))
            else
                -- 대안: 카메라 회전
                local cf = CFrame.lookAt(Camera.CFrame.Position, target.Position)
                Camera.CFrame = Camera.CFrame:Lerp(cf, 0.3)
            end
        end
    end

    if Config.ESP.Enabled then
        updateESP()
    end
end)

-- Player handling
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then createESP(plr) end
end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

print("[Rivals] Xeno version loaded | E = Aim | RightShift = GUI")
