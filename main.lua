--[[
    =============================================================================
    MIMI.FORGE // RUNTIME INSTRUMENTATION & COMBAT TELEMETRY CLIENT
    =============================================================================
    Architecture: Modular Client-Side Analytic & Visual System
    Platform: Universal Luau (Roblox Client Engine)
    Distribution: GitHub Loadstring Ready
    =============================================================================
--]]

-- [ENVIRONMENT PREPARATION & CLEANUP]
if getgenv and getgenv()._MIMI_ACTIVE then
    pcall(function() getgenv()._MIMI_UNLOAD() end)
end

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    HttpService = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    Stats = game:GetService("Stats"),
    CoreGui = game:GetService("CoreGui")
}

local LocalPlayer = Services.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Services.Workspace.CurrentCamera

-- Detect Drawing API support
local HasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")

-- [MASTER CONFIGURATION]
local Config = {
    MasterEnabled = true,

    -- Aim Module
    Aim = {
        Enabled = true,
        TargetSelector = "Crosshair", -- "Crosshair", "Distance", "Health"
        FOV = 130,
        AdjustableFOV = true,
        Priority = "Crosshair", -- "Crosshair", "Distance", "Health"
        Smoothness = 5, -- 1 = instant, higher = smoother
        SmoothnessVisual = true,
        TargetSwitching = true,
        LockIndicator = true,
        AimDirectionVis = true,
        LineOfSightCheck = true,
        AimKey = Enum.UserInputType.MouseButton2,
        AimKeyCode = Enum.KeyCode.E,
        UseKeyCode = false
    },

    -- Target Module
    Target = {
        HitboxVis = true,
        SelectedHitbox = "Head", -- "Head", "Torso", "Limbs", "Closest"
        HitboxTransparency = 0.45,
        HitboxColor = Color3.fromRGB(255, 45, 75),
        RaycastVis = true,
        ShowDistance = true
    },

    -- Visuals (ESP) Module
    Visuals = {
        Enabled = true,
        Boxes = true,
        Skeleton = true,
        Names = true,
        Distance = true,
        HealthBars = true,
        TeamCheck = false,
        VisibilityCheck = true,
        Tracers = true,
        TracerOrigin = "Bottom", -- "Bottom", "Center", "Mouse"
        MaxDistance = 1200,
        BoxColor = Color3.fromRGB(255, 42, 77),
        BoxOccludedColor = Color3.fromRGB(160, 20, 45),
        SkeletonColor = Color3.fromRGB(240, 240, 245),
        NameColor = Color3.fromRGB(255, 255, 255),
        DistanceColor = Color3.fromRGB(200, 200, 210),
        TracerColor = Color3.fromRGB(255, 42, 77)
    },

    -- Crosshair Module
    Crosshair = {
        Enabled = true,
        Size = 12,
        Thickness = 2,
        Gap = 6,
        Opacity = 0.95,
        Color = Color3.fromRGB(255, 42, 77),
        DynamicMovement = true,
        DynamicShooting = true,
        Hitmarker = true,
        HitmarkerSize = 10,
        HitmarkerColor = Color3.fromRGB(255, 255, 255)
    },

    -- Combat & Telemetry Module
    Combat = {
        MovingTargets = true,
        StrafingTargets = true,
        TargetSpeedFactor = 1.0,
        ReactionTracker = true,
        TrackAccuracy = true,
        TrackHeadshots = true,
        TrackDamage = true
    },

    -- HUD Module
    HUD = {
        Enabled = true,
        ShowCurrentTarget = true,
        ShowFOV = true,
        ShowDistance = true,
        ShowFPS = true,
        ShowPing = true,
        ShowAccuracy = true,
        ShowHits = true,
        ShowMisses = true
    },

    -- Settings
    Settings = {
        UIKeybind = Enum.KeyCode.RightShift,
        UIOpacity = 0.95,
        RedGlowIntensity = 1.0,
        AnimationSpeed = 1.0,
        ConfigFile = "mimi_instrumentation_config.json"
    }
}

-- [RUNTIME TELEMETRY STATE]
local Telemetry = {
    Shots = 0,
    Hits = 0,
    Misses = 0,
    Headshots = 0,
    TotalDamage = 0,
    Accuracy = 0,
    FPS = 60,
    Ping = 0,
    ReactionTime = 0,
    TargetAcquisitionTimestamp = 0,
    LastTargetHealth = 0,
    CurrentTarget = nil,
    IsAiming = false,
    IsFiring = false,
    HitmarkerAlpha = 0
}

-- [CONNECTION REGISTRY FOR SAFE UNLOAD]
local Registry = {
    Events = {},
    Drawings = {},
    VisualPool = {},
    GuiInstances = {}
}

local function RegisterEvent(connection)
    table.insert(Registry.Events, connection)
    return connection
end

-- [MATHEMATICAL & VECTOR UTILITIES]
local function WorldToScreen(worldPoint)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPoint)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

local function GetScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function GetMouseLocation()
    return Services.UserInputService:GetMouseLocation()
end

local function GetCharacter(player)
    if not player then return nil end
    return player.Character
end

local function GetRootPart(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function GetHumanoid(character)
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(character)
    local hum = GetHumanoid(character)
    return hum and hum.Health > 0
end

local function IsTeammate(player)
    if not Config.Visuals.TeamCheck then return false end
    if player == LocalPlayer then return true end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

-- Line of Sight Raycast
local function CheckLineOfSight(origin, targetPos, targetCharacter)
    local ignoreList = { Camera, LocalPlayer.Character }
    local params = RaycastParams.new()
    params.FilterType = RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = true

    local direction = (targetPos - origin)
    local result = Services.Workspace:Raycast(origin, direction, params)

    if not result then return true end
    if result.Instance and targetCharacter and result.Instance:IsDescendantOf(targetCharacter) then
        return true
    end
    return false
end

-- [TARGET RESOLUTION ENGINE]
local function ResolveTargetPart(character, preference)
    if not character then return nil end
    if preference == "Head" then
        return character:FindFirstChild("Head") or GetRootPart(character)
    elseif preference == "Torso" then
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif preference == "Limbs" then
        local limbCandidates = {
            character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"),
            character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"),
            character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg"),
            character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
        }
        for _, part in ipairs(limbCandidates) do
            if part then return part end
        end
        return GetRootPart(character)
    elseif preference == "Closest" then
        local mousePos = GetMouseLocation()
        local bestPart = nil
        local minDistance = math.huge
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") then
                local screenPos, onScreen = WorldToScreen(child.Position)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        bestPart = child
                    end
                end
            end
        end
        return bestPart or GetRootPart(character)
    end
    return character:FindFirstChild("Head") or GetRootPart(character)
end

local function GetBestCandidate()
    if not Config.MasterEnabled or not Config.Aim.Enabled then return nil, nil end

    local bestPlayer = nil
    local bestPart = nil
    local bestScore = math.huge
    local mousePos = GetMouseLocation()
    local screenCenter = GetScreenCenter()

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsTeammate(player) then
            local char = GetCharacter(player)
            if char and IsAlive(char) then
                local root = GetRootPart(char)
                if root then
                    local part = ResolveTargetPart(char, Config.Target.SelectedHitbox)
                    if part then
                        local screenPos, onScreen, depth = WorldToScreen(part.Position)
                        if onScreen and depth > 0 then
                            local fovDist = (screenPos - mousePos).Magnitude
                            if fovDist <= Config.Aim.FOV then
                                local los = true
                                if Config.Aim.LineOfSightCheck then
                                    los = CheckLineOfSight(Camera.CFrame.Position, part.Position, char)
                                end

                                if los then
                                    local score = 0
                                    local dist3D = (Camera.CFrame.Position - part.Position).Magnitude
                                    local hum = GetHumanoid(char)
                                    local health = hum and hum.Health or 100

                                    if Config.Aim.Priority == "Crosshair" then
                                        score = fovDist
                                    elseif Config.Aim.Priority == "Distance" then
                                        score = dist3D
                                    elseif Config.Aim.Priority == "Health" then
                                        score = health
                                    end

                                    if score < bestScore then
                                        bestScore = score
                                        bestPlayer = player
                                        bestPart = part
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestPart
end

-- [BALLISTICS & TARGET TRACKING]
local function ApplySmoothAim(targetPart)
    if not targetPart then return end
    local targetPos = targetPart.Position

    -- Optional target velocity prediction for moving & strafing targets
    if Config.Combat.MovingTargets and targetPart.AssemblyLinearVelocity then
        local pingComp = (Telemetry.Ping / 1000) * Config.Combat.TargetSpeedFactor
        targetPos = targetPos + (targetPart.AssemblyLinearVelocity * pingComp)
    end

    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)

    local smoothRatio = math.clamp(1 / math.max(Config.Aim.Smoothness, 1), 0.05, 1)
    Camera.CFrame = currentCF:Lerp(targetCF, smoothRatio)
