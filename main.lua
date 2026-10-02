--[[
    =============================================================================
    SAVIOR.V2 // RUNTIME INSTRUMENTATION & COMBAT TELEMETRY CLIENT
    =============================================================================
    Target Profile: Rivals & Universal Engine Compatibility
    Interface: Matcha-Slate Architecture (Dual-Column Stacked Cards + 3D Viewport)
    Defaults: All Options Unchecked (Clean Zero-State Initialization)
    Distribution: GitHub Loadstring Ready
    Repository: github.com/cylixstudios/saviorv2
    =============================================================================
--]]

-- [ENVIRONMENT CLEANUP]
if getgenv and getgenv()._SAVIOR_ACTIVE then
    pcall(function() getgenv()._SAVIOR_UNLOAD() end)
end

-- [SERVICE DEFINITIONS]
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    HttpService = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
    CoreGui = game:GetService("CoreGui"),
    GuiService = game:GetService("GuiService"),
    Stats = game:GetService("Stats"),
    Teams = game:GetService("Teams")
}

local LocalPlayer = Services.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Services.Workspace.CurrentCamera

-- Detect Drawing API support safely
local HasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")

-- [MASTER CONFIGURATION // ALL OPTIONS UNCHECKED BY DEFAULT]
local Config = {
    MasterEnabled = false,

    -- Aim & Ballistics
    Aim = {
        Enabled = false,
        AimKey = Enum.UserInputType.MouseButton2,
        AimKeyCode = Enum.KeyCode.E,
        UseKeyCode = false,
        Priority = "Crosshair", -- "Crosshair", "Distance", "Health"
        AimPart = "Head",       -- "Head", "Torso", "Limbs", "Closest"
        FOV = 130,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(0, 229, 255),
        Smoothness = 5,
        LineOfSightCheck = false,
        Prediction = false,
        TargetSwitching = false
    },

    -- Visuals / Overlays (Matches Reference Layout - All Default False)
    Visuals = {
        Enabled = false,
        TeamCheck = false,
        VisibleCheck = false,
        VisibleColor = Color3.fromRGB(75, 140, 255),
        OccludedColor = Color3.fromRGB(255, 60, 80),
        TeamBasedColor = false,
        TextGradient = false,
        TextBackground = false,
        Outline = false,
        Glow = false,
        SelfESP = false,
        SizingType = "Bounding", -- "Bounding", "Corner", "3D"
        RenderDistance = 1200,

        -- Box
        Box = {
            Enabled = false,
            FillBox = false,
            BoxType = "2D", -- "2D", "Corner", "Filled"
            Color = Color3.fromRGB(240, 240, 250),
            FillColor = Color3.fromRGB(20, 25, 38)
        },

        -- Name
        Name = {
            Enabled = false,
            Type = "Name", -- "Name", "DisplayName", "Both"
            Color = Color3.fromRGB(255, 255, 255)
        },

        -- Indicators
        Indicators = {
            Distance = false,
            DistanceColor = Color3.fromRGB(200, 205, 220),
            EquippedItem = false,
            EquippedColor = Color3.fromRGB(180, 190, 210),
            Skeleton = false,
            SkeletonColor = Color3.fromRGB(245, 245, 250),
            HeadDot = false,
            HeadDotColor = Color3.fromRGB(255, 255, 255),
            HeadDotGlow = false,
            ProfilePicture = false
        },

        -- Health
        Health = {
            HealthBar = false,
            BarColor = Color3.fromRGB(0, 255, 136),
            HealthBased = false,
            HealthText = false,
            TextPos = "Above Name" -- "Above Name", "Side", "Bottom"
        },

        -- Chams (Native Highlight Overlays)
        Chams = {
            Enabled = false,
            Mode = "Default", -- "Default", "Wireframe", "Flat"
            Filled = false,
            RenderingType = "Static", -- "Static", "Pulse"
            VisibleColor = Color3.fromRGB(75, 140, 255),
            OccludedColor = Color3.fromRGB(255, 50, 80),
            FillTransparency = 0.5,
            OutlineTransparency = 0.1
        },

        -- Tracer
        Tracer = {
            Enabled = false,
            Origin = "Bottom", -- "Bottom", "Center", "Mouse"
            Color = Color3.fromRGB(200, 205, 225)
        }
    },

    -- Reticle / Crosshair
    Crosshair = {
        Enabled = false,
        Size = 10,
        Thickness = 2,
        Gap = 5,
        Opacity = 0.95,
        Color = Color3.fromRGB(0, 229, 255),
        DynamicMovement = false,
        DynamicShooting = false,
        Hitmarker = false,
        HitmarkerColor = Color3.fromRGB(255, 255, 255)
    },

    -- Global Settings
    Settings = {
        UIKey = Enum.KeyCode.RightShift,
        ConfigFile = "savior_v2_rivals_config.json"
    }
}

-- [TELEMETRY TRACKER]
local Telemetry = {
    Shots = 0,
    Hits = 0,
    Misses = 0,
    Headshots = 0,
    TotalDamage = 0,
    Accuracy = 100,
    FPS = 60,
    Ping = 0,
    ReactionTime = 0,
    CurrentTarget = nil,
    IsAiming = false,
    IsFiring = false,
    HitmarkerAlpha = 0,
    AcquisitionTime = 0,
    LastTargetHP = 0
}

-- [REGISTRY & CLEANUP HANDLER]
local Registry = {
    Events = {},
    Drawings = {},
    VisualPool = {},
    ChamsPool = {},
    GuiInstances = {}
}

local function RegisterEvent(conn)
    table.insert(Registry.Events, conn)
    return conn
end

-- [RIVALS-COMPATIBLE ENTITY RESOLVER]
-- In Rivals, characters are standard models or located in workspace.Characters/workspace.Players
local function GetEntityCharacter(player)
    if not player then return nil end

    -- Primary: Player.Character
    if player.Character and player.Character.Parent then
        return player.Character
    end

    -- Secondary: Workspace direct name lookup
    local wsChar = Services.Workspace:FindFirstChild(player.Name)
    if wsChar and wsChar:IsA("Model") then
        return wsChar
    end

    -- Tertiary: Check specialized containers common in Rivals
    local containers = {"Characters", "Players", "Alive", "Entities", "Spawns"}
    for _, folderName in ipairs(containers) do
        local folder = Services.Workspace:FindFirstChild(folderName)
        if folder then
            local target = folder:FindFirstChild(player.Name)
            if target and target:IsA("Model") then
                return target
            end
        end
    end

    return nil
end

local function GetEntityRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("HitboxRoot")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Root")
end

local function GetEntityHumanoid(character)
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function GetEntityHealth(character, humanoid)
    -- Rivals health can be an Attribute on Character or on Humanoid
    if character then
        local hpAttr = character:GetAttribute("Health")
        if hpAttr and type(hpAttr) == "number" then return hpAttr end
    end
    if humanoid then return humanoid.Health end
    return 100
end

local function GetEntityMaxHealth(character, humanoid)
    if character then
        local maxHpAttr = character:GetAttribute("MaxHealth")
        if maxHpAttr and type(maxHpAttr) == "number" then return maxHpAttr end
    end
    if humanoid then return humanoid.MaxHealth end
    return 100
end

local function IsEntityAlive(character)
    if not character then return false end
    local hum = GetEntityHumanoid(character)
    local root = GetEntityRoot(character)
    if not root then return false end

    -- Check attribute health or humanoid health
    local hp = GetEntityHealth(character, hum)
    return hp > 0
end

-- Team Check Supporting Rivals Team Attributes & Services
local function IsEntityTeammate(player, character)
    if not Config.Visuals.TeamCheck then return false end
    if player == LocalPlayer then return true end

    -- Attribute-based team matching (Rivals standard)
    if player:GetAttribute("Team") and LocalPlayer:GetAttribute("Team") then
        return player:GetAttribute("Team") == LocalPlayer:GetAttribute("Team")
    end
    if character and LocalPlayer.Character then
        local cTeam = character:GetAttribute("Team")
        local lTeam = LocalPlayer.Character:GetAttribute("Team")
        if cTeam and lTeam then return cTeam == lTeam end
    end

    -- Engine Team object matching
    if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        return true
    end
    if LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor then
        return true
    end

    return false
end

-- [MATH & PROJECTION UTILITIES]
local function WorldToScreen(worldPos)
    local point, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(point.X, point.Y), onScreen, point.Z
end

local function GetMouseLocation()
    return Services.UserInputService:GetMouseLocation()
end

local function GetScreenCenter()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function CheckLineOfSight(origin, targetPos, character)
    local params = RaycastParams.new()
    params.FilterType = RaycastFilterType.Exclude
    local ignore = { Camera, LocalPlayer.Character }
    if character then table.insert(ignore, character) end
    params.FilterDescendantsInstances = { Camera, LocalPlayer.Character }
    params.IgnoreWater = true

    local dir = (targetPos - origin)
    local result = Services.Workspace:Raycast(origin, dir, params)

    if not result then return true end
    if character and result.Instance and result.Instance:IsDescendantOf(character) then
        return true
    end
    return false
end

-- Resolve Target Hitbox Part (Rivals Head, Torso, Limbs)
local function ResolveTargetPart(character, hitboxType)
    if not character then return nil end
    if hitboxType == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("HitboxHead") or GetEntityRoot(character)
    elseif hitboxType == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or GetEntityRoot(character)
    elseif hitboxType == "Limbs" then
        local limbs = {
            character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftLowerArm"),
            character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("RightLowerArm"),
            character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLowerLeg"),
            character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLowerLeg")
        }
        for _, p in ipairs(limbs) do if p then return p end end
        return GetEntityRoot(character)
    elseif hitboxType == "Closest" then
        local mousePos = GetMouseLocation()
        local bestPart = nil
        local bestDist = math.huge
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") then
                local screenPos, onScreen = WorldToScreen(child.Position)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestPart = child
                    end
                end
            end
        end
        return bestPart or GetEntityRoot(character)
    end
    return character:FindFirstChild("Head") or GetEntityRoot(character)
end

-- Get Best Target Candidate
local function GetBestTarget()
    if not Config.MasterEnabled or not Config.Aim.Enabled then return nil, nil end

    local bestPlayer = nil
    local bestPart = nil
    local bestScore = math.huge
    local mousePos = GetMouseLocation()

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = GetEntityCharacter(player)
            if char and IsEntityAlive(char) and not IsEntityTeammate(player, char) then
                local root = GetEntityRoot(char)
                if root then
                    local part = ResolveTargetPart(char, Config.Aim.AimPart)
                    if part then
                        local screenPos, onScreen, depth = WorldToScreen(part.Position)
                        if onScreen and depth > 0 then
                            local fovDist = (screenPos - mousePos).Magnitude
                            if fovDist <= Config.Aim.FOV then
                                local isVisible = true
                                if Config.Aim.LineOfSightCheck then
                                    isVisible = CheckLineOfSight(Camera.CFrame.Position, part.Position, char)
                                end

                                if isVisible then
                                    local score = 0
                                    local dist3D = (Camera.CFrame.Position - part.Position).Magnitude
                                    local hum = GetEntityHumanoid(char)
                                    local hp = GetEntityHealth(char, hum)

                                    if Config.Aim.Priority == "Crosshair" then
                                        score = fovDist
                                    elseif Config.Aim.Priority == "Distance" then
                                        score = dist3D
                                    elseif Config.Aim.Priority == "Health" then
                                        score = hp
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

-- [BALLISTICS & TARGET TRACKING HOOK]
local function ApplyAim(targetPart)
    if not targetPart then return end
    local targetPos = targetPart.Position

    if Config.Aim.Prediction and targetPart.AssemblyLinearVelocity then
        local pingComp = (Telemetry.Ping / 1000)
        targetPos = targetPos + (targetPart.AssemblyLinearVelocity * pingComp)
    end

    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)
    local lerpRatio = math.clamp(1 / math.max(Config.Aim.Smoothness, 1), 0.05, 1)

    Camera.CFrame = currentCF:Lerp(targetCF, lerpRatio)
