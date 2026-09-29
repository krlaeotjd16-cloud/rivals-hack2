--[[
    Rivals — Xeno Fix
    Aimbot + ESP + Unnamed-style GUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 140,
        Smooth = 0.25,
        TeamCheck = true,
        TargetPart = "Head",
        ShowFOV = true,
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 1200,
        Color = Color3.fromRGB(255, 40, 40),
    },
}

local State = {
    AimHolding = false,
    GUIVisible = true,
}

-- ===================== UTILS =====================
local function alive(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function enemy(plr)
    if not Config.Aimbot.TeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return plr.Team ~= LocalPlayer.Team
end

local function getTarget()
    local best, bestDist = nil, Config.Aimbot.FOV
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and alive(plr) and enemy(plr) then
            local part = plr.Character:FindFirstChild(Config.Aimbot.TargetPart)
                or plr.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

-- ===================== ESP (Highlight + 재적용) =====================
local highlights = {}

local function applyHighlight(plr)
    if highlights[plr] then
        highlights[plr]:Destroy()
        highlights[plr] = nil
    end
    if not Config.ESP.Enabled then return end
    if not alive(plr) or (Config.ESP.TeamCheck and not enemy(plr)) then return end

    local char = plr.Character
    if not char then return end

    local hl = Instance.new("Highlight")
    hl.Name = "RivalsESP"
    hl.FillColor = Config.ESP.Color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    highlights[plr] = hl
end

local function refreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            applyHighlight(plr)
        end
    end
end

-- 캐릭터 다시 생길 때마다 ESP 재적용
local function hookCharacter(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.8)
        applyHighlight(plr)
    end)
    if plr.Character then
        applyHighlight(plr)
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then hookCharacter(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    hookCharacter(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
    if highlights[plr] then
        highlights[plr]:Destroy()
        highlights[plr] = nil
    end
end)

-- ===================== AIMBOT =====================
local function doAim()
    if not Config.Aimbot.Enabled or not State.AimHolding then return end
    local target = getTarget()
    if not target then return end

    local camPos = Camera.CFrame.Position
    local look = CFrame.lookAt(camPos, target.Position)
    -- 부드럽게 회전 (Xeno에서 가장 안정적)
    Camera.CFrame = Camera.CFrame:Lerp(look, Config.Aimbot.Smooth)
end

-- ===================== GUI (Unnamed 스타일) =====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RivalsUnnamed"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 380, 0, 280)
Main.Position = UDim2.new(0.5, -190, 0.5, -140)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = Main

-- 상단 바
local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 28)
Top.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
Top.BorderSizePixel = 0
Top.Parent = Main

local TopC = Instance.new("UICorner")
TopC.CornerRadius = UDim.new(0, 6)
TopC.Parent = Top

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Unnamed  |  Rivals"
Title.TextColor3 = Color3.fromRGB(210, 210, 220)
Title.TextSize = 13
Title.Font = Enum.Font.GothamMedium
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

-- 탭 버튼 영역
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 26)
TabBar.Position = UDim2.new(0, 0, 0, 28)
TabBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local function makeTab(name, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 70, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundTransparency = 1
    b.Text = name
    b.TextColor3 = Color3.fromRGB(160, 160, 170)
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.Parent = TabBar
    return b
end

local tabAim = makeTab("aimbot", 8)
local tabEsp = makeTab("esp", 80)
local tabMisc = makeTab("misc", 152)

-- 컨텐츠
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -70)
Content.Position = UDim2.new(0, 8, 0, 60)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function clearContent()
    for _, v in ipairs(Content:GetChildren()) do
        v:Destroy()
    end
end

local function addToggle(text, y, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = Content

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 18)
    btn.Position = UDim2.new(1, -42, 0.5, -9)
    btn.BackgroundColor3 = default and Color3.fromRGB(0, 160, 70) or Color3.fromRGB(55, 55, 65)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 3)
    c.Parent = btn

    local on = default
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(0, 160, 70) or Color3.fromRGB(55, 55, 65)
        callback(on)
    end)
end

local function showAim()
    clearContent()
    tabAim.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabEsp.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabMisc.TextColor3 = Color3.fromRGB(160, 160, 170)

    addToggle("enabled", 0, Config.Aimbot.Enabled, function(v)
        Config.Aimbot.Enabled = v
    end)
    addToggle("team check", 28, Config.Aimbot.TeamCheck, function(v)
        Config.Aimbot.TeamCheck = v
        Config.ESP.TeamCheck = v
        refreshAllESP()
    end)
    addToggle("show fov", 56, Config.Aimbot.ShowFOV, function(v)
        Config.Aimbot.ShowFOV = v
    end)
end

local function showEsp()
    clearContent()
    tabAim.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabEsp.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabMisc.TextColor3 = Color3.fromRGB(160, 160, 170)

    addToggle("enabled", 0, Config.ESP.Enabled, function(v)
        Config.ESP.Enabled = v
        refreshAllESP()
    end)
    addToggle("team check", 28, Config.ESP.TeamCheck, function(v)
        Config.ESP.TeamCheck = v
        refreshAllESP()
    end)
end

local function showMisc()
    clearContent()
    tabAim.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabEsp.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabMisc.TextColor3 = Color3.fromRGB(255, 255, 255)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "Keybinds\nE = Hold Aimbot\nRightShift = Toggle GUI"
    info.TextColor3 = Color3.fromRGB(180, 180, 190)
    info.TextSize = 12
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = Content
end

tabAim.MouseButton1Click:Connect(showAim)
tabEsp.MouseButton1Click:Connect(showEsp)
tabMisc.MouseButton1Click:Connect(showMisc)

showAim() -- 기본 탭

-- ===================== INPUT =====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        State.AimHolding = true
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        State.GUIVisible = not State.GUIVisible
        Main.Visible = State.GUIVisible
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        State.AimHolding = false
    end
end)

-- ===================== LOOP =====================
RunService.RenderStepped:Connect(function()
    doAim()
end)

-- 매치 들어가도 ESP 유지되게 주기적 새로고침
task.spawn(function()
    while true do
        task.wait(3)
        if Config.ESP.Enabled then
            refreshAllESP()
        end
    end
end)

print("[Rivals] Xeno fixed | E = Aim | RightShift = GUI")