end

-- [DRAWING-BASED OVERLAY SYSTEM]
local DrawingObjects = {
    FOVCircle = nil,
    AimLine = nil,
    LockIndicatorText = nil,
    HitboxBox = nil,
    RaycastPath = nil,
    CrosshairLines = {},
    HitmarkerLines = {}
}

if HasDrawing then
    -- FOV Circle
    local fov = Drawing.new("Circle")
    fov.Thickness = 1.5
    fov.NumSides = 64
    fov.Radius = Config.Aim.FOV
    fov.Filled = false
    fov.Transparency = 0.8
    fov.Color = Config.Visuals.BoxColor
    fov.Visible = false
    DrawingObjects.FOVCircle = fov
    table.insert(Registry.Drawings, fov)

    -- Aim Direction Line
    local aimLine = Drawing.new("Line")
    aimLine.Thickness = 1.5
    aimLine.Transparency = 0.8
    aimLine.Color = Color3.fromRGB(255, 60, 90)
    aimLine.Visible = false
    DrawingObjects.AimLine = aimLine
    table.insert(Registry.Drawings, aimLine)

    -- Lock Indicator Tag
    local lockTag = Drawing.new("Text")
    lockTag.Size = 14
    lockTag.Center = true
    lockTag.Outline = true
    lockTag.Color = Color3.fromRGB(255, 45, 75)
    lockTag.Visible = false
    DrawingObjects.LockIndicatorText = lockTag
    table.insert(Registry.Drawings, lockTag)

    -- Target Raycast Path Visualizer
    local rayPath = Drawing.new("Line")
    rayPath.Thickness = 1.5
    rayPath.Transparency = 0.65
    rayPath.Color = Color3.fromRGB(0, 255, 170)
    rayPath.Visible = false
    DrawingObjects.RaycastPath = rayPath
    table.insert(Registry.Drawings, rayPath)

    -- Crosshair Lines (4 axes)
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = Config.Crosshair.Thickness
        line.Color = Config.Crosshair.Color
        line.Transparency = Config.Crosshair.Opacity
        line.Visible = false
        table.insert(DrawingObjects.CrosshairLines, line)
        table.insert(Registry.Drawings, line)
    end

    -- Hitmarker (4 diagonal lines forming an X)
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Config.Crosshair.HitmarkerColor
        line.Transparency = 1
        line.Visible = false
        table.insert(DrawingObjects.HitmarkerLines, line)
        table.insert(Registry.Drawings, line)
    end
end

-- Visual Overlay Pool per Player (Boxes, Skeletons, Labels, Tracers)
local function CreateVisualSet()
    if not HasDrawing then return nil end

    local set = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBarOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        SkeletonLines = {}
    }

    set.Box.Thickness = 1.5
    set.Box.Filled = false
    set.BoxOutline.Thickness = 3
    set.BoxOutline.Filled = false
    set.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    set.BoxOutline.Transparency = 0.5

    set.Name.Size = 13
    set.Name.Center = true
    set.Name.Outline = true

    set.Distance.Size = 12
    set.Distance.Center = true
    set.Distance.Outline = true

    set.HealthBarOutline.Filled = true
    set.HealthBarOutline.Color = Color3.fromRGB(15, 15, 18)
    set.HealthBarOutline.Transparency = 0.8

    set.HealthBar.Filled = true

    set.Tracer.Thickness = 1.5

    -- Allocate up to 14 bones for complex rigs
    for i = 1, 14 do
        local boneLine = Drawing.new("Line")
        boneLine.Thickness = 1.2
        boneLine.Color = Config.Visuals.SkeletonColor
        boneLine.Visible = false
        table.insert(set.SkeletonLines, boneLine)
        table.insert(Registry.Drawings, boneLine)
    end

    table.insert(Registry.Drawings, set.Box)
    table.insert(Registry.Drawings, set.BoxOutline)
    table.insert(Registry.Drawings, set.Name)
    table.insert(Registry.Drawings, set.Distance)
    table.insert(Registry.Drawings, set.HealthBarOutline)
    table.insert(Registry.Drawings, set.HealthBar)
    table.insert(Registry.Drawings, set.Tracer)

    return set
end

local function HideVisualSet(set)
    if not set then return end
    set.Box.Visible = false
    set.BoxOutline.Visible = false
    set.Name.Visible = false
    set.Distance.Visible = false
    set.HealthBarOutline.Visible = false
    set.HealthBar.Visible = false
    set.Tracer.Visible = false
    for _, bone in ipairs(set.SkeletonLines) do
        bone.Visible = false
    end
end

-- Skeleton Joint Graph
local R15Joints = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local R6Joints = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function RenderSkeleton(character, visualSet)
    if not character or not visualSet then return end
    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local joints = isR15 and R15Joints or R6Joints

    local lineIndex = 1
    for _, pair in ipairs(joints) do
        local p1 = character:FindFirstChild(pair[1])
        local p2 = character:FindFirstChild(pair[2])
        if p1 and p2 and lineIndex <= #visualSet.SkeletonLines then
            local s1, onScreen1 = WorldToScreen(p1.Position)
            local s2, onScreen2 = WorldToScreen(p2.Position)
            local bone = visualSet.SkeletonLines[lineIndex]
            if onScreen1 and onScreen2 then
                bone.From = s1
                bone.To = s2
                bone.Color = Config.Visuals.SkeletonColor
                bone.Visible = true
            else
                bone.Visible = false
            end
            lineIndex = lineIndex + 1
        end
    end

    for i = lineIndex, #visualSet.SkeletonLines do
        visualSet.SkeletonLines[i].Visible = false
    end
end