end

-- Bind Aim to Post-Camera RenderStep
Services.RunService:BindToRenderStep("SaviorAimExecution", Enum.RenderPriority.Camera.Value + 1, function()
    if Telemetry.IsAiming and Config.MasterEnabled and Config.Aim.Enabled and Telemetry.CurrentTarget then
        local char = GetEntityCharacter(Telemetry.CurrentTarget)
        if char and IsEntityAlive(char) then
            local part = ResolveTargetPart(char, Config.Aim.AimPart)
            if part then
                ApplyAim(part)
            end
        end
    end
end)

-- [DRAWING-BASED OVERLAY INFRASTRUCTURE]
local DrawingObjects = {
    FOVCircle = nil,
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
    fov.Transparency = 0.85
    fov.Color = Config.Aim.FOVColor
    fov.Visible = false
    DrawingObjects.FOVCircle = fov
    table.insert(Registry.Drawings, fov)

    -- Crosshair (4 axes)
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = Config.Crosshair.Thickness
        line.Color = Config.Crosshair.Color
        line.Transparency = Config.Crosshair.Opacity
        line.Visible = false
        table.insert(DrawingObjects.CrosshairLines, line)
        table.insert(Registry.Drawings, line)
    end

    -- Hitmarker (4 diagonal lines)
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

-- Visual Set Allocation for each Player
local function CreatePlayerVisualSet()
    if not HasDrawing then return nil end

    local set = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        BoxFill = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Equipped = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        HealthText = Drawing.new("Text"),
        HeadDot = Drawing.new("Circle"),
        Tracer = Drawing.new("Line"),
        SkeletonLines = {}
    }

    set.Box.Thickness = 1.5
    set.Box.Filled = false

    set.BoxOutline.Thickness = 3
    set.BoxOutline.Filled = false
    set.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    set.BoxOutline.Transparency = 0.5

    set.BoxFill.Filled = true
    set.BoxFill.Color = Config.Visuals.Box.FillColor
    set.BoxFill.Transparency = 0.25

    set.Name.Size = 13
    set.Name.Center = true
    set.Name.Outline = true

    set.Distance.Size = 11
    set.Distance.Center = true
    set.Distance.Outline = true

    set.Equipped.Size = 11
    set.Equipped.Center = true
    set.Equipped.Outline = true

    set.HealthBarOutline.Filled = true
    set.HealthBarOutline.Color = Color3.fromRGB(12, 14, 20)
    set.HealthBarOutline.Transparency = 0.8

    set.HealthBar.Filled = true

    set.HealthText.Size = 11
    set.HealthText.Center = true
    set.HealthText.Outline = true

    set.HeadDot.Thickness = 1.5
    set.HeadDot.Filled = true
    set.HeadDot.Radius = 3.5

    set.Tracer.Thickness = 1.5

    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Thickness = 1.2
        line.Visible = false
        table.insert(set.SkeletonLines, line)
        table.insert(Registry.Drawings, line)
    end

    table.insert(Registry.Drawings, set.Box)
    table.insert(Registry.Drawings, set.BoxOutline)
    table.insert(Registry.Drawings, set.BoxFill)
    table.insert(Registry.Drawings, set.Name)
    table.insert(Registry.Drawings, set.Distance)
    table.insert(Registry.Drawings, set.Equipped)
    table.insert(Registry.Drawings, set.HealthBar)
    table.insert(Registry.Drawings, set.HealthBarOutline)
    table.insert(Registry.Drawings, set.HealthText)
    table.insert(Registry.Drawings, set.HeadDot)
    table.insert(Registry.Drawings, set.Tracer)

    return set
end

local function HideVisualSet(set)
    if not set then return end
    set.Box.Visible = false
    set.BoxOutline.Visible = false
    set.BoxFill.Visible = false
    set.Name.Visible = false
    set.Distance.Visible = false
    set.Equipped.Visible = false
    set.HealthBar.Visible = false
    set.HealthBarOutline.Visible = false
    set.HealthText.Visible = false
    set.HeadDot.Visible = false
    set.Tracer.Visible = false
    for _, bone in ipairs(set.SkeletonLines) do
        bone.Visible = false
    end
end