-- [USER INTERFACE CREATION (PREMIUM CRIMSON THEME)]
local function BuildInterface()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Mimi_Forge_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Executor-safe parent injection
    local parentTarget = Services.CoreGui
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = Services.CoreGui
        elseif gethui then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = Services.CoreGui
        end
    end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    table.insert(Registry.GuiInstances, ScreenGui)

    -- Main Container Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 780, 0, 480)
    MainFrame.Position = UDim2.new(0.5, -390, 0.5, -240)
    MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 34, 76)
    MainStroke.Thickness = 1.6
    MainStroke.Transparency = 0.2
    MainStroke.Parent = MainFrame

    -- Dragging Handler
    local isDragging = false
    local dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and isDragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Top Navigation Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 46)
    TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 10)
    TopCorner.Parent = TopBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 260, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "MIMI.FORGE // INSTRUMENTATION"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 42, 77)
    TitleLabel.TextSize = 15
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar

    local StatusBadge = Instance.new("Frame")
    StatusBadge.Size = UDim2.new(0, 95, 0, 24)
    StatusBadge.Position = UDim2.new(0, 280, 0.5, -12)
    StatusBadge.BackgroundColor3 = Color3.fromRGB(24, 20, 25)
    StatusBadge.BorderSizePixel = 0
    StatusBadge.Parent = TopBar

    local BadgeCorner = Instance.new("UICorner")
    BadgeCorner.CornerRadius = UDim.new(0, 6)
    BadgeCorner.Parent = StatusBadge

    local BadgeDot = Instance.new("Frame")
    BadgeDot.Size = UDim2.new(0, 8, 0, 8)
    BadgeDot.Position = UDim2.new(0, 8, 0.5, -4)
    BadgeDot.BackgroundColor3 = Color3.fromRGB(0, 255, 140)
    BadgeDot.BorderSizePixel = 0
    BadgeDot.Parent = StatusBadge
    Instance.new("UICorner", BadgeDot).CornerRadius = UDim.new(1, 0)

    local BadgeText = Instance.new("TextLabel")
    BadgeText.Size = UDim2.new(1, -22, 1, 0)
    BadgeText.Position = UDim2.new(0, 20, 0, 0)
    BadgeText.BackgroundTransparency = 1
    BadgeText.Font = Enum.Font.GothamMedium
    BadgeText.Text = "ONLINE"
    BadgeText.TextColor3 = Color3.fromRGB(220, 220, 230)
    BadgeText.TextSize = 11
    BadgeText.TextXAlignment = Enum.TextXAlignment.Left
    BadgeText.Parent = StatusBadge

    -- Top Bar Action Buttons (Minimize, Close)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(28, 20, 24)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 60, 80)
    CloseBtn.TextSize = 20
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Parent = TopBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 32, 0, 32)
    MinBtn.Position = UDim2.new(1, -78, 0.5, -16)
    MinBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Text = "−"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    MinBtn.TextSize = 18
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TopBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    -- Left Navigation Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 140, 1, -86)
    Sidebar.Position = UDim2.new(0, 10, 0, 52)
    Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

    local TabContainer = Instance.new("UIListLayout")
    TabContainer.Padding = UDim.new(0, 6)
    TabContainer.FillDirection = Enum.FillDirection.Vertical
    TabContainer.SortOrder = Enum.SortOrder.LayoutOrder
    TabContainer.Parent = Sidebar

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.PaddingTop = UDim.new(0, 8)
    SidebarPadding.PaddingLeft = UDim.new(0, 8)
    SidebarPadding.PaddingRight = UDim.new(0, 8)
    SidebarPadding.Parent = Sidebar

    -- Central Configuration Panel
    local CenterPanel = Instance.new("Frame")
    CenterPanel.Name = "CenterPanel"
    CenterPanel.Size = UDim2.new(1, -380, 1, -86)
    CenterPanel.Position = UDim2.new(0, 158, 0, 52)
    CenterPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    CenterPanel.BorderSizePixel = 0
    CenterPanel.Parent = MainFrame
    Instance.new("UICorner", CenterPanel).CornerRadius = UDim.new(0, 8)

    -- Right-Side Live Statistics Panel
    local StatsPanel = Instance.new("Frame")
    StatsPanel.Name = "StatsPanel"
    StatsPanel.Size = UDim2.new(0, 204, 1, -86)
    StatsPanel.Position = UDim2.new(1, -214, 0, 52)
    StatsPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    StatsPanel.BorderSizePixel = 0
    StatsPanel.Parent = MainFrame
    Instance.new("UICorner", StatsPanel).CornerRadius = UDim.new(0, 8)

    local StatsLayout = Instance.new("UIListLayout")
    StatsLayout.Padding = UDim.new(0, 10)
    StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    StatsLayout.Parent = StatsPanel

    local StatsPadding = Instance.new("UIPadding")
    StatsPadding.PaddingTop = UDim.new(0, 10)
    StatsPadding.PaddingLeft = UDim.new(0, 10)
    StatsPadding.PaddingRight = UDim.new(0, 10)
    StatsPadding.Parent = StatsPanel

    -- Bottom Status Bar
    local BottomBar = Instance.new("Frame")
    BottomBar.Name = "BottomBar"
    BottomBar.Size = UDim2.new(1, -20, 0, 26)
    BottomBar.Position = UDim2.new(0, 10, 1, -30)
    BottomBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    BottomBar.BorderSizePixel = 0
    BottomBar.Parent = MainFrame
    Instance.new("UICorner", BottomBar).CornerRadius = UDim.new(0, 6)

    local StatusPulse = Instance.new("Frame")
    StatusPulse.Size = UDim2.new(0, 8, 0, 8)
    StatusPulse.Position = UDim2.new(0, 10, 0.5, -4)
    StatusPulse.BackgroundColor3 = Color3.fromRGB(255, 42, 77)
    StatusPulse.BorderSizePixel = 0
    StatusPulse.Parent = BottomBar
    Instance.new("UICorner", StatusPulse).CornerRadius = UDim.new(1, 0)

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(0.6, 0, 1, 0)
    StatusLabel.Position = UDim2.new(0, 26, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "CORE: ACTIVE // MONITORING PROCESS"
    StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
    StatusLabel.TextSize = 10
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = BottomBar

    local SignatureLabel = Instance.new("TextLabel")
    SignatureLabel.Size = UDim2.new(0.35, 0, 1, 0)
    SignatureLabel.Position = UDim2.new(0.65, 0, 0, 0)
    SignatureLabel.BackgroundTransparency = 1
    SignatureLabel.Font = Enum.Font.Code
    SignatureLabel.Text = "MIMI.V2 // LOADSTRING"
    SignatureLabel.TextColor3 = Color3.fromRGB(255, 42, 77)
    SignatureLabel.TextSize = 10
    SignatureLabel.TextXAlignment = Enum.TextXAlignment.Right
    SignatureLabel.Parent = BottomBar

    -- [MINIMIZE BADGE / RESTORE DOCK]
    local RestoreDock = Instance.new("Frame")
    RestoreDock.Name = "RestoreDock"
    RestoreDock.Size = UDim2.new(0, 130, 0, 36)
    RestoreDock.Position = UDim2.new(0, 20, 0, 20)
    RestoreDock.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    RestoreDock.BorderSizePixel = 0
    RestoreDock.Visible = false
    RestoreDock.Parent = ScreenGui
    Instance.new("UICorner", RestoreDock).CornerRadius = UDim.new(0, 8)

    local RestoreStroke = Instance.new("UIStroke", RestoreDock)
    RestoreStroke.Color = Color3.fromRGB(255, 42, 77)
    RestoreStroke.Thickness = 1.2

    local RestoreBtn = Instance.new("TextButton")
    RestoreBtn.Size = UDim2.new(1, 0, 1, 0)
    RestoreBtn.BackgroundTransparency = 1
    RestoreBtn.Font = Enum.Font.GothamBold
    RestoreBtn.Text = "RESTORE [MIMI]"
    RestoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    RestoreBtn.TextSize = 12
    RestoreBtn.Parent = RestoreDock

    RestoreBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        RestoreDock.Visible = false
    end)

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        RestoreDock.Visible = true
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        if getgenv and getgenv()._MIMI_UNLOAD then
            getgenv()._MIMI_UNLOAD()
        else
            ScreenGui:Destroy()
        end
    end)

    -- [TAB MANAGEMENT & CONTROL BUILDERS]
    local TabPages = {}
    local TabButtons = {}

    local function CreateTab(name, layoutOrder)
        local btn = Instance.new("TextButton")
        btn.Name = name .. "_TabBtn"
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = (layoutOrder == 1) and Color3.fromRGB(255, 34, 76) or Color3.fromRGB(24, 24, 30)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Text = name:upper()
        btn.TextColor3 = (layoutOrder == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 195)
        btn.TextSize = 11
        btn.LayoutOrder = layoutOrder
        btn.Parent = Sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "_Page"
        page.Size = UDim2.new(1, -16, 1, -16)
        page.Position = UDim2.new(0, 8, 0, 8)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(255, 42, 77)
        page.Visible = (layoutOrder == 1)
        page.Parent = CenterPanel

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 16)
        end)

        TabPages[name] = page
        TabButtons[name] = btn

        btn.MouseButton1Click:Connect(function()
            for tName, tPage in pairs(TabPages) do
                local isCurrent = (tName == name)
                tPage.Visible = isCurrent
                local b = TabButtons[tName]
                Services.TweenService:Create(b, TweenInfo.new(0.2), {
                    BackgroundColor3 = isCurrent and Color3.fromRGB(255, 34, 76) or Color3.fromRGB(24, 24, 30),
                    TextColor3 = isCurrent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 195)
                }):Play()
            end
        end)

        return page
    end

    -- UI Control Component Helpers
    local function AddToggle(parent, labelText, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(230, 230, 240)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local switch = Instance.new("TextButton")
        switch.Size = UDim2.new(0, 42, 0, 22)
        switch.Position = UDim2.new(1, -52, 0.5, -11)
        switch.BackgroundColor3 = defaultVal and Color3.fromRGB(255, 34, 76) or Color3.fromRGB(40, 40, 50)
        switch.BorderSizePixel = 0
        switch.Text = ""
        switch.Parent = frame
        Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = defaultVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = switch
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local state = defaultVal
        switch.MouseButton1Click:Connect(function()
            state = not state
            Services.TweenService:Create(switch, TweenInfo.new(0.2), {
                BackgroundColor3 = state and Color3.fromRGB(255, 34, 76) or Color3.fromRGB(40, 40, 50)
            }):Play()
            Services.TweenService:Create(knob, TweenInfo.new(0.2), {
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            }):Play()
            callback(state)
        end)
    end

    local function AddSlider(parent, labelText, minVal, maxVal, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 48)
        frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.65, 0, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 4)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(230, 230, 240)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local valueDisplay = Instance.new("TextLabel")
        valueDisplay.Size = UDim2.new(0.3, -12, 0, 20)
        valueDisplay.Position = UDim2.new(0.7, 0, 0, 4)
        valueDisplay.BackgroundTransparency = 1
        valueDisplay.Font = Enum.Font.Code
        valueDisplay.Text = tostring(defaultVal)
        valueDisplay.TextColor3 = Color3.fromRGB(255, 42, 77)
        valueDisplay.TextSize = 12
        valueDisplay.TextXAlignment = Enum.TextXAlignment.Right
        valueDisplay.Parent = frame

        local barBg = Instance.new("TextButton")
        barBg.Size = UDim2.new(1, -24, 0, 8)
        barBg.Position = UDim2.new(0, 12, 0, 28)
        barBg.BackgroundColor3 = Color3.fromRGB(42, 42, 54)
        barBg.BorderSizePixel = 0
        barBg.Text = ""
        barBg.AutoButtonColor = false
        barBg.Parent = frame
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

        local progress = Instance.new("Frame")
        local initialPercent = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        progress.Size = UDim2.new(initialPercent, 0, 1, 0)
        progress.BackgroundColor3 = Color3.fromRGB(255, 34, 76)
        progress.BorderSizePixel = 0
        progress.Parent = barBg
        Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function update(input)
            local posX = input.Position.X - barBg.AbsolutePosition.X
            local pct = math.clamp(posX / barBg.AbsoluteSize.X, 0, 1)
            progress.Size = UDim2.new(pct, 0, 1, 0)
            local val = math.floor(minVal + ((maxVal - minVal) * pct) + 0.5)
            valueDisplay.Text = tostring(val)
            callback(val)
        end

        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input)
            end
        end)

        Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        Services.UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
    end

    local function AddDropdown(parent, labelText, options, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 52)
        frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, 0, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(230, 230, 240)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, -24, 0, 22)
        optionBtn.Position = UDim2.new(0, 12, 0, 26)
        optionBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 44)
        optionBtn.BorderSizePixel = 0
        optionBtn.Font = Enum.Font.GothamBold
        optionBtn.Text = "  " .. tostring(defaultVal)
        optionBtn.TextColor3 = Color3.fromRGB(255, 42, 77)
        optionBtn.TextSize = 11
        optionBtn.TextXAlignment = Enum.TextXAlignment.Left
        optionBtn.Parent = frame
        Instance.new("UICorner", optionBtn).CornerRadius = UDim.new(0, 4)

        local currentIndex = 1
        for idx, val in ipairs(options) do
            if val == defaultVal then currentIndex = idx break end
        end

        optionBtn.MouseButton1Click:Connect(function()
            currentIndex = currentIndex + 1
            if currentIndex > #options then currentIndex = 1 end
            local selected = options[currentIndex]
            optionBtn.Text = "  " .. tostring(selected)
            callback(selected)
        end)
    end

    local function AddActionButton(parent, text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(32, 28, 36)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 42, 77)
        btn.TextSize = 12
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(255, 34, 76)
        stroke.Thickness = 1
        stroke.Transparency = 0.5

        btn.MouseButton1Click:Connect(function()
            Services.TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 34, 76) }):Play()
            task.wait(0.15)
            Services.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(32, 28, 36) }):Play()
            callback()
        end)
    end

    -- [BUILD MODULE TABS]
    local AimPage = CreateTab("Aim", 1)
    AddToggle(AimPage, "Master Aim Assist", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    AddSlider(AimPage, "Field Of View (FOV)", 30, 450, Config.Aim.FOV, function(v)
        Config.Aim.FOV = v
        if DrawingObjects.FOVCircle then DrawingObjects.FOVCircle.Radius = v end
    end)
    AddSlider(AimPage, "Smoothness Factor", 1, 20, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)
    AddDropdown(AimPage, "Target Priority", {"Crosshair", "Distance", "Health"}, Config.Aim.Priority, function(v) Config.Aim.Priority = v end)
    AddToggle(AimPage, "Line-of-Sight Check", Config.Aim.LineOfSightCheck, function(v) Config.Aim.LineOfSightCheck = v end)
    AddToggle(AimPage, "Target Switching On Death", Config.Aim.TargetSwitching, function(v) Config.Aim.TargetSwitching = v end)
    AddToggle(AimPage, "Aim Direction Visualizer", Config.Aim.AimDirectionVis, function(v) Config.Aim.AimDirectionVis = v end)
    AddToggle(AimPage, "Lock Indicator", Config.Aim.LockIndicator, function(v) Config.Aim.LockIndicator = v end)

    local TargetPage = CreateTab("Target", 2)
    AddDropdown(TargetPage, "Hitbox Selection", {"Head", "Torso", "Limbs", "Closest"}, Config.Target.SelectedHitbox, function(v) Config.Target.SelectedHitbox = v end)
    AddToggle(TargetPage, "Hitbox Visualization", Config.Target.HitboxVis, function(v) Config.Target.HitboxVis = v end)
    AddSlider(TargetPage, "Hitbox Transparency %", 10, 95, math.floor(Config.Target.HitboxTransparency * 100), function(v) Config.Target.HitboxTransparency = v / 100 end)
    AddToggle(TargetPage, "Raycast Trajectory Line", Config.Target.RaycastVis, function(v) Config.Target.RaycastVis = v end)
    AddToggle(TargetPage, "Show Target Distance Tag", Config.Target.ShowDistance, function(v) Config.Target.ShowDistance = v end)

    local VisualsPage = CreateTab("Visuals", 3)
    AddToggle(VisualsPage, "Master Visual Overlay", Config.Visuals.Enabled, function(v) Config.Visuals.Enabled = v end)
    AddToggle(VisualsPage, "Bounding Boxes", Config.Visuals.Boxes, function(v) Config.Visuals.Boxes = v end)
    AddToggle(VisualsPage, "Skeletal Framework", Config.Visuals.Skeleton, function(v) Config.Visuals.Skeleton = v end)
    AddToggle(VisualsPage, "Player Names", Config.Visuals.Names, function(v) Config.Visuals.Names = v end)
    AddToggle(VisualsPage, "Distance Readout", Config.Visuals.Distance, function(v) Config.Visuals.Distance = v end)
    AddToggle(VisualsPage, "Dynamic Health Bars", Config.Visuals.HealthBars, function(v) Config.Visuals.HealthBars = v end)
    AddToggle(VisualsPage, "Screen Tracers", Config.Visuals.Tracers, function(v) Config.Visuals.Tracers = v end)
    AddDropdown(VisualsPage, "Tracer Origin", {"Bottom", "Center", "Mouse"}, Config.Visuals.TracerOrigin, function(v) Config.Visuals.TracerOrigin = v end)
    AddToggle(VisualsPage, "Team Member Filter", Config.Visuals.TeamCheck, function(v) Config.Visuals.TeamCheck = v end)
    AddToggle(VisualsPage, "Occlusion Visibility Check", Config.Visuals.VisibilityCheck, function(v) Config.Visuals.VisibilityCheck = v end)
    AddSlider(VisualsPage, "Max Render Distance", 200, 3000, Config.Visuals.MaxDistance, function(v) Config.Visuals.MaxDistance = v end)

    local CrosshairPage = CreateTab("Crosshair", 4)
    AddToggle(CrosshairPage, "Custom Dynamic Reticle", Config.Crosshair.Enabled, function(v) Config.Crosshair.Enabled = v end)
    AddSlider(CrosshairPage, "Reticle Size", 4, 30, Config.Crosshair.Size, function(v) Config.Crosshair.Size = v end)
    AddSlider(CrosshairPage, "Reticle Thickness", 1, 6, Config.Crosshair.Thickness, function(v) Config.Crosshair.Thickness = v end)
    AddSlider(CrosshairPage, "Center Gap", 1, 20, Config.Crosshair.Gap, function(v) Config.Crosshair.Gap = v end)
    AddSlider(CrosshairPage, "Opacity %", 10, 100, math.floor(Config.Crosshair.Opacity * 100), function(v) Config.Crosshair.Opacity = v / 100 end)
    AddToggle(CrosshairPage, "Dynamic Movement Expansion", Config.Crosshair.DynamicMovement, function(v) Config.Crosshair.DynamicMovement = v end)
    AddToggle(CrosshairPage, "Shooting Flash Indicator", Config.Crosshair.DynamicShooting, function(v) Config.Crosshair.DynamicShooting = v end)
    AddToggle(CrosshairPage, "Transient Hit-Marker (X)", Config.Crosshair.Hitmarker, function(v) Config.Crosshair.Hitmarker = v end)

    local CombatPage = CreateTab("Combat", 5)
    AddToggle(CombatPage, "Moving Target Compensation", Config.Combat.MovingTargets, function(v) Config.Combat.MovingTargets = v end)
    AddToggle(CombatPage, "Strafing Trajectory Tracking", Config.Combat.StrafingTargets, function(v) Config.Combat.StrafingTargets = v end)
    AddSlider(CombatPage, "Lead Velocity Factor", 1, 5, math.floor(Config.Combat.TargetSpeedFactor), function(v) Config.Combat.TargetSpeedFactor = v end)
    AddToggle(CombatPage, "Reaction-Time Benchmark", Config.Combat.ReactionTracker, function(v) Config.Combat.ReactionTracker = v end)
    AddActionButton(CombatPage, "RESET COMBAT STATISTICS", function()
        Telemetry.Shots = 0
        Telemetry.Hits = 0
        Telemetry.Misses = 0
        Telemetry.Headshots = 0
        Telemetry.TotalDamage = 0
        Telemetry.Accuracy = 0
        Telemetry.ReactionTime = 0
    end)

    local SettingsPage = CreateTab("Settings", 6)
    AddToggle(SettingsPage, "Global Master Enable", Config.MasterEnabled, function(v) Config.MasterEnabled = v end)
    AddSlider(SettingsPage, "UI Background Opacity %", 40, 100, math.floor(Config.Settings.UIOpacity * 100), function(v)
        Config.Settings.UIOpacity = v / 100
        MainFrame.BackgroundTransparency = 1 - (v / 100)
    end)
    AddSlider(SettingsPage, "Crimson Glow Intensity", 1, 10, math.floor(Config.Settings.RedGlowIntensity * 5), function(v)
        Config.Settings.RedGlowIntensity = v / 5
        MainStroke.Thickness = 1 + (v / 5)
    end)
    AddActionButton(SettingsPage, "SAVE CONFIGURATION FILE", function()
        pcall(function()
            if writefile then
                local data = Services.HttpService:JSONEncode(Config)
                writefile(Config.Settings.ConfigFile, data)
            end
        end)
    end)
    AddActionButton(SettingsPage, "LOAD CONFIGURATION FILE", function()
        pcall(function()
            if readfile and isfile and isfile(Config.Settings.ConfigFile) then
                local raw = readfile(Config.Settings.ConfigFile)
                local decoded = Services.HttpService:JSONDecode(raw)
                for k, v in pairs(decoded) do Config[k] = v end
            end
        end)
    end)
    AddActionButton(SettingsPage, "RESET TO FACTORY DEFAULTS", function()
        Config.Aim.FOV = 130
        Config.Aim.Smoothness = 5
        Config.Visuals.MaxDistance = 1200
        Config.Crosshair.Size = 12
    end)

    -- [RIGHT STATS PANEL WIDGETS]
    local function CreateStatCard(title)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 78)
        card.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        card.BorderSizePixel = 0
        card.Parent = StatsPanel
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local cTitle = Instance.new("TextLabel")
        cTitle.Size = UDim2.new(1, -16, 0, 18)
        cTitle.Position = UDim2.new(0, 8, 0, 6)
        cTitle.BackgroundTransparency = 1
        cTitle.Font = Enum.Font.GothamBold
        cTitle.Text = title
        cTitle.TextColor3 = Color3.fromRGB(255, 42, 77)
        cTitle.TextSize = 10
        cTitle.TextXAlignment = Enum.TextXAlignment.Left
        cTitle.Parent = card

        local cVal1 = Instance.new("TextLabel")
        cVal1.Name = "Value1"
        cVal1.Size = UDim2.new(1, -16, 0, 22)
        cVal1.Position = UDim2.new(0, 8, 0, 26)
        cVal1.BackgroundTransparency = 1
        cVal1.Font = Enum.Font.Code
        cVal1.Text = "--"
        cVal1.TextColor3 = Color3.fromRGB(240, 240, 250)
        cVal1.TextSize = 13
        cVal1.TextXAlignment = Enum.TextXAlignment.Left
        cVal1.Parent = card

        local cVal2 = Instance.new("TextLabel")
        cVal2.Name = "Value2"
        cVal2.Size = UDim2.new(1, -16, 0, 18)
        cVal2.Position = UDim2.new(0, 8, 0, 50)
        cVal2.BackgroundTransparency = 1
        cVal2.Font = Enum.Font.GothamMedium
        cVal2.Text = "--"
        cVal2.TextColor3 = Color3.fromRGB(160, 160, 175)
        cVal2.TextSize = 11
        cVal2.TextXAlignment = Enum.TextXAlignment.Left
        cVal2.Parent = card

        return card
    end

    local TargetCard = CreateStatCard("ACTIVE TARGET TELEMETRY")
    local SystemCard = CreateStatCard("ENGINE PERFORMANCE")
    local CombatCard = CreateStatCard("COMBAT ACCURACY METRICS")

    -- [DETACHED HUD WIDGET]
    local HUDFrame = Instance.new("Frame")
    HUDFrame.Name = "Mimi_HUD"
    HUDFrame.Size = UDim2.new(0, 230, 0, 110)
    HUDFrame.Position = UDim2.new(0, 25, 0.75, 0)
    HUDFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    HUDFrame.BorderSizePixel = 0
    HUDFrame.Parent = ScreenGui
    Instance.new("UICorner", HUDFrame).CornerRadius = UDim.new(0, 8)

    local HUDStroke = Instance.new("UIStroke", HUDFrame)
    HUDStroke.Color = Color3.fromRGB(255, 34, 76)
    HUDStroke.Thickness = 1.2
    HUDStroke.Transparency = 0.3

    local HUDTitle = Instance.new("TextLabel")
    HUDTitle.Size = UDim2.new(1, -16, 0, 20)
    HUDTitle.Position = UDim2.new(0, 8, 0, 4)
    HUDTitle.BackgroundTransparency = 1
    HUDTitle.Font = Enum.Font.GothamBold
    HUDTitle.Text = "TELEMETRY HUD"
    HUDTitle.TextColor3 = Color3.fromRGB(255, 42, 77)
    HUDTitle.TextSize = 10
    HUDTitle.TextXAlignment = Enum.TextXAlignment.Left
    HUDTitle.Parent = HUDFrame

    local HUDTargetLabel = Instance.new("TextLabel")
    HUDTargetLabel.Size = UDim2.new(1, -16, 0, 18)
    HUDTargetLabel.Position = UDim2.new(0, 8, 0, 24)
    HUDTargetLabel.BackgroundTransparency = 1
    HUDTargetLabel.Font = Enum.Font.Code
    HUDTargetLabel.Text = "TARGET: NONE"
    HUDTargetLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    HUDTargetLabel.TextSize = 11
    HUDTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    HUDTargetLabel.Parent = HUDFrame

    local HUDMetricsLabel = Instance.new("TextLabel")
    HUDMetricsLabel.Size = UDim2.new(1, -16, 0, 18)
    HUDMetricsLabel.Position = UDim2.new(0, 8, 0, 44)
    HUDMetricsLabel.BackgroundTransparency = 1
    HUDMetricsLabel.Font = Enum.Font.Gotham
    HUDMetricsLabel.Text = "FPS: 60  |  PING: 0ms  |  FOV: 130"
    HUDMetricsLabel.TextColor3 = Color3.fromRGB(170, 170, 185)
    HUDMetricsLabel.TextSize = 10
    HUDMetricsLabel.TextXAlignment = Enum.TextXAlignment.Left
    HUDMetricsLabel.Parent = HUDFrame

    local HUDCombatLabel = Instance.new("TextLabel")
    HUDCombatLabel.Size = UDim2.new(1, -16, 0, 18)
    HUDCombatLabel.Position = UDim2.new(0, 8, 0, 64)
    HUDCombatLabel.BackgroundTransparency = 1
    HUDCombatLabel.Font = Enum.Font.GothamMedium
    HUDCombatLabel.Text = "ACC: 100%  |  HITS: 0  |  MISS: 0"
    HUDCombatLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
    HUDCombatLabel.TextSize = 10
    HUDCombatLabel.TextXAlignment = Enum.TextXAlignment.Left
    HUDCombatLabel.Parent = HUDFrame

    local HUDReactionLabel = Instance.new("TextLabel")
    HUDReactionLabel.Size = UDim2.new(1, -16, 0, 18)
    HUDReactionLabel.Position = UDim2.new(0, 8, 0, 84)
    HUDReactionLabel.BackgroundTransparency = 1
    HUDReactionLabel.Font = Enum.Font.Code
    HUDReactionLabel.Text = "REACTION: 0 ms"
    HUDReactionLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
    HUDReactionLabel.TextSize = 10
    HUDReactionLabel.TextXAlignment = Enum.TextXAlignment.Left
    HUDReactionLabel.Parent = HUDFrame

    -- Dragging Handler for HUD
    local isDraggingHUD = false
    local hudDragStart, hudStartPos
    HUDFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingHUD = true
            hudDragStart = input.Position
            hudStartPos = HUDFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingHUD = false
                end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if isDraggingHUD and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - hudDragStart
            HUDFrame.Position = UDim2.new(hudStartPos.X.Scale, hudStartPos.X.Offset + delta.X, hudStartPos.Y.Scale, hudStartPos.Y.Offset + delta.Y)
        end
    end)

    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        HUDFrame = HUDFrame,
        TargetCard = TargetCard,
        SystemCard = SystemCard,
        CombatCard = CombatCard,
        HUDTargetLabel = HUDTargetLabel,
        HUDMetricsLabel = HUDMetricsLabel,
        HUDCombatLabel = HUDCombatLabel,
        HUDReactionLabel = HUDReactionLabel
    }
end

local UI = BuildInterface()

-- [INPUT HANDLING (AIM KEY & UI TOGGLE)]
RegisterEvent(Services.UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Config.Settings.UIKeybind then
        UI.MainFrame.Visible = not UI.MainFrame.Visible
        return
    end

    if not processed then
        if input.UserInputType == Config.Aim.AimKey or (Config.Aim.UseKeyCode and input.KeyCode == Config.Aim.AimKeyCode) then
            Telemetry.IsAiming = true
            if Telemetry.CurrentTarget then
                Telemetry.TargetAcquisitionTimestamp = os.clock()
            end
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Telemetry.IsFiring = true
            Telemetry.Shots = Telemetry.Shots + 1
            if Telemetry.TargetAcquisitionTimestamp > 0 then
                Telemetry.ReactionTime = math.floor((os.clock() - Telemetry.TargetAcquisitionTimestamp) * 1000)
            end
        end
    end
end))

RegisterEvent(Services.UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.Aim.AimKey or (Config.Aim.UseKeyCode and input.KeyCode == Config.Aim.AimKeyCode) then
        Telemetry.IsAiming = false
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Telemetry.IsFiring = false
    end
end))

-- [PERFORMANCE METRICS TRACKER]
local frameCount = 0
local lastFpsTimestamp = os.clock()