-- Universal Skeletal Hierarchy
local R15Bones = {
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

local R6Bones = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function RenderSkeleton(char, visualSet, color)
    local isR15 = char:FindFirstChild("UpperTorso") ~= nil
    local boneList = isR15 and R15Bones or R6Bones

    local index = 1
    for _, pair in ipairs(boneList) do
        local p1 = char:FindFirstChild(pair[1])
        local p2 = char:FindFirstChild(pair[2])
        if p1 and p2 and index <= #visualSet.SkeletonLines then
            local s1, onScreen1 = WorldToScreen(p1.Position)
            local s2, onScreen2 = WorldToScreen(p2.Position)
            local line = visualSet.SkeletonLines[index]
            if onScreen1 and onScreen2 then
                line.From = s1
                line.To = s2
                line.Color = color
                line.Visible = true
            else
                line.Visible = false
            end
            index = index + 1
        end
    end

    for i = index, #visualSet.SkeletonLines do
        visualSet.SkeletonLines[i].Visible = false
    end
end

-- Highlight Chams Handler
local function UpdateChams(player, char, isVisible)
    if not char then return end

    if Config.MasterEnabled and Config.Visuals.Enabled and Config.Visuals.Chams.Enabled and not IsEntityTeammate(player, char) and IsEntityAlive(char) then
        local hl = Registry.ChamsPool[player]
        if not hl or hl.Parent ~= char then
            pcall(function() if hl then hl:Destroy() end end)
            hl = Instance.new("Highlight")
            hl.Name = "Savior_Highlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            Registry.ChamsPool[player] = hl
        end

        local fillCol = isVisible and Config.Visuals.Chams.VisibleColor or Config.Visuals.Chams.OccludedColor
        hl.FillColor = fillCol
        hl.OutlineColor = isVisible and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 30, 45)
        hl.FillTransparency = Config.Visuals.Chams.Filled and Config.Visuals.Chams.FillTransparency or 1
        hl.OutlineTransparency = Config.Visuals.Chams.OutlineTransparency
        hl.Enabled = true
    else
        if Registry.ChamsPool[player] then
            Registry.ChamsPool[player].Enabled = false
        end
    end
end