RegisterEvent(Services.RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = os.clock()
    if now - lastFpsTimestamp >= 0.5 then
        Telemetry.FPS = math.floor(frameCount / (now - lastFpsTimestamp))
        frameCount = 0
        lastFpsTimestamp = now

        pcall(function()
            local netStats = Services.Stats.Network.ServerStatsItem["Data Ping"]
            if netStats then
                Telemetry.Ping = math.floor(netStats:GetValue())
            end
        end)
    end
end))

-- [DYNAMIC CROSSHAIR RENDERING]
local function UpdateCustomCrosshair()
    if not HasDrawing then return end
    local enabled = Config.MasterEnabled and Config.Crosshair.Enabled

    local center = GetScreenCenter()
    local gap = Config.Crosshair.Gap
    local size = Config.Crosshair.Size

    -- Dynamic Movement Expansion
    if Config.Crosshair.DynamicMovement and LocalPlayer.Character then
        local hum = GetHumanoid(LocalPlayer.Character)
        if hum and hum.MoveDirection.Magnitude > 0 then
            gap = gap + 4
        end
    end

    -- Dynamic Shooting Expansion
    if Config.Crosshair.DynamicShooting and Telemetry.IsFiring then
        gap = gap + 6
    end

    local lines = DrawingObjects.CrosshairLines
    if #lines == 4 then
        lines[1].Visible = enabled -- Top
        lines[2].Visible = enabled -- Bottom
        lines[3].Visible = enabled -- Left
        lines[4].Visible = enabled -- Right

        if enabled then
            local color = Config.Crosshair.Color
            local opacity = Config.Crosshair.Opacity
            local th = Config.Crosshair.Thickness

            -- Top
            lines[1].From = Vector2.new(center.X, center.Y - gap)
            lines[1].To = Vector2.new(center.X, center.Y - gap - size)
            lines[1].Thickness = th
            lines[1].Color = color
            lines[1].Transparency = opacity

            -- Bottom
            lines[2].From = Vector2.new(center.X, center.Y + gap)
            lines[2].To = Vector2.new(center.X, center.Y + gap + size)
            lines[2].Thickness = th
            lines[2].Color = color
            lines[2].Transparency = opacity

            -- Left
            lines[3].From = Vector2.new(center.X - gap, center.Y)
            lines[3].To = Vector2.new(center.X - gap - size, center.Y)
            lines[3].Thickness = th
            lines[3].Color = color
            lines[3].Transparency = opacity

            -- Right
            lines[4].From = Vector2.new(center.X + gap, center.Y)
            lines[4].To = Vector2.new(center.X + gap + size, center.Y)
            lines[4].Thickness = th
            lines[4].Color = color
            lines[4].Transparency = opacity
        end
    end

    -- Transient Hitmarker (X)
    local hm = DrawingObjects.HitmarkerLines
    if #hm == 4 then
        local visible = (Telemetry.HitmarkerAlpha > 0)
        for _, line in ipairs(hm) do
            line.Visible = visible
            if visible then
                line.Color = Config.Crosshair.HitmarkerColor
                line.Transparency = Telemetry.HitmarkerAlpha
            end
        end

        if visible then
            local hs = Config.Crosshair.HitmarkerSize
            hm[1].From = Vector2.new(center.X - hs, center.Y - hs)
            hm[1].To = Vector2.new(center.X - 3, center.Y - 3)

            hm[2].From = Vector2.new(center.X + hs, center.Y - hs)
            hm[2].To = Vector2.new(center.X + 3, center.Y - 3)

            hm[3].From = Vector2.new(center.X - hs, center.Y + hs)
            hm[3].To = Vector2.new(center.X - 3, center.Y + 3)

            hm[4].From = Vector2.new(center.X + hs, center.Y + hs)
            hm[4].To = Vector2.new(center.X + 3, center.Y + 3)

            Telemetry.HitmarkerAlpha = math.clamp(Telemetry.HitmarkerAlpha - 0.05, 0, 1)
        end
    end