-- [USER INTERFACE // MATCHA SLATE ARCHITECTURE]
local function BuildMatchaInterface()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Savior_Matcha_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Environment protected parent
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

    -- Palette Constants
    local Palette = {
        Bg = Color3.fromRGB(19, 21, 29),
        Card = Color3.fromRGB(27, 30, 43),
        CardBorder = Color3.fromRGB(36, 41, 58),
        Header = Color3.fromRGB(23, 26, 36),
        TextMuted = Color3.fromRGB(123, 130, 154),
        TextLight = Color3.fromRGB(220, 226, 240),
        AccentBlue = Color3.fromRGB(75, 140, 255),
        AccentCyan = Color3.fromRGB(0, 229, 255),
        AccentGreen = Color3.fromRGB(0, 255, 136),
        AccentRed = Color3.fromRGB(255, 60, 80),
        CheckboxOff = Color3.fromRGB(36, 41, 58),
        CheckboxOn = Color3.fromRGB(75, 140, 255)
    }

    -- Main Container Window
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 680, 0, 720)
    MainFrame.Position = UDim2.new(0.5, -460, 0.5, -360)
    MainFrame.BackgroundColor3 = Palette.Bg
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Palette.CardBorder
    MainStroke.Thickness = 1.2

    -- Main Window Dragging
    local isDraggingMain = false
    local dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingMain = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingMain = false
                end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if isDraggingMain and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Top Header
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 42)
    TopBar.BackgroundColor3 = Palette.Header
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 65, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "Matcha"
    TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar

    local function CreatePillBadge(text, posX, width)
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, width, 0, 20)
        pill.Position = UDim2.new(0, posX, 0.5, -10)
        pill.BackgroundColor3 = Color3.fromRGB(32, 36, 50)
        pill.BorderSizePixel = 0
        pill.Parent = TopBar
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = text
        label.TextColor3 = Palette.TextMuted
        label.TextSize = 11
        label.Parent = pill
        return pill
    end

    CreatePillBadge("Interface", 85, 60)
    CreatePillBadge("Standard", 152, 65)

    local RightStatus = Instance.new("TextLabel")
    RightStatus.Size = UDim2.new(0, 120, 1, 0)
    RightStatus.Position = UDim2.new(1, -136, 0, 0)
    RightStatus.BackgroundTransparency = 1
    RightStatus.Font = Enum.Font.GothamMedium
    RightStatus.Text = "Rivals Active"
    RightStatus.TextColor3 = Palette.AccentGreen
    RightStatus.TextSize = 12
    RightStatus.TextXAlignment = Enum.TextXAlignment.Right
    RightStatus.Parent = TopBar

    -- Primary Module Navigation Tabs
    local TabBar = Instance.new("Frame")
    TabBar.Name = "TabBar"
    TabBar.Size = UDim2.new(1, -32, 0, 36)
    TabBar.Position = UDim2.new(0, 16, 0, 48)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = MainFrame

    local TabBarLayout = Instance.new("UIListLayout")
    TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
    TabBarLayout.Padding = UDim.new(0, 6)
    TabBarLayout.Parent = TabBar

    local PrimaryTabButtons = {}
    local PrimaryTabPages = {}

    -- Content Area Frame
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -32, 1, -120)
    ContentContainer.Position = UDim2.new(0, 16, 0, 88)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Bottom Footer
    local Footer = Instance.new("Frame")
    Footer.Name = "Footer"
    Footer.Size = UDim2.new(1, -32, 0, 24)
    Footer.Position = UDim2.new(0, 16, 1, -28)
    Footer.BackgroundTransparency = 1
    Footer.Parent = MainFrame

    local OnlineDot = Instance.new("Frame")
    OnlineDot.Size = UDim2.new(0, 6, 0, 6)
    OnlineDot.Position = UDim2.new(0, 0, 0.5, -3)
    OnlineDot.BackgroundColor3 = Palette.AccentGreen
    OnlineDot.BorderSizePixel = 0
    OnlineDot.Parent = Footer
    Instance.new("UICorner", OnlineDot).CornerRadius = UDim.new(1, 0)

    local OnlineText = Instance.new("TextLabel")
    OnlineText.Size = UDim2.new(0, 100, 1, 0)
    OnlineText.Position = UDim2.new(0, 12, 0, 0)
    OnlineText.BackgroundTransparency = 1
    OnlineText.Font = Enum.Font.Gotham
    OnlineText.Text = "67M online"
    OnlineText.TextColor3 = Palette.TextMuted
    OnlineText.TextSize = 10
    OnlineText.TextXAlignment = Enum.TextXAlignment.Left
    OnlineText.Parent = Footer

    local DiscordLink = Instance.new("TextLabel")
    DiscordLink.Size = UDim2.new(0.4, 0, 1, 0)
    DiscordLink.Position = UDim2.new(0.3, 0, 0, 0)
    DiscordLink.BackgroundTransparency = 1
    DiscordLink.Font = Enum.Font.Gotham
    DiscordLink.Text = "matcha.pink/discord"
    DiscordLink.TextColor3 = Palette.TextMuted
    DiscordLink.TextSize = 10
    DiscordLink.Parent = Footer

    local BuildTag = Instance.new("TextLabel")
    BuildTag.Size = UDim2.new(0, 130, 1, 0)
    BuildTag.Position = UDim2.new(1, -130, 0, 0)
    BuildTag.BackgroundTransparency = 1
    BuildTag.Font = Enum.Font.Gotham
    BuildTag.Text = "Build: Oct 2026"
    BuildTag.TextColor3 = Palette.TextMuted
    BuildTag.TextSize = 10
    BuildTag.TextXAlignment = Enum.TextXAlignment.Right
    BuildTag.Parent = Footer

    -- [3D PREVIEW WINDOW]
    local PreviewFrame = Instance.new("Frame")
    PreviewFrame.Name = "PreviewFrame"
    PreviewFrame.Size = UDim2.new(0, 270, 0, 390)
    PreviewFrame.Position = UDim2.new(0.5, 235, 0.5, -360)
    PreviewFrame.BackgroundColor3 = Palette.Bg
    PreviewFrame.BorderSizePixel = 0
    PreviewFrame.Parent = ScreenGui
    Instance.new("UICorner", PreviewFrame).CornerRadius = UDim.new(0, 10)

    local PreviewStroke = Instance.new("UIStroke", PreviewFrame)
    PreviewStroke.Color = Palette.CardBorder
    PreviewStroke.Thickness = 1.2

    local isDraggingPreview = false
    local prevDragStart, prevStartPos
    PreviewFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingPreview = true
            prevDragStart = input.Position
            prevStartPos = PreviewFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDraggingPreview = false
                end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if isDraggingPreview and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - prevDragStart
            PreviewFrame.Position = UDim2.new(prevStartPos.X.Scale, prevStartPos.X.Offset + delta.X, prevStartPos.Y.Scale, prevStartPos.Y.Offset + delta.Y)
        end
    end)

    local PrevHeader = Instance.new("Frame")
    PrevHeader.Size = UDim2.new(1, -20, 0, 32)
    PrevHeader.Position = UDim2.new(0, 10, 0, 10)
    PrevHeader.BackgroundTransparency = 1
    PrevHeader.Parent = PreviewFrame

    local PrevHeaderLayout = Instance.new("UIListLayout")
    PrevHeaderLayout.FillDirection = Enum.FillDirection.Horizontal
    PrevHeaderLayout.Padding = UDim.new(0, 6)
    PrevHeaderLayout.Parent = PrevHeader

    local function CreatePrevPill(text, isSelected)
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 42, 0, 22)
        pill.BackgroundColor3 = isSelected and Color3.fromRGB(36, 41, 58) or Color3.fromRGB(24, 27, 38)
        pill.BorderSizePixel = 0
        pill.Parent = PrevHeader
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = text
        label.TextColor3 = isSelected and Palette.TextLight or Palette.TextMuted
        label.TextSize = 11
        label.Parent = pill
    end

    CreatePrevPill("ESP", false)
    CreatePrevPill("Preview", false)
    CreatePrevPill("3D", true)

    local Viewport = Instance.new("ViewportFrame")
    Viewport.Size = UDim2.new(1, -24, 1, -54)
    Viewport.Position = UDim2.new(0, 12, 0, 44)
    Viewport.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
    Viewport.BorderSizePixel = 0
    Viewport.Parent = PreviewFrame
    Instance.new("UICorner", Viewport).CornerRadius = UDim.new(0, 8)

    local vCamera = Instance.new("Camera")
    vCamera.Parent = Viewport
    Viewport.CurrentCamera = vCamera

    local dummyModel = Instance.new("Model")
    dummyModel.Name = "PreviewDummy"
    dummyModel.Parent = Viewport

    local function MakePart(name, size, cf, color)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Color = color or Color3.fromRGB(240, 240, 245)
        p.Material = Enum.Material.SmoothPlastic
        p.CanCollide = false
        p.Anchored = true
        p.Parent = dummyModel
        return p
    end

    MakePart("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), Color3.fromRGB(255, 255, 255))
    MakePart("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), Color3.fromRGB(230, 230, 235))
    MakePart("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.6, 0, 0), Color3.fromRGB(40, 40, 45))
    MakePart("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.6, 0, 0), Color3.fromRGB(40, 40, 45))
    MakePart("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.55, -2, 0), Color3.fromRGB(25, 25, 30))
    MakePart("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.55, -2, 0), Color3.fromRGB(25, 25, 30))

    local PrevBox = Instance.new("Frame")
    PrevBox.Size = UDim2.new(0, 120, 0, 210)
    PrevBox.Position = UDim2.new(0.5, -60, 0.5, -105)
    PrevBox.BackgroundTransparency = 1
    PrevBox.BorderSizePixel = 0
    PrevBox.Parent = Viewport

    local PrevBoxStroke = Instance.new("UIStroke", PrevBox)
    PrevBoxStroke.Color = Color3.fromRGB(240, 240, 250)
    PrevBoxStroke.Thickness = 1.2
    PrevBoxStroke.Enabled = false

    local PrevHealthBar = Instance.new("Frame")
    PrevHealthBar.Size = UDim2.new(0, 3, 1, 0)
    PrevHealthBar.Position = UDim2.new(0, -7, 0, 0)
    PrevHealthBar.BackgroundColor3 = Palette.AccentGreen
    PrevHealthBar.BorderSizePixel = 0
    PrevHealthBar.Visible = false
    PrevHealthBar.Parent = PrevBox

    local PrevNameTag = Instance.new("TextLabel")
    PrevNameTag.Size = UDim2.new(1, 0, 0, 16)
    PrevNameTag.Position = UDim2.new(0, 0, 0, -18)
    PrevNameTag.BackgroundTransparency = 1
    PrevNameTag.Font = Enum.Font.GothamMedium
    PrevNameTag.Text = "Target_Player"
    PrevNameTag.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevNameTag.TextSize = 10
    PrevNameTag.Visible = false
    PrevNameTag.Parent = PrevBox

    local PrevDistTag = Instance.new("TextLabel")
    PrevDistTag.Size = UDim2.new(1, 0, 0, 16)
    PrevDistTag.Position = UDim2.new(0, 0, 1, 2)
    PrevDistTag.BackgroundTransparency = 1
    PrevDistTag.Font = Enum.Font.GothamMedium
    PrevDistTag.Text = "42m"
    PrevDistTag.TextColor3 = Palette.TextMuted
    PrevDistTag.TextSize = 9
    PrevDistTag.Visible = false
    PrevDistTag.Parent = PrevBox

    local rotAngle = 0
    RegisterEvent(Services.RunService.RenderStepped:Connect(function(dt)
        rotAngle = rotAngle + (dt * 0.45)
        local camX = math.sin(rotAngle) * 7.5
        local camZ = math.cos(rotAngle) * 7.5
        vCamera.CFrame = CFrame.new(Vector3.new(camX, 0.2, camZ), Vector3.new(0, 0, 0))
    end))

    -- [COMPONENT CREATORS]
    local function CreateCard(parent, title)
        local card = Instance.new("Frame")
        card.BackgroundColor3 = Palette.Card
        card.BorderSizePixel = 0
        card.Parent = parent
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", card)
        stroke.Color = Palette.CardBorder
        stroke.Thickness = 1

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = card

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 12)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.Parent = card

        if title then
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 0, 16)
            t.BackgroundTransparency = 1
            t.Font = Enum.Font.GothamBold
            t.Text = title
            t.TextColor3 = Palette.TextLight
            t.TextSize = 11
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.LayoutOrder = 0
            t.Parent = card
        end

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            card.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 24)
        end)

        return card
    end

    local function AddCheckbox(parent, text, defaultVal, callback, colorSwatch)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local boxBtn = Instance.new("TextButton")
        boxBtn.Size = UDim2.new(0, 14, 0, 14)
        boxBtn.Position = UDim2.new(0, 0, 0.5, -7)
        boxBtn.BackgroundColor3 = defaultVal and Palette.CheckboxOn or Palette.CheckboxOff
        boxBtn.BorderSizePixel = 0
        boxBtn.Text = ""
        boxBtn.AutoButtonColor = false
        boxBtn.Parent = row
        Instance.new("UICorner", boxBtn).CornerRadius = UDim.new(0, 3)

        local checkMark = Instance.new("TextLabel")
        checkMark.Size = UDim2.new(1, 0, 1, 0)
        checkMark.BackgroundTransparency = 1
        checkMark.Font = Enum.Font.GothamBold
        checkMark.Text = defaultVal and "✓" or ""
        checkMark.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkMark.TextSize = 10
        checkMark.Parent = boxBtn

        local label = Instance.new("TextButton")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.Position = UDim2.new(0, 22, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = text
        label.TextColor3 = defaultVal and Palette.TextLight or Palette.TextMuted
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        if colorSwatch then
            if type(colorSwatch) == "table" then
                local s1 = Instance.new("Frame")
                s1.Size = UDim2.new(0, 12, 0, 12)
                s1.Position = UDim2.new(1, -28, 0.5, -6)
                s1.BackgroundColor3 = colorSwatch[1]
                s1.BorderSizePixel = 0
                s1.Parent = row
                Instance.new("UICorner", s1).CornerRadius = UDim.new(0, 2)

                local s2 = Instance.new("Frame")
                s2.Size = UDim2.new(0, 12, 0, 12)
                s2.Position = UDim2.new(1, -12, 0.5, -6)
                s2.BackgroundColor3 = colorSwatch[2]
                s2.BorderSizePixel = 0
                s2.Parent = row
                Instance.new("UICorner", s2).CornerRadius = UDim.new(0, 2)
            else
                local s = Instance.new("Frame")
                s.Size = UDim2.new(0, 12, 0, 12)
                s.Position = UDim2.new(1, -12, 0.5, -6)
                s.BackgroundColor3 = colorSwatch
                s.BorderSizePixel = 0
                s.Parent = row
                Instance.new("UICorner", s).CornerRadius = UDim.new(0, 2)
            end
        end

        local state = defaultVal
        local function toggle()
            state = not state
            boxBtn.BackgroundColor3 = state and Palette.CheckboxOn or Palette.CheckboxOff
            checkMark.Text = state and "✓" or ""
            label.TextColor3 = state and Palette.TextLight or Palette.TextMuted
            callback(state)
        end

        boxBtn.MouseButton1Click:Connect(toggle)
        label.MouseButton1Click:Connect(toggle)
    end

    local function AddDropdown(parent, labelText, options, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 44)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = labelText
        lbl.TextColor3 = Palette.TextMuted
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 24)
        btn.Position = UDim2.new(0, 0, 0, 18)
        btn.BackgroundColor3 = Color3.fromRGB(36, 41, 58)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.Text = "  " .. tostring(defaultVal)
        btn.TextColor3 = Palette.TextLight
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 20, 1, 0)
        arrow.Position = UDim2.new(1, -20, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Font = Enum.Font.Gotham
        arrow.Text = "▼"
        arrow.TextColor3 = Palette.TextMuted
        arrow.TextSize = 8
        arrow.Parent = btn

        local currIdx = 1
        for i, opt in ipairs(options) do
            if opt == defaultVal then currIdx = i break end
        end

        btn.MouseButton1Click:Connect(function()
            currIdx = currIdx + 1
            if currIdx > #options then currIdx = 1 end
            local sel = options[currIdx]
            btn.Text = "  " .. tostring(sel)
            callback(sel)
        end)
    end

    local function AddSlider(parent, labelText, minVal, maxVal, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = labelText
        lbl.TextColor3 = Palette.TextMuted
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local num = Instance.new("TextLabel")
        num.Size = UDim2.new(0.3, 0, 0, 16)
        num.Position = UDim2.new(0.7, 0, 0, 0)
        num.BackgroundTransparency = 1
        num.Font = Enum.Font.Code
        num.Text = tostring(defaultVal)
        num.TextColor3 = Palette.TextLight
        num.TextSize = 11
        num.TextXAlignment = Enum.TextXAlignment.Right
        num.Parent = frame

        local barBg = Instance.new("TextButton")
        barBg.Size = UDim2.new(1, 0, 0, 6)
        barBg.Position = UDim2.new(0, 0, 0, 22)
        barBg.BackgroundColor3 = Color3.fromRGB(36, 41, 58)
        barBg.BorderSizePixel = 0
        barBg.Text = ""
        barBg.AutoButtonColor = false
        barBg.Parent = frame
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        local pct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = Palette.AccentBlue
        fill.BorderSizePixel = 0
        fill.Parent = barBg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function update(input)
            local posX = input.Position.X - barBg.AbsolutePosition.X
            local p = math.clamp(posX / barBg.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            local val = math.floor(minVal + ((maxVal - minVal) * p) + 0.5)
            num.Text = tostring(val)
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

    -- Tab Page Builder
    local function CreateTabPage(name, isFirst)
        local page = Instance.new("Frame")
        page.Name = name .. "_Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = isFirst
        page.Parent = ContentContainer

        local btn = Instance.new("TextButton")
        btn.Name = name .. "_TabBtn"
        btn.Size = UDim2.new(0, 68, 1, 0)
        btn.BackgroundColor3 = isFirst and Color3.fromRGB(36, 41, 58) or Palette.Bg
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = name
        btn.TextColor3 = isFirst and Palette.TextLight or Palette.TextMuted
        btn.TextSize = 12
        btn.Parent = TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        PrimaryTabButtons[name] = btn
        PrimaryTabPages[name] = page

        btn.MouseButton1Click:Connect(function()
            for tName, tPage in pairs(PrimaryTabPages) do
                local isCurr = (tName == name)
                tPage.Visible = isCurr
                local b = PrimaryTabButtons[tName]
                b.BackgroundColor3 = isCurr and Color3.fromRGB(36, 41, 58) or Palette.Bg
                b.TextColor3 = isCurr and Palette.TextLight or Palette.TextMuted
            end
        end)

        return page
    end

    -- 1. VISUALS TAB (Matches image.png - All Default False)
    local VisualsPage = CreateTabPage("Visuals", true)

    local SubNav = Instance.new("Frame")
    SubNav.Size = UDim2.new(1, 0, 0, 26)
    SubNav.BackgroundTransparency = 1
    SubNav.Parent = VisualsPage

    local SubNavLayout = Instance.new("UIListLayout")
    SubNavLayout.FillDirection = Enum.FillDirection.Horizontal
    SubNavLayout.Padding = UDim.new(0, 6)
    SubNavLayout.Parent = SubNav

    local function CreateSubPill(text, isSel)
        local p = Instance.new("Frame")
        p.Size = UDim2.new(0, 52, 1, 0)
        p.BackgroundColor3 = isSel and Color3.fromRGB(36, 41, 58) or Color3.fromRGB(24, 27, 38)
        p.BorderSizePixel = 0
        p.Parent = SubNav
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = text
        lbl.TextColor3 = isSel and Palette.TextLight or Palette.TextMuted
        lbl.TextSize = 11
        lbl.Parent = p
    end

    CreateSubPill("ESP", true)
    CreateSubPill("Crosshair", false)
    CreateSubPill("Misc", false)
    CreateSubPill("Flaggs", false)

    local DualColScroll = Instance.new("ScrollingFrame")
    DualColScroll.Size = UDim2.new(1, 0, 1, -34)
    DualColScroll.Position = UDim2.new(0, 0, 0, 34)
    DualColScroll.BackgroundTransparency = 1
    DualColScroll.BorderSizePixel = 0
    DualColScroll.ScrollBarThickness = 3
    DualColScroll.ScrollBarImageColor3 = Palette.CardBorder
    DualColScroll.Parent = VisualsPage

    local Col1 = Instance.new("Frame")
    Col1.Size = UDim2.new(0.485, 0, 1, 0)
    Col1.Position = UDim2.new(0, 0, 0, 0)
    Col1.BackgroundTransparency = 1
    Col1.Parent = DualColScroll

    local Col1Layout = Instance.new("UIListLayout")
    Col1Layout.Padding = UDim.new(0, 10)
    Col1Layout.Parent = Col1

    local Col2 = Instance.new("Frame")
    Col2.Size = UDim2.new(0.485, 0, 1, 0)
    Col2.Position = UDim2.new(0.515, 0, 0, 0)
    Col2.BackgroundTransparency = 1
    Col2.Parent = DualColScroll

    local Col2Layout = Instance.new("UIListLayout")
    Col2Layout.Padding = UDim.new(0, 10)
    Col2Layout.Parent = Col2

    Col1Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        DualColScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(Col1Layout.AbsoluteContentSize.Y, Col2Layout.AbsoluteContentSize.Y) + 20)
    end)
    Col2Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        DualColScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(Col1Layout.AbsoluteContentSize.Y, Col2Layout.AbsoluteContentSize.Y) + 20)
    end)

    -- [COLUMN 1 CARDS]
    local MainCard = CreateCard(Col1, nil)
    AddCheckbox(MainCard, "Master Enable", Config.MasterEnabled, function(v) Config.MasterEnabled = v end)
    AddCheckbox(MainCard, "Enabled", Config.Visuals.Enabled, function(v) Config.Visuals.Enabled = v end)
    AddCheckbox(MainCard, "Team Check", Config.Visuals.TeamCheck, function(v) Config.Visuals.TeamCheck = v end)
    AddCheckbox(MainCard, "Visible Check", Config.Visuals.VisibleCheck, function(v) Config.Visuals.VisibleCheck = v end, {Config.Visuals.VisibleColor, Config.Visuals.OccludedColor})
    AddCheckbox(MainCard, "Team Based Color", Config.Visuals.TeamBasedColor, function(v) Config.Visuals.TeamBasedColor = v end)
    AddCheckbox(MainCard, "Text Gradient", Config.Visuals.TextGradient, function(v) Config.Visuals.TextGradient = v end, Color3.fromRGB(255, 255, 255))
    AddCheckbox(MainCard, "Text Background", Config.Visuals.TextBackground, function(v) Config.Visuals.TextBackground = v end, Color3.fromRGB(0, 0, 0))
    AddCheckbox(MainCard, "Outline", Config.Visuals.Outline, function(v) Config.Visuals.Outline = v end)
    AddCheckbox(MainCard, "Glow", Config.Visuals.Glow, function(v) Config.Visuals.Glow = v end)
    AddCheckbox(MainCard, "Self ESP", Config.Visuals.SelfESP, function(v) Config.Visuals.SelfESP = v end)
    AddDropdown(MainCard, "Sizing Type", {"Bounding", "Corner", "3D"}, Config.Visuals.SizingType, function(v) Config.Visuals.SizingType = v end)
    AddSlider(MainCard, "Render Distance", 100, 3000, Config.Visuals.RenderDistance, function(v) Config.Visuals.RenderDistance = v end)

    local BoxCard = CreateCard(Col1, "Box")
    AddCheckbox(BoxCard, "Enabled", Config.Visuals.Box.Enabled, function(v)
        Config.Visuals.Box.Enabled = v
        PrevBoxStroke.Enabled = v
    end, Config.Visuals.Box.Color)
    AddCheckbox(BoxCard, "Fill Box", Config.Visuals.Box.FillBox, function(v) Config.Visuals.Box.FillBox = v end, Config.Visuals.Box.FillColor)
    AddDropdown(BoxCard, "Box Type", {"2D", "Corner", "Filled"}, Config.Visuals.Box.BoxType, function(v) Config.Visuals.Box.BoxType = v end)

    local NameCard = CreateCard(Col1, "Name")
    AddCheckbox(NameCard, "Enabled", Config.Visuals.Name.Enabled, function(v)
        Config.Visuals.Name.Enabled = v
        PrevNameTag.Visible = v
    end, Config.Visuals.Name.Color)
    AddDropdown(NameCard, "Type", {"Name", "DisplayName", "Both"}, Config.Visuals.Name.Type, function(v) Config.Visuals.Name.Type = v end)

    -- [COLUMN 2 CARDS]
    local IndCard = CreateCard(Col2, "Indicators")
    AddCheckbox(IndCard, "Distance", Config.Visuals.Indicators.Distance, function(v)
        Config.Visuals.Indicators.Distance = v
        PrevDistTag.Visible = v
    end, Config.Visuals.Indicators.DistanceColor)
    AddCheckbox(IndCard, "Equipped Item", Config.Visuals.Indicators.EquippedItem, function(v) Config.Visuals.Indicators.EquippedItem = v end, Config.Visuals.Indicators.EquippedColor)
    AddCheckbox(IndCard, "Skeleton", Config.Visuals.Indicators.Skeleton, function(v) Config.Visuals.Indicators.Skeleton = v end, Config.Visuals.Indicators.SkeletonColor)
    AddCheckbox(IndCard, "Head Dot", Config.Visuals.Indicators.HeadDot, function(v) Config.Visuals.Indicators.HeadDot = v end, Config.Visuals.Indicators.HeadDotColor)
    AddCheckbox(IndCard, "Head Dot Glow", Config.Visuals.Indicators.HeadDotGlow, function(v) Config.Visuals.Indicators.HeadDotGlow = v end)
    AddCheckbox(IndCard, "Profile Picture", Config.Visuals.Indicators.ProfilePicture, function(v) Config.Visuals.Indicators.ProfilePicture = v end)

    local HealthCard = CreateCard(Col2, "Health")
    AddCheckbox(HealthCard, "Health Bar", Config.Visuals.Health.HealthBar, function(v)
        Config.Visuals.Health.HealthBar = v
        PrevHealthBar.Visible = v
    end, Config.Visuals.Health.BarColor)
    AddCheckbox(HealthCard, "Health Based", Config.Visuals.Health.HealthBased, function(v) Config.Visuals.Health.HealthBased = v end)
    AddCheckbox(HealthCard, "Health Text", Config.Visuals.Health.HealthText, function(v) Config.Visuals.Health.HealthText = v end)
    AddDropdown(HealthCard, "Text Pos", {"Above Name", "Side", "Bottom"}, Config.Visuals.Health.TextPos, function(v) Config.Visuals.Health.TextPos = v end)

    local ChamsCard = CreateCard(Col2, "Chams")
    AddDropdown(ChamsCard, "Mode", {"Default", "Wireframe", "Flat"}, Config.Visuals.Chams.Mode, function(v) Config.Visuals.Chams.Mode = v end)
    AddCheckbox(ChamsCard, "Enabled", Config.Visuals.Chams.Enabled, function(v) Config.Visuals.Chams.Enabled = v end, {Config.Visuals.Chams.VisibleColor, Config.Visuals.Chams.OccludedColor})
    AddCheckbox(ChamsCard, "Filled", Config.Visuals.Chams.Filled, function(v) Config.Visuals.Chams.Filled = v end, Color3.fromRGB(255, 255, 255))
    AddDropdown(ChamsCard, "Rendering Type", {"Static", "Pulse"}, Config.Visuals.Chams.RenderingType, function(v) Config.Visuals.Chams.RenderingType = v end)

    local TracerCard = CreateCard(Col2, "Tracer")
    AddCheckbox(TracerCard, "Enabled", Config.Visuals.Tracer.Enabled, function(v) Config.Visuals.Tracer.Enabled = v end, Config.Visuals.Tracer.Color)
    AddDropdown(TracerCard, "Origin", {"Bottom", "Center", "Mouse"}, Config.Visuals.Tracer.Origin, function(v) Config.Visuals.Tracer.Origin = v end)

    -- 2. COMBAT TAB (All Default False)
    local CombatPage = CreateTabPage("Combat", false)
    local CombatCol1 = Instance.new("Frame")
    CombatCol1.Size = UDim2.new(0.485, 0, 1, 0)
    CombatCol1.BackgroundTransparency = 1
    CombatCol1.Parent = CombatPage
    Instance.new("UIListLayout", CombatCol1).Padding = UDim.new(0, 10)

    local CombatCol2 = Instance.new("Frame")
    CombatCol2.Size = UDim2.new(0.485, 0, 1, 0)
    CombatCol2.Position = UDim2.new(0.515, 0, 0, 0)
    CombatCol2.BackgroundTransparency = 1
    CombatCol2.Parent = CombatPage
    Instance.new("UIListLayout", CombatCol2).Padding = UDim.new(0, 10)

    local AimCard = CreateCard(CombatCol1, "Targeting Module")
    AddCheckbox(AimCard, "Aim Assist Enabled", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    AddCheckbox(AimCard, "Show FOV Circle", Config.Aim.ShowFOV, function(v) Config.Aim.ShowFOV = v end)
    AddDropdown(AimCard, "Priority", {"Crosshair", "Distance", "Health"}, Config.Aim.Priority, function(v) Config.Aim.Priority = v end)
    AddDropdown(AimCard, "Hitbox Part", {"Head", "Torso", "Limbs", "Closest"}, Config.Aim.AimPart, function(v) Config.Aim.AimPart = v end)
    AddSlider(AimCard, "Field Of View", 30, 450, Config.Aim.FOV, function(v)
        Config.Aim.FOV = v
        if DrawingObjects.FOVCircle then DrawingObjects.FOVCircle.Radius = v end
    end)
    AddSlider(AimCard, "Smoothness", 1, 20, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)
    AddCheckbox(AimCard, "Line-of-Sight Check", Config.Aim.LineOfSightCheck, function(v) Config.Aim.LineOfSightCheck = v end)
    AddCheckbox(AimCard, "Movement Prediction", Config.Aim.Prediction, function(v) Config.Aim.Prediction = v end)

    local CrossCard = CreateCard(CombatCol2, "Crosshair & Reticle")
    AddCheckbox(CrossCard, "Custom Crosshair", Config.Crosshair.Enabled, function(v) Config.Crosshair.Enabled = v end, Config.Crosshair.Color)
    AddSlider(CrossCard, "Size", 4, 30, Config.Crosshair.Size, function(v) Config.Crosshair.Size = v end)
    AddSlider(CrossCard, "Thickness", 1, 6, Config.Crosshair.Thickness, function(v) Config.Crosshair.Thickness = v end)
    AddSlider(CrossCard, "Gap", 1, 20, Config.Crosshair.Gap, function(v) Config.Crosshair.Gap = v end)
    AddCheckbox(CrossCard, "Dynamic Movement", Config.Crosshair.DynamicMovement, function(v) Config.Crosshair.DynamicMovement = v end)
    AddCheckbox(CrossCard, "Dynamic Shooting", Config.Crosshair.DynamicShooting, function(v) Config.Crosshair.DynamicShooting = v end)
    AddCheckbox(CrossCard, "Hitmarker (X)", Config.Crosshair.Hitmarker, function(v) Config.Crosshair.Hitmarker = v end)

    local StatsCard = CreateCard(CombatCol2, "Combat Telemetry")
    local AccLabel = Instance.new("TextLabel")
    AccLabel.Size = UDim2.new(1, 0, 0, 18)
    AccLabel.BackgroundTransparency = 1
    AccLabel.Font = Enum.Font.Code
    AccLabel.Text = "ACCURACY: 100% | SHOTS: 0"
    AccLabel.TextColor3 = Palette.AccentGreen
    AccLabel.TextSize = 11
    AccLabel.TextXAlignment = Enum.TextXAlignment.Left
    AccLabel.Parent = StatsCard

    local HitsLabel = Instance.new("TextLabel")
    HitsLabel.Size = UDim2.new(1, 0, 0, 18)
    HitsLabel.BackgroundTransparency = 1
    HitsLabel.Font = Enum.Font.Code
    HitsLabel.Text = "HITS: 0 | MISSES: 0 | DMG: 0"
    HitsLabel.TextColor3 = Palette.TextLight
    HitsLabel.TextSize = 11
    HitsLabel.TextXAlignment = Enum.TextXAlignment.Left
    HitsLabel.Parent = StatsCard

    -- 3. CONFIGS TAB
    local ConfigsPage = CreateTabPage("Configs", false)
    local CfgCard = CreateCard(ConfigsPage, "Configuration Manager")

    local function CreateButton(parent, text, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(36, 41, 58)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = text
        btn.TextColor3 = Palette.TextLight
        btn.TextSize = 12
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            btn.BackgroundColor3 = Palette.AccentBlue
            task.wait(0.12)
            btn.BackgroundColor3 = Color3.fromRGB(36, 41, 58)
            cb()
        end)
    end

    CreateButton(CfgCard, "Save Configuration", function()
        pcall(function()
            if writefile then
                writefile(Config.Settings.ConfigFile, Services.HttpService:JSONEncode(Config))
            end
        end)
    end)

    CreateButton(CfgCard, "Load Configuration", function()
        pcall(function()
            if readfile and isfile and isfile(Config.Settings.ConfigFile) then
                local data = Services.HttpService:JSONDecode(readfile(Config.Settings.ConfigFile))
                for k, v in pairs(data) do Config[k] = v end
            end
        end)
    end)

    CreateButton(CfgCard, "Reset Defaults", function()
        Config.Aim.FOV = 130
        Config.Aim.Smoothness = 5
        Config.Visuals.RenderDistance = 1200
    end)

    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        PreviewFrame = PreviewFrame,
        AccLabel = AccLabel,
        HitsLabel = HitsLabel
    }