end

-- [MAIN RUNTIME RENDER LOOP]
RegisterEvent(Services.RunService.RenderStepped:Connect(function()
    -- 1. Resolve Target
    local targetPlayer, targetPart = GetBestCandidate()
    Telemetry.CurrentTarget = targetPlayer

    -- Target health delta monitoring for combat telemetry
    if targetPlayer and targetPlayer.Character then
        local hum = GetHumanoid(targetPlayer.Character)
        if hum then
            if Telemetry.LastTargetHealth > 0 and hum.Health < Telemetry.LastTargetHealth then
                local delta = Telemetry.LastTargetHealth - hum.Health
                Telemetry.Hits = Telemetry.Hits + 1
                Telemetry.TotalDamage = Telemetry.TotalDamage + delta
                Telemetry.HitmarkerAlpha = 1.0

                if targetPart and targetPart.Name == "Head" then
                    Telemetry.Headshots = Telemetry.Headshots + 1
                end
            end
            Telemetry.LastTargetHealth = hum.Health
        end
    else
        Telemetry.LastTargetHealth = 0
    end

    -- Recalculate Accuracy
    if Telemetry.Shots > 0 then
        Telemetry.Accuracy = math.clamp(math.floor((Telemetry.Hits / Telemetry.Shots) * 100), 0, 100)
    else
        Telemetry.Accuracy = 100
    end

    -- 2. Aim Interpolation
    if Telemetry.IsAiming and targetPart and Config.MasterEnabled and Config.Aim.Enabled then
        ApplySmoothAim(targetPart)
    end

    -- 3. FOV & Target Visual Indicators
    if HasDrawing then
        local mousePos = GetMouseLocation()
        if DrawingObjects.FOVCircle then
            local showFOV = Config.MasterEnabled and Config.Aim.Enabled and Config.Aim.AdjustableFOV
            DrawingObjects.FOVCircle.Visible = showFOV
            if showFOV then
                DrawingObjects.FOVCircle.Position = mousePos
                DrawingObjects.FOVCircle.Radius = Config.Aim.FOV
                DrawingObjects.FOVCircle.Color = Config.Visuals.BoxColor
            end
        end

        -- Aim Direction & Lock Indicators
        if targetPart and Config.MasterEnabled and Config.Aim.Enabled then
            local screenPos, onScreen = WorldToScreen(targetPart.Position)
            if onScreen then
                if Config.Aim.AimDirectionVis and DrawingObjects.AimLine then
                    DrawingObjects.AimLine.From = mousePos
                    DrawingObjects.AimLine.To = screenPos
                    DrawingObjects.AimLine.Visible = true
                elseif DrawingObjects.AimLine then
                    DrawingObjects.AimLine.Visible = false
                end

                if Config.Aim.LockIndicator and DrawingObjects.LockIndicatorText then
                    DrawingObjects.LockIndicatorText.Position = Vector2.new(screenPos.X, screenPos.Y - 24)
                    DrawingObjects.LockIndicatorText.Text = string.format("[LOCK: %s]", targetPlayer.Name:upper())
                    DrawingObjects.LockIndicatorText.Visible = true
                elseif DrawingObjects.LockIndicatorText then
                    DrawingObjects.LockIndicatorText.Visible = false
                end

                if Config.Target.RaycastVis and DrawingObjects.RaycastPath and LocalPlayer.Character then
                    local localRoot = GetRootPart(LocalPlayer.Character)
                    if localRoot then
                        local startScreen = WorldToScreen(localRoot.Position)
                        DrawingObjects.RaycastPath.From = startScreen
                        DrawingObjects.RaycastPath.To = screenPos
                        DrawingObjects.RaycastPath.Visible = true
                    end
                elseif DrawingObjects.RaycastPath then
                    DrawingObjects.RaycastPath.Visible = false
                end
            else
                if DrawingObjects.AimLine then DrawingObjects.AimLine.Visible = false end
                if DrawingObjects.LockIndicatorText then DrawingObjects.LockIndicatorText.Visible = false end
                if DrawingObjects.RaycastPath then DrawingObjects.RaycastPath.Visible = false end
            end
        else
            if DrawingObjects.AimLine then DrawingObjects.AimLine.Visible = false end
            if DrawingObjects.LockIndicatorText then DrawingObjects.LockIndicatorText.Visible = false end
            if DrawingObjects.RaycastPath then DrawingObjects.RaycastPath.Visible = false end
        end
    end

    -- 4. Custom Crosshair Update
    UpdateCustomCrosshair()

    -- 5. Visual Projection (ESP) Loop
    if HasDrawing then
        for _, player in ipairs(Services.Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not Registry.VisualPool[player] then
                    Registry.VisualPool[player] = CreateVisualSet()
                end
                local set = Registry.VisualPool[player]
                local char = GetCharacter(player)
                local shouldRender = Config.MasterEnabled and Config.Visuals.Enabled and char and IsAlive(char) and not IsTeammate(player)

                if shouldRender then
                    local root = GetRootPart(char)
                    local hum = GetHumanoid(char)
                    if root and hum then
                        local dist = (Camera.CFrame.Position - root.Position).Magnitude
                        if dist <= Config.Visuals.MaxDistance then
                            local rootPos, onScreen = WorldToScreen(root.Position)
                            if onScreen then
                                -- Dynamic Color Resolution
                                local isVisible = true
                                if Config.Visuals.VisibilityCheck then
                                    isVisible = CheckLineOfSight(Camera.CFrame.Position, root.Position, char)
                                end
                                local themeColor = isVisible and Config.Visuals.BoxColor or Config.Visuals.BoxOccludedColor

                                -- Bounding Box Calculation
                                local head = char:FindFirstChild("Head")
                                local headPos = head and WorldToScreen(head.Position + Vector3.new(0, 0.5, 0)) or Vector2.new(rootPos.X, rootPos.Y - 20)
                                local legPos = WorldToScreen(root.Position - Vector3.new(0, 3, 0))

                                local boxHeight = math.abs(headPos.Y - legPos.Y)
                                local boxWidth = math.max(boxHeight * 0.65, 12)
                                local boxTopLeft = Vector2.new(rootPos.X - (boxWidth / 2), headPos.Y)

                                -- Render Box
                                if Config.Visuals.Boxes then
                                    set.Box.Size = Vector2.new(boxWidth, boxHeight)
                                    set.Box.Position = boxTopLeft
                                    set.Box.Color = themeColor
                                    set.Box.Visible = true

                                    set.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                                    set.BoxOutline.Position = Vector2.new(boxTopLeft.X - 1, boxTopLeft.Y - 1)
                                    set.BoxOutline.Visible = true
                                else
                                    set.Box.Visible = false
                                    set.BoxOutline.Visible = false
                                end

                                -- Render Names
                                if Config.Visuals.Names then
                                    set.Name.Position = Vector2.new(rootPos.X, boxTopLeft.Y - 16)
                                    set.Name.Text = player.DisplayName or player.Name
                                    set.Name.Color = Config.Visuals.NameColor
                                    set.Name.Visible = true
                                else
                                    set.Name.Visible = false
                                end

                                -- Render Distance
                                if Config.Visuals.Distance then
                                    set.Distance.Position = Vector2.new(rootPos.X, boxTopLeft.Y + boxHeight + 2)
                                    set.Distance.Text = string.format("%d m", math.floor(dist * 0.28))
                                    set.Distance.Color = Config.Visuals.DistanceColor
                                    set.Distance.Visible = true
                                else
                                    set.Distance.Visible = false
                                end

                                -- Render Health Bar
                                if Config.Visuals.HealthBars then
                                    local healthPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                    local barWidth = 3
                                    local barHeight = boxHeight * healthPct
                                    local barX = boxTopLeft.X - 6

                                    set.HealthBarOutline.Size = Vector2.new(barWidth + 2, boxHeight + 2)
                                    set.HealthBarOutline.Position = Vector2.new(barX - 1, boxTopLeft.Y - 1)
                                    set.HealthBarOutline.Visible = true

                                    set.HealthBar.Size = Vector2.new(barWidth, barHeight)
                                    set.HealthBar.Position = Vector2.new(barX, boxTopLeft.Y + (boxHeight - barHeight))
                                    set.HealthBar.Color = Color3.fromHSV(healthPct * 0.33, 0.9, 0.95)
                                    set.HealthBar.Visible = true
                                else
                                    set.HealthBarOutline.Visible = false
                                    set.HealthBar.Visible = false
                                end

                                -- Render Tracer Lines
                                if Config.Visuals.Tracers then
                                    local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                    if Config.Visuals.TracerOrigin == "Center" then
                                        origin = GetScreenCenter()
                                    elseif Config.Visuals.TracerOrigin == "Mouse" then
                                        origin = GetMouseLocation()
                                    end
                                    set.Tracer.From = origin
                                    set.Tracer.To = Vector2.new(rootPos.X, boxTopLeft.Y + boxHeight)
                                    set.Tracer.Color = themeColor
                                    set.Tracer.Visible = true
                                else
                                    set.Tracer.Visible = false
                                end

                                -- Render Skeleton
                                if Config.Visuals.Skeleton then
                                    RenderSkeleton(char, set)
                                else
                                    for _, bone in ipairs(set.SkeletonLines) do
                                        bone.Visible = false
                                    end
                                end
                            else
                                HideVisualSet(set)
                            end
                        else
                            HideVisualSet(set)
                        end
                    else
                        HideVisualSet(set)
                    end
                else
                    HideVisualSet(set)
                end
            end
        end
    end

    -- 6. Live Dashboard & HUD Telemetry Cards
    pcall(function()
        if UI and UI.MainFrame and UI.MainFrame.Visible then
            -- Target Card
            if Telemetry.CurrentTarget and Telemetry.CurrentTarget.Character then
                local char = Telemetry.CurrentTarget.Character
                local hum = GetHumanoid(char)
                local root = GetRootPart(char)
                local dist = root and (Camera.CFrame.Position - root.Position).Magnitude or 0
                local hp = hum and math.floor(hum.Health) or 0
                local maxHp = hum and math.floor(hum.MaxHealth) or 100

                UI.TargetCard.Value1.Text = string.format("%s (HP: %d/%d)", Telemetry.CurrentTarget.Name:upper(), hp, maxHp)
                UI.TargetCard.Value2.Text = string.format("DISTANCE: %d STUDS | HITBOX: %s", math.floor(dist), Config.Target.SelectedHitbox:upper())
            else
                UI.TargetCard.Value1.Text = "NO TARGET ACQUIRED"
                UI.TargetCard.Value2.Text = "SEARCHING FIELD OF VIEW..."
            end

            -- Performance Card
            UI.SystemCard.Value1.Text = string.format("FPS: %d  |  PING: %d ms", Telemetry.FPS, Telemetry.Ping)
            UI.SystemCard.Value2.Text = string.format("FOV RADIUS: %d px  |  SMOOTH: %d", Config.Aim.FOV, Config.Aim.Smoothness)

            -- Combat Card
            UI.CombatCard.Value1.Text = string.format("ACCURACY: %d%%  |  HITS: %d", Telemetry.Accuracy, Telemetry.Hits)
            UI.CombatCard.Value2.Text = string.format("SHOTS: %d  |  DMG: %d  |  HS: %d", Telemetry.Shots, Telemetry.TotalDamage, Telemetry.Headshots)
        end

        -- Update Floating HUD
        if UI and UI.HUDFrame then
            UI.HUDFrame.Visible = Config.MasterEnabled and Config.HUD.Enabled

            if UI.HUDFrame.Visible then
                if Telemetry.CurrentTarget then
                    local root = GetRootPart(Telemetry.CurrentTarget.Character)
                    local dist = root and math.floor((Camera.CFrame.Position - root.Position).Magnitude) or 0
                    UI.HUDTargetLabel.Text = string.format("TARGET: %s [%d STUDS]", Telemetry.CurrentTarget.Name:upper(), dist)
                    UI.HUDTargetLabel.TextColor3 = Color3.fromRGB(255, 42, 77)
                else
                    UI.HUDTargetLabel.Text = "TARGET: SCANNING..."
                    UI.HUDTargetLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
                end

                UI.HUDMetricsLabel.Text = string.format("FPS: %d  |  PING: %dms  |  FOV: %d", Telemetry.FPS, Telemetry.Ping, Config.Aim.FOV)
                UI.HUDCombatLabel.Text = string.format("ACC: %d%%  |  HITS: %d  |  MISS: %d", Telemetry.Accuracy, Telemetry.Hits, Telemetry.Shots - Telemetry.Hits)
                UI.HUDReactionLabel.Text = string.format("LAST REACTION: %d ms", Telemetry.ReactionTime)
            end
        end
    end)
end))

-- [CLEANUP HANDLER FOR PLAYER LEAVING]
RegisterEvent(Services.Players.PlayerRemoving:Connect(function(player)
    if Registry.VisualPool[player] then
        HideVisualSet(Registry.VisualPool[player])
        Registry.VisualPool[player] = nil
    end
end))

-- [GLOBAL UNLOAD FUNCTION]
local function Unload()
    for _, conn in ipairs(Registry.Events) do
        pcall(function() conn:Disconnect() end)
    end
    for _, drawing in ipairs(Registry.Drawings) do
        pcall(function() drawing:Remove() end)
    end
    for _, gui in ipairs(Registry.GuiInstances) do
        pcall(function() gui:Destroy() end)
    end
    if getgenv then
        getgenv()._MIMI_ACTIVE = nil
        getgenv()._MIMI_UNLOAD = nil
    end
end

if getgenv then
    getgenv()._MIMI_ACTIVE = true
    getgenv()._MIMI_UNLOAD = Unload
end

-- [COMPLETION BANNER]
print([[
    ========================================================
    [MIMI.FORGE] // RUNTIME INITIALIZATION COMPLETE
    Target: Universal Client Engine
    Status: Operational (UI Toggle: RightShift)
    ========================================================
]])