end

local UI = BuildMatchaInterface()

-- [INPUT HANDLING]
RegisterEvent(Services.UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Config.Settings.UIKey then
        UI.MainFrame.Visible = not UI.MainFrame.Visible
        UI.PreviewFrame.Visible = UI.MainFrame.Visible
        return
    end

    if not processed then
        if input.UserInputType == Config.Aim.AimKey or (Config.Aim.UseKeyCode and input.KeyCode == Config.Aim.AimKeyCode) then
            Telemetry.IsAiming = true
            if Telemetry.CurrentTarget then
                Telemetry.AcquisitionTime = os.clock()
            end
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Telemetry.IsFiring = true
            Telemetry.Shots = Telemetry.Shots + 1
            if Telemetry.AcquisitionTime > 0 then
                Telemetry.ReactionTime = math.floor((os.clock() - Telemetry.AcquisitionTime) * 1000)
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

-- [PERFORMANCE METRICS CALCULATOR]
local fCount = 0
local lastFpsTime = os.clock()
RegisterEvent(Services.RunService.RenderStepped:Connect(function()
    fCount = fCount + 1
    local now = os.clock()
    if now - lastFpsTime >= 0.5 then
        Telemetry.FPS = math.floor(fCount / (now - lastFpsTime))
        fCount = 0
        lastFpsTime = now

        pcall(function()
            local pingItem = Services.Stats.Network.ServerStatsItem["Data Ping"]
            if pingItem then Telemetry.Ping = math.floor(pingItem:GetValue()) end
        end)
    end
end))

-- [DYNAMIC CROSSHAIR & HITMARKER]
local function UpdateCrosshair()
    if not HasDrawing then return end
    local enabled = Config.MasterEnabled and Config.Crosshair.Enabled

    local center = GetScreenCenter()
    local gap = Config.Crosshair.Gap
    local size = Config.Crosshair.Size

    if Config.Crosshair.DynamicMovement and LocalPlayer.Character then
        local hum = GetEntityHumanoid(LocalPlayer.Character)
        if hum and hum.MoveDirection.Magnitude > 0 then gap = gap + 4 end
    end
    if Config.Crosshair.DynamicShooting and Telemetry.IsFiring then gap = gap + 6 end

    local lines = DrawingObjects.CrosshairLines
    if #lines == 4 then
        lines[1].Visible = enabled
        lines[2].Visible = enabled
        lines[3].Visible = enabled
        lines[4].Visible = enabled

        if enabled then
            local col = Config.Crosshair.Color
            local th = Config.Crosshair.Thickness
            local op = Config.Crosshair.Opacity

            lines[1].From = Vector2.new(center.X, center.Y - gap)
            lines[1].To = Vector2.new(center.X, center.Y - gap - size)
            lines[1].Thickness = th; lines[1].Color = col; lines[1].Transparency = op

            lines[2].From = Vector2.new(center.X, center.Y + gap)
            lines[2].To = Vector2.new(center.X, center.Y + gap + size)
            lines[2].Thickness = th; lines[2].Color = col; lines[2].Transparency = op

            lines[3].From = Vector2.new(center.X - gap, center.Y)
            lines[3].To = Vector2.new(center.X - gap - size, center.Y)
            lines[3].Thickness = th; lines[3].Color = col; lines[3].Transparency = op

            lines[4].From = Vector2.new(center.X + gap, center.Y)
            lines[4].To = Vector2.new(center.X + gap + size, center.Y)
            lines[4].Thickness = th; lines[4].Color = col; lines[4].Transparency = op
        end
    end

    local hm = DrawingObjects.HitmarkerLines
    if #hm == 4 then
        local vis = (Telemetry.HitmarkerAlpha > 0)
        for _, l in ipairs(hm) do
            l.Visible = vis
            if vis then
                l.Color = Config.Crosshair.HitmarkerColor
                l.Transparency = Telemetry.HitmarkerAlpha
            end
        end
        if vis then
            local hs = 10
            hm[1].From = Vector2.new(center.X - hs, center.Y - hs); hm[1].To = Vector2.new(center.X - 3, center.Y - 3)
            hm[2].From = Vector2.new(center.X + hs, center.Y - hs); hm[2].To = Vector2.new(center.X + 3, center.Y - 3)
            hm[3].From = Vector2.new(center.X - hs, center.Y + hs); hm[3].To = Vector2.new(center.X - 3, center.Y + 3)
            hm[4].From = Vector2.new(center.X + hs, center.Y + hs); hm[4].To = Vector2.new(center.X + 3, center.Y + 3)
            Telemetry.HitmarkerAlpha = math.clamp(Telemetry.HitmarkerAlpha - 0.05, 0, 1)
        end
    end
end

-- [MAIN RENDER LOOP]
RegisterEvent(Services.RunService.RenderStepped:Connect(function()
    -- 1. Candidate Acquisition
    local targetPlayer, targetPart = GetBestTarget()
    Telemetry.CurrentTarget = targetPlayer

    -- Target Damage Delta Tracking
    if targetPlayer then
        local char = GetEntityCharacter(targetPlayer)
        if char then
            local hum = GetEntityHumanoid(char)
            local hp = GetEntityHealth(char, hum)
            if Telemetry.LastTargetHP > 0 and hp < Telemetry.LastTargetHP then
                local delta = Telemetry.LastTargetHP - hp
                Telemetry.Hits = Telemetry.Hits + 1
                Telemetry.TotalDamage = Telemetry.TotalDamage + delta
                Telemetry.HitmarkerAlpha = 1.0
                if targetPart and targetPart.Name == "Head" then
                    Telemetry.Headshots = Telemetry.Headshots + 1
                end
            end
            Telemetry.LastTargetHP = hp
        end
    else
        Telemetry.LastTargetHP = 0
    end

    -- Recalculate Accuracy
    if Telemetry.Shots > 0 then
        Telemetry.Accuracy = math.clamp(math.floor((Telemetry.Hits / Telemetry.Shots) * 100), 0, 100)
    end

    -- 2. FOV Circle Update
    if HasDrawing and DrawingObjects.FOVCircle then
        local showFOV = Config.MasterEnabled and Config.Aim.Enabled and Config.Aim.ShowFOV
        DrawingObjects.FOVCircle.Visible = showFOV
        if showFOV then
            DrawingObjects.FOVCircle.Position = GetMouseLocation()
            DrawingObjects.FOVCircle.Radius = Config.Aim.FOV
            DrawingObjects.FOVCircle.Color = Config.Aim.FOVColor
        end
    end

    -- 3. Reticle Update
    UpdateCrosshair()

    -- 4. Visuals & Chams Loop
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not Registry.VisualPool[player] and HasDrawing then
                Registry.VisualPool[player] = CreatePlayerVisualSet()
            end
            local set = Registry.VisualPool[player]
            local char = GetEntityCharacter(player)
            local shouldRender = Config.MasterEnabled and Config.Visuals.Enabled and char and IsEntityAlive(char) and not IsEntityTeammate(player, char)

            if shouldRender then
                local root = GetEntityRoot(char)
                local hum = GetEntityHumanoid(char)
                if root then
                    local dist = (Camera.CFrame.Position - root.Position).Magnitude
                    if dist <= Config.Visuals.RenderDistance then
                        local rootPos, onScreen = WorldToScreen(root.Position)
                        local isVisible = true
                        if Config.Visuals.VisibleCheck then
                            isVisible = CheckLineOfSight(Camera.CFrame.Position, root.Position, char)
                        end

                        UpdateChams(player, char, isVisible)

                        if onScreen and set then
                            local themeCol = isVisible and Config.Visuals.VisibleColor or Config.Visuals.OccludedColor

                            -- Accurate Bounding Box Calculation
                            local head = char:FindFirstChild("Head") or root
                            local headPos = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
                            local legPos = WorldToScreen(root.Position - Vector3.new(0, 3, 0))
                            local boxHeight = math.abs(headPos.Y - legPos.Y)
                            local boxWidth = math.max(boxHeight * 0.65, 12)
                            local boxTopLeft = Vector2.new(rootPos.X - (boxWidth / 2), headPos.Y)

                            -- Bounding Box
                            if Config.Visuals.Box.Enabled then
                                set.Box.Size = Vector2.new(boxWidth, boxHeight)
                                set.Box.Position = boxTopLeft
                                set.Box.Color = Config.Visuals.Box.Color
                                set.Box.Visible = true

                                set.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                                set.BoxOutline.Position = Vector2.new(boxTopLeft.X - 1, boxTopLeft.Y - 1)
                                set.BoxOutline.Visible = true

                                if Config.Visuals.Box.FillBox then
                                    set.BoxFill.Size = Vector2.new(boxWidth, boxHeight)
                                    set.BoxFill.Position = boxTopLeft
                                    set.BoxFill.Visible = true
                                else
                                    set.BoxFill.Visible = false
                                end
                            else
                                set.Box.Visible = false
                                set.BoxOutline.Visible = false
                                set.BoxFill.Visible = false
                            end

                            -- Names
                            if Config.Visuals.Name.Enabled then
                                set.Name.Position = Vector2.new(rootPos.X, boxTopLeft.Y - 16)
                                set.Name.Text = (Config.Visuals.Name.Type == "DisplayName") and (player.DisplayName or player.Name) or player.Name
                                set.Name.Color = Config.Visuals.Name.Color
                                set.Name.Visible = true
                            else
                                set.Name.Visible = false
                            end

                            -- Distance
                            if Config.Visuals.Indicators.Distance then
                                set.Distance.Position = Vector2.new(rootPos.X, boxTopLeft.Y + boxHeight + 2)
                                set.Distance.Text = string.format("%d m", math.floor(dist * 0.28))
                                set.Distance.Color = Config.Visuals.Indicators.DistanceColor
                                set.Distance.Visible = true
                            else
                                set.Distance.Visible = false
                            end

                            -- Equipped Tool / Weapon (Rivals Weapon Detection)
                            if Config.Visuals.Indicators.EquippedItem then
                                local tool = char:FindFirstChildOfClass("Tool")
                                if not tool then
                                    -- Check weapon models welded to character hands/torso in Rivals
                                    for _, child in ipairs(char:GetChildren()) do
                                        if child:IsA("Model") and (string.find(child.Name:lower(), "gun") or string.find(child.Name:lower(), "weapon") or string.find(child.Name:lower(), "rifle")) then
                                            tool = child
                                            break
                                        end
                                    end
                                end
                                if tool then
                                    set.Equipped.Position = Vector2.new(rootPos.X, boxTopLeft.Y + boxHeight + (Config.Visuals.Indicators.Distance and 16 or 2))
                                    set.Equipped.Text = "[" .. tool.Name .. "]"
                                    set.Equipped.Color = Config.Visuals.Indicators.EquippedColor
                                    set.Equipped.Visible = true
                                else
                                    set.Equipped.Visible = false
                                end
                            else
                                set.Equipped.Visible = false
                            end

                            -- Health Bar & Health Calculation
                            if Config.Visuals.Health.HealthBar then
                                local curHp = GetEntityHealth(char, hum)
                                local maxHp = GetEntityMaxHealth(char, hum)
                                local pct = math.clamp(curHp / math.max(maxHp, 1), 0, 1)
                                local barWidth = 3
                                local barHeight = boxHeight * pct
                                local barX = boxTopLeft.X - 6

                                set.HealthBarOutline.Size = Vector2.new(barWidth + 2, boxHeight + 2)
                                set.HealthBarOutline.Position = Vector2.new(barX - 1, boxTopLeft.Y - 1)
                                set.HealthBarOutline.Visible = true

                                set.HealthBar.Size = Vector2.new(barWidth, barHeight)
                                set.HealthBar.Position = Vector2.new(barX, boxTopLeft.Y + (boxHeight - barHeight))
                                set.HealthBar.Color = Config.Visuals.Health.HealthBased and Color3.fromHSV(pct * 0.33, 0.9, 0.95) or Config.Visuals.Health.BarColor
                                set.HealthBar.Visible = true
                            else
                                set.HealthBar.Visible = false
                                set.HealthBarOutline.Visible = false
                            end

                            -- Head Dot
                            if Config.Visuals.Indicators.HeadDot and head then
                                local hScreen, hOn = WorldToScreen(head.Position)
                                if hOn then
                                    set.HeadDot.Position = hScreen
                                    set.HeadDot.Color = Config.Visuals.Indicators.HeadDotColor
                                    set.HeadDot.Visible = true
                                else
                                    set.HeadDot.Visible = false
                                end
                            else
                                set.HeadDot.Visible = false
                            end

                            -- Skeletal Overlay
                            if Config.Visuals.Indicators.Skeleton then
                                RenderSkeleton(char, set, Config.Visuals.Indicators.SkeletonColor)
                            else
                                for _, b in ipairs(set.SkeletonLines) do b.Visible = false end
                            end

                            -- Screen Tracers
                            if Config.Visuals.Tracer.Enabled then
                                local orig = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                if Config.Visuals.Tracer.Origin == "Center" then orig = GetScreenCenter()
                                elseif Config.Visuals.Tracer.Origin == "Mouse" then orig = GetMouseLocation() end
                                set.Tracer.From = orig
                                set.Tracer.To = Vector2.new(rootPos.X, boxTopLeft.Y + boxHeight)
                                set.Tracer.Color = Config.Visuals.Tracer.Color
                                set.Tracer.Visible = true
                            else
                                set.Tracer.Visible = false
                            end
                        else
                            HideVisualSet(set)
                        end
                    else
                        HideVisualSet(set)
                        UpdateChams(player, char, false)
                    end
                else
                    HideVisualSet(set)
                    UpdateChams(player, char, false)
                end
            else
                HideVisualSet(set)
                UpdateChams(player, char, false)
            end
        end
    end

    -- Update Live Dashboard Readouts
    if UI and UI.AccLabel and UI.HitsLabel then
        UI.AccLabel.Text = string.format("ACCURACY: %d%% | SHOTS: %d", Telemetry.Accuracy, Telemetry.Shots)
        UI.HitsLabel.Text = string.format("HITS: %d | MISSES: %d | DMG: %d", Telemetry.Hits, math.max(Telemetry.Shots - Telemetry.Hits, 0), Telemetry.TotalDamage)
    end
end))

-- [PLAYER REMOVED CLEANUP]
RegisterEvent(Services.Players.PlayerRemoving:Connect(function(player)
    if Registry.VisualPool[player] then
        HideVisualSet(Registry.VisualPool[player])
        Registry.VisualPool[player] = nil
    end
    if Registry.ChamsPool[player] then
        pcall(function() Registry.ChamsPool[player]:Destroy() end)
        Registry.ChamsPool[player] = nil
    end
end))

-- [GLOBAL UNLOAD HANDLER]
local function Unload()
    pcall(function() Services.RunService:UnbindFromRenderStep("SaviorAimExecution") end)
    for _, conn in ipairs(Registry.Events) do pcall(function() conn:Disconnect() end) end
    for _, dw in ipairs(Registry.Drawings) do pcall(function() dw:Remove() end) end
    for _, ch in pairs(Registry.ChamsPool) do pcall(function() ch:Destroy() end) end
    for _, gui in ipairs(Registry.GuiInstances) do pcall(function() gui:Destroy() end) end
    if getgenv then
        getgenv()._SAVIOR_ACTIVE = nil
        getgenv()._SAVIOR_UNLOAD = nil
    end
end

if getgenv then
    getgenv()._SAVIOR_ACTIVE = true
    getgenv()._SAVIOR_UNLOAD = Unload
end

print("[SAVIOR.V2] // Rivals Engine Compatibility Initialized (All options unchecked)")
