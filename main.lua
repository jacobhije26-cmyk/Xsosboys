-- XSOSBOYS Modern Tabbed Menu with True Sticky Aim Lock, Anti-Desync Resolver & 2D Box ESP
-- Password: bocpogi | Menu Toggle Key: F6 / RightControl

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local PASSWORD = "bocpogi"

local Settings = {
    BigHeadEnabled = false,
    FastWalkEnabled = true,
    AimBotEnabled = true,          -- Enabled so it attaches on right-click immediately
    RightClickToAim = true,        -- Hold Right-Click (MouseButton2) to attach/lock-on
    StickyLock = true,             -- Stay locked onto target while holding RMB without dropping
    AimbotMode = "Smooth",         -- Options: "Smooth" or "Rage"
    AimbotSmoothness = 0.55,       -- Lerp smoothness for Smooth mode (higher = stickier)
    TargetPart = "Head",           -- "Head" or "Torso" / "HumanoidRootPart"
    AntiDesyncResolver = true,     -- Anti-Desync Resolver so aimbot ignores target fake lag/desync
    PredictionEnabled = false,     -- Direct part hit lock (set false to prevent drifting away)
    PredictionAmount = 0.05,       -- Optional subtle prediction lead
    DesyncEnabled = false,         -- Player Anti-Lock Desync (makes enemy aimbots miss you)
    DesyncMode = "Velocity",       -- "Velocity", "Underground", or "FakeLag"
    ShowFOVCircle = true,
    ESPEnabled = true,             -- Master ESP toggle
    ESPBoxes = true,               -- 2D Box outline around players
    ESPNames = true,               -- Name label above box
    ESPHealth = true,              -- Health % label
    ESPDistance = true,            -- Distance [37m] label
    ESPHighlight = false,          -- Character highlight / chams
    JumpBoostEnabled = false,
    FlyEnabled = false,
    FlingEnabled = false,
    BigHeadSize = 3,
    WalkSpeed = 60,
    AimFOV = 65,
    FlySpeed = 50,
    FlingPower = 100,
}

local ESPGui = nil
local ESPObjects = {}
local ESPHighlights = {}
local FlyBodyVelocity = nil
local FlyBodyGyro = nil
local FOVCircleGui = nil
local FOVFrame = nil
local FOVNumberLabel = nil
local FOVStroke = nil
local CurrentTarget = nil
local CurrentTargetPart = nil
local IsRightClicking = false

-- Target Velocity Cache
local LastTargetPositions = {}

----------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------
local function getHumanoid(target)
    if not target then return nil end
    local character = target:IsA("Model") and target or (target.Character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(target)
    if not target then return nil end
    local character = target:IsA("Model") and target or (target.Character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
end

local function isTargetAlive(target)
    local humanoid = getHumanoid(target)
    return humanoid and humanoid.Health > 0
end

local function getTargetPart(character)
    if not character then return nil end
    if Settings.TargetPart == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    else
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Head")
    end
end

local function makeCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = instance
    return corner
end

local function makeStroke(instance, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(255, 0, 0)
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.3
    stroke.Parent = instance
    return stroke
end

----------------------------------------------------
-- NUMBERED VISUAL FOV CIRCLE OVERLAY
----------------------------------------------------
local function createFOVCircle()
    if FOVCircleGui then FOVCircleGui:Destroy() end

    FOVCircleGui = Instance.new("ScreenGui")
    FOVCircleGui.Name = "XSOSBOYS_FOVCircle"
    FOVCircleGui.ResetOnSpawn = false
    FOVCircleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    FOVCircleGui.IgnoreGuiInset = true
    FOVCircleGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Red Circle Frame
    FOVFrame = Instance.new("Frame")
    FOVFrame.Name = "FOVRing"
    FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    FOVFrame.BackgroundTransparency = 1
    FOVFrame.BorderSizePixel = 0
    FOVFrame.Parent = FOVCircleGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = FOVFrame

    FOVStroke = Instance.new("UIStroke")
    FOVStroke.Name = "FOVBorder"
    FOVStroke.Color = Color3.fromRGB(255, 30, 30)
    FOVStroke.Thickness = 2
    FOVStroke.Transparency = 0.2
    FOVStroke.Parent = FOVFrame

    -- FOV Number Text Label
    FOVNumberLabel = Instance.new("TextLabel")
    FOVNumberLabel.Name = "FOVNumber"
    FOVNumberLabel.Size = UDim2.new(0, 220, 0, 18)
    FOVNumberLabel.AnchorPoint = Vector2.new(0.5, 0)
    FOVNumberLabel.Position = UDim2.new(0.5, 0, 1, 4)
    FOVNumberLabel.BackgroundTransparency = 1
    FOVNumberLabel.Font = Enum.Font.GothamBold
    FOVNumberLabel.Text = "FOV: " .. tostring(Settings.AimFOV) .. "px"
    FOVNumberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    FOVNumberLabel.TextSize = 12
    FOVNumberLabel.Parent = FOVFrame

    local textStroke = Instance.new("UIStroke")
    textStroke.Color = Color3.fromRGB(0, 0, 0)
    textStroke.Thickness = 1.5
    textStroke.Parent = FOVNumberLabel
end

local function updateFOVCirclePosition()
    if not FOVFrame or not FOVNumberLabel or not FOVStroke then return end

    if Settings.ShowFOVCircle then
        FOVFrame.Visible = true
        local radius = Settings.AimFOV
        local diameter = radius * 2
        FOVFrame.Size = UDim2.new(0, diameter, 0, diameter)

        local mousePos = UserInputService:GetMouseLocation()
        FOVFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)

        -- Visual feedback when attached / locked on target
        if CurrentTarget and CurrentTargetPart and (not Settings.RightClickToAim or IsRightClicking) then
            local targetName = (typeof(CurrentTarget) == "Instance" and (CurrentTarget.DisplayName or CurrentTarget.Name)) or "Target"
            FOVStroke.Color = Color3.fromRGB(50, 255, 120)
            FOVStroke.Thickness = 2.5
            FOVNumberLabel.Text = "FOV: " .. tostring(Settings.AimFOV) .. "px [LOCKED: " .. targetName .. "]"
            FOVNumberLabel.TextColor3 = Color3.fromRGB(80, 255, 150)
        else
            FOVStroke.Color = Color3.fromRGB(255, 30, 30)
            FOVStroke.Thickness = 2
            FOVNumberLabel.Text = "FOV: " .. tostring(Settings.AimFOV) .. "px [" .. Settings.AimbotMode .. "]"
            FOVNumberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        FOVFrame.Visible = false
    end
end

----------------------------------------------------
-- 2D BOX ESP SYSTEM (BOX, NAME, HP%, DISTANCE)
----------------------------------------------------
local function createESPGui()
    if ESPGui then ESPGui:Destroy() end

    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "XSOSBOYS_ESP_Gui"
    ESPGui.ResetOnSpawn = false
    ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ESPGui.IgnoreGuiInset = true
    ESPGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function createPlayerESP(player)
    if not ESPGui or not ESPGui.Parent then createESPGui() end

    local container = Instance.new("Frame")
    container.Name = player.Name .. "_ESP"
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Visible = false
    container.Parent = ESPGui

    -- 2D Bounding Box Outline
    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Size = UDim2.new(1, 0, 1, 0)
    box.Position = UDim2.new(0, 0, 0, 0)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Parent = container

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Name = "BoxStroke"
    boxStroke.Color = Color3.fromRGB(255, 255, 255)
    boxStroke.Thickness = 1.5
    boxStroke.Transparency = 0.1
    boxStroke.Parent = box

    -- Name Label (On top of Box)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0, 240, 0, 18)
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Position = UDim2.new(0.5, 0, 0, -3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.DisplayName or player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 13
    nameLabel.Parent = container

    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = Color3.fromRGB(0, 0, 0)
    nameStroke.Thickness = 1.5
    nameStroke.Parent = nameLabel

    -- Bottom Label (Health % and Distance)
    local bottomLabel = Instance.new("TextLabel")
    bottomLabel.Name = "BottomLabel"
    bottomLabel.Size = UDim2.new(0, 240, 0, 18)
    bottomLabel.AnchorPoint = Vector2.new(0.5, 0)
    bottomLabel.Position = UDim2.new(0.5, 0, 1, 3)
    bottomLabel.BackgroundTransparency = 1
    bottomLabel.Font = Enum.Font.GothamBold
    bottomLabel.RichText = true
    bottomLabel.Text = "<font color='#32CD32'>100%</font> [0m]"
    bottomLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bottomLabel.TextSize = 12
    bottomLabel.Parent = container

    local bottomStroke = Instance.new("UIStroke")
    bottomStroke.Color = Color3.fromRGB(0, 0, 0)
    bottomStroke.Thickness = 1.5
    bottomStroke.Parent = bottomLabel

    return {
        Container = container,
        Box = box,
        BoxStroke = boxStroke,
        NameLabel = nameLabel,
        BottomLabel = bottomLabel,
        Player = player
    }
end

local function updateESP()
    if not Settings.ESPEnabled then
        for _, esp in pairs(ESPObjects) do
            if esp.Container then esp.Container.Visible = false end
        end
        for _, highlight in pairs(ESPHighlights) do
            if highlight and highlight.Parent then highlight:Destroy() end
        end
        ESPHighlights = {}
        return
    end

    if not ESPGui or not ESPGui.Parent then
        createESPGui()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local key = tostring(player.UserId)
            local esp = ESPObjects[key]
            if not esp or not esp.Container or not esp.Container.Parent then
                esp = createPlayerESP(player)
                ESPObjects[key] = esp
            end

            local char = player.Character
            local hum = getHumanoid(player)
            local root = getRootPart(player)

            if char and hum and root and hum.Health > 0 then
                local head = char:FindFirstChild("Head")
                local topWorld = (head and head.Position + Vector3.new(0, 0.7, 0)) or (root.Position + Vector3.new(0, 2.7, 0))
                local bottomWorld = root.Position - Vector3.new(0, 3.0, 0)

                local topScreen, topOnScreen = Camera:WorldToViewportPoint(topWorld)
                local bottomScreen, bottomOnScreen = Camera:WorldToViewportPoint(bottomWorld)

                if topOnScreen or bottomOnScreen then
                    local height = math.abs(bottomScreen.Y - topScreen.Y)
                    local width = math.clamp(height * 0.62, 10, 400)
                    local centerX = (topScreen.X + bottomScreen.X) / 2
                    local topY = math.min(topScreen.Y, bottomScreen.Y)

                    esp.Container.Position = UDim2.new(0, centerX - width / 2, 0, topY)
                    esp.Container.Size = UDim2.new(0, width, 0, height)
                    esp.Container.Visible = true

                    -- Box Visibility
                    esp.Box.Visible = Settings.ESPBoxes

                    -- Name Label Visibility & Text
                    esp.NameLabel.Visible = Settings.ESPNames
                    esp.NameLabel.Text = player.DisplayName or player.Name

                    -- Health & Distance calculation
                    local hpPercent = math.clamp(math.floor((hum.Health / math.max(hum.MaxHealth, 1)) * 100), 0, 100)
                    local hpColorHex = "#32CD32" -- Green
                    if hpPercent < 35 then
                        hpColorHex = "#FF3333" -- Red
                    elseif hpPercent < 70 then
                        hpColorHex = "#FFAA00" -- Orange/Yellow
                    end

                    local distanceStuds = (root.Position - Camera.CFrame.Position).Magnitude
                    local distMeters = math.floor(distanceStuds)

                    local bottomText = ""
                    if Settings.ESPHealth and Settings.ESPDistance then
                        bottomText = string.format("<font color='%s'>%d%%</font> [%dm]", hpColorHex, hpPercent, distMeters)
                    elseif Settings.ESPHealth then
                        bottomText = string.format("<font color='%s'>%d%%</font>", hpColorHex, hpPercent)
                    elseif Settings.ESPDistance then
                        bottomText = string.format("[%dm]", distMeters)
                    end

                    esp.BottomLabel.Visible = (Settings.ESPHealth or Settings.ESPDistance)
                    esp.BottomLabel.Text = bottomText

                    -- Optional Highlight / Chams
                    if Settings.ESPHighlight then
                        local hKey = player.UserId .. "_hl"
                        if not ESPHighlights[hKey] or not ESPHighlights[hKey].Parent then
                            local hl = Instance.new("Highlight")
                            hl.Name = "ESP_Highlight"
                            hl.Adornee = char
                            hl.FillColor = Color3.fromRGB(255, 30, 30)
                            hl.FillTransparency = 0.6
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.OutlineTransparency = 0.1
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hl.Parent = char
                            ESPHighlights[hKey] = hl
                        end
                    else
                        local hKey = player.UserId .. "_hl"
                        if ESPHighlights[hKey] and ESPHighlights[hKey].Parent then
                            ESPHighlights[hKey]:Destroy()
                            ESPHighlights[hKey] = nil
                        end
                    end
                else
                    esp.Container.Visible = false
                end
            else
                esp.Container.Visible = false
            end
        end
    end

    -- Cleanup left players
    for key, esp in pairs(ESPObjects) do
        if not esp.Player or not esp.Player.Parent then
            if esp.Container then esp.Container:Destroy() end
            ESPObjects[key] = nil
        end
    end
end

----------------------------------------------------
-- FLY & MOVEMENT SYSTEM
----------------------------------------------------
local function disableFly()
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
end

local function enableFly()
    local root = getRootPart(LocalPlayer)
    if not root then return end
    disableFly()

    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyBodyVelocity.Parent = root

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    FlyBodyGyro.CFrame = root.CFrame
    FlyBodyGyro.Parent = root
end

local function updateFly()
    if not Settings.FlyEnabled then
        disableFly()
        return
    end

    local root = getRootPart(LocalPlayer)
    if not root then disableFly() return end
    if not FlyBodyVelocity or not FlyBodyVelocity.Parent then enableFly() end

    local moveDir = Vector3.new(0, 0, 0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    if FlyBodyGyro then FlyBodyGyro.CFrame = Camera.CFrame end
    if FlyBodyVelocity then
        FlyBodyVelocity.Velocity = (moveDir.Magnitude > 0) and (moveDir.Unit * Settings.FlySpeed) or Vector3.new(0, 0, 0)
    end
end

----------------------------------------------------
-- PLAYER CLIENT DESYNC (ANTI-LOCK)
----------------------------------------------------
local function updatePlayerDesync()
    if not Settings.DesyncEnabled then return end

    local root = getRootPart(LocalPlayer)
    if not root then return end

    if Settings.DesyncMode == "Velocity" then
        -- Spoofs AssemblyLinearVelocity each tick to break enemy aimbots
        local oldVel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(math.random(-2500, 2500), math.random(-2500, 2500), math.random(-2500, 2500))
        RunService.RenderStepped:Wait()
        if root and root.Parent then root.AssemblyLinearVelocity = oldVel end
    elseif Settings.DesyncMode == "Underground" then
        -- Underground visual offset
        local oldCF = root.CFrame
        root.CFrame = oldCF * CFrame.new(0, -12, 0)
        RunService.RenderStepped:Wait()
        if root and root.Parent then root.CFrame = oldCF end
    elseif Settings.DesyncMode == "FakeLag" then
        -- Jitter lag desync
        if tick() % 0.15 < 0.06 then
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

----------------------------------------------------
-- AIMBOT & TRUE STICKY LOCK SYSTEM
----------------------------------------------------
local function getTargetInFOV()
    local mousePos = UserInputService:GetMouseLocation()
    local fovRadius = Settings.AimFOV

    -- 1. If we already have a locked target while holding Right-Click, STICK TO IT solidly!
    if Settings.StickyLock and IsRightClicking and CurrentTarget and isTargetAlive(CurrentTarget) then
        local char = CurrentTarget:IsA("Model") and CurrentTarget or CurrentTarget.Character
        if char then
            local part = getTargetPart(char)
            if part then
                return CurrentTarget, part
            end
        end
    end

    -- 2. Search for nearest target inside FOV circle
    local bestTarget = nil
    local bestPart = nil
    local shortestDist = fovRadius

    -- Check all other players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isTargetAlive(player) then
            local part = getTargetPart(player.Character)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist <= shortestDist then
                        shortestDist = dist
                        bestTarget = player
                        bestPart = part
                    end
                end
            end
        end
    end

    -- Check NPC / dummy humanoid models in workspace if no player in FOV
    if not bestTarget then
        for _, model in ipairs(workspace:GetChildren()) do
            if model:IsA("Model") and model ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(model) then
                if isTargetAlive(model) then
                    local part = getTargetPart(model)
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist <= shortestDist then
                                shortestDist = dist
                                bestTarget = model
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestPart
end

local function updateAimbot()
    if not Settings.AimBotEnabled then
        CurrentTarget = nil
        CurrentTargetPart = nil
        return
    end

    -- If RightClickToAim is enabled, only attach when Right-Click (RMB) is held down
    if Settings.RightClickToAim and not IsRightClicking then
        CurrentTarget = nil
        CurrentTargetPart = nil
        return
    end

    local target, targetPart = getTargetInFOV()
    if target and targetPart then
        CurrentTarget = target
        CurrentTargetPart = targetPart

        -- Direct target part position (neutralizes desync without flying away)
        local targetPos = targetPart.Position

        -- Optional prediction only if specifically enabled
        if Settings.PredictionEnabled then
            local root = getRootPart(target)
            if root and root:IsA("BasePart") then
                local vel = root.AssemblyLinearVelocity
                if vel.Magnitude < 100 then
                    targetPos = targetPos + (vel * Settings.PredictionAmount)
                end
            end
        end

        local camPos = Camera.CFrame.Position
        local targetCF = CFrame.lookAt(camPos, targetPos)

        if Settings.AimbotMode == "Rage" or Settings.AimbotSmoothness >= 0.95 then
            -- Instant Snap Lock (100% Rigid Attachment)
            Camera.CFrame = targetCF
        else
            -- Magnetic Lerp Attachment (Smoothed but firmly attached)
            local smoothness = math.clamp(Settings.AimbotSmoothness, 0.1, 0.95)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, smoothness)
        end
    else
        CurrentTarget = nil
        CurrentTargetPart = nil
    end
end

----------------------------------------------------
-- BIG HEAD SYSTEM
----------------------------------------------------
local function updateBigHead()
    if not Settings.BigHeadEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                head.Size = Vector3.new(Settings.BigHeadSize, Settings.BigHeadSize, Settings.BigHeadSize)
                head.CanCollide = false
            end
        end
    end
end

----------------------------------------------------
-- INPUT LISTENERS (RIGHT-CLICK LOCK & MENU TOGGLE)
----------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsRightClicking = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        IsRightClicking = false
        CurrentTarget = nil
        CurrentTargetPart = nil
    end
end)

----------------------------------------------------
-- MAIN HACK MENU UI BUILDER
----------------------------------------------------
local function initializeHackMenu()
    createFOVCircle()
    createESPGui()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "XSOSBOYS_HackGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 530, 0, 430)
    mainFrame.Position = UDim2.new(0.5, -265, 0.5, -215)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    makeCorner(mainFrame, 10)
    makeStroke(mainFrame, Color3.fromRGB(255, 40, 40), 2)

    -- Top Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    makeCorner(header, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "XSOSBOYS MENU"
    title.TextColor3 = Color3.fromRGB(255, 60, 60)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.Parent = header
    makeCorner(closeBtn, 6)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    -- Dragging Logic
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Sidebar Nav
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 120, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -130, 1, -50)
    contentFrame.Position = UDim2.new(0, 125, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    local tabFrames = {}
    local tabButtons = {}

    local function createTab(name)
        local f = Instance.new("ScrollingFrame")
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ScrollBarThickness = 4
        f.ScrollBarImageColor3 = Color3.fromRGB(255, 40, 40)
        f.Visible = false
        f.Parent = contentFrame

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = f

        tabFrames[name] = f
        return f
    end

    local tabNames = {"Combat", "Movement", "Visuals", "Settings"}
    for i, tName in ipairs(tabNames) do
        createTab(tName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 104, 0, 32)
        btn.Position = UDim2.new(0, 8, 0, 10 + (i - 1) * 38)
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(28, 28, 28)
        btn.Font = Enum.Font.GothamBold
        btn.Text = tName
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Parent = sidebar
        makeCorner(btn, 6)
        tabButtons[tName] = btn

        btn.MouseButton1Click:Connect(function()
            for _, frame in pairs(tabFrames) do frame.Visible = false end
            for _, b in pairs(tabButtons) do b.BackgroundColor3 = Color3.fromRGB(28, 28, 28) end
            tabFrames[tName].Visible = true
            btn.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
        end)
    end
    tabFrames["Combat"].Visible = true

    -- UI Builders
    local function addToggle(parentTab, text, state, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 34)
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 140, 40) or Color3.fromRGB(30, 30, 30)
        btn.Font = Enum.Font.GothamBold
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Parent = tabFrames[parentTab]
        makeCorner(btn, 6)
        local stroke = makeStroke(btn, state and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(60, 60, 60), 1)

        btn.MouseButton1Click:Connect(function()
            local newState = callback()
            btn.Text = text .. ": " .. (newState and "ON" or "OFF")
            btn.BackgroundColor3 = newState and Color3.fromRGB(40, 140, 40) or Color3.fromRGB(30, 30, 30)
            stroke.Color = newState and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(60, 60, 60)
        end)
    end

    local function addModeSelector(parentTab, text, defaultMode, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 34)
        btn.BackgroundColor3 = (defaultMode == "Rage") and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(40, 100, 180)
        btn.Font = Enum.Font.GothamBold
        btn.Text = text .. ": " .. tostring(defaultMode):upper()
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Parent = tabFrames[parentTab]
        makeCorner(btn, 6)
        makeStroke(btn, Color3.fromRGB(100, 100, 255), 1)

        btn.MouseButton1Click:Connect(function()
            local newMode = callback()
            btn.Text = text .. ": " .. tostring(newMode):upper()
            btn.BackgroundColor3 = (newMode == "Rage") and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(40, 100, 180)
        end)
    end

    local function addSlider(parentTab, text, min, max, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 45)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.Parent = tabFrames[parentTab]
        makeCorner(frame, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 18)
        lbl.Position = UDim2.new(0, 8, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text .. ": " .. defaultVal
        lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -16, 0, 8)
        bar.Position = UDim2.new(0, 8, 0, 26)
        bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        bar.Parent = frame
        makeCorner(bar, 4)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((defaultVal - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        fill.Parent = bar
        makeCorner(fill, 4)

        local draggingSlider = false
        local function updateVal(inputX)
            local rel = math.clamp((inputX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = text .. ": " .. val
            callback(val)
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = true updateVal(input.Position.X) end
        end)
        bar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then updateVal(input.Position.X) end
        end)
    end

    -- --- POPULATE TABS ---
    -- Combat Tab
    addToggle("Combat", "Aimbot Master", Settings.AimBotEnabled, function()
        Settings.AimBotEnabled = not Settings.AimBotEnabled
        return Settings.AimBotEnabled
    end)
    addToggle("Combat", "Hold Right-Click to Lock", Settings.RightClickToAim, function()
        Settings.RightClickToAim = not Settings.RightClickToAim
        return Settings.RightClickToAim
    end)
    addToggle("Combat", "Sticky Retention (No Drop)", Settings.StickyLock, function()
        Settings.StickyLock = not Settings.StickyLock
        return Settings.StickyLock
    end)
    addModeSelector("Combat", "Aimbot Mode", Settings.AimbotMode, function()
        Settings.AimbotMode = (Settings.AimbotMode == "Smooth") and "Rage" or "Smooth"
        return Settings.AimbotMode
    end)
    addModeSelector("Combat", "Target Part", Settings.TargetPart, function()
        Settings.TargetPart = (Settings.TargetPart == "Head") and "Torso" or "Head"
        return Settings.TargetPart
    end)
    addToggle("Combat", "Show FOV Circle & Number", Settings.ShowFOVCircle, function()
        Settings.ShowFOVCircle = not Settings.ShowFOVCircle
        return Settings.ShowFOVCircle
    end)
    addSlider("Combat", "Aimbot FOV Size", 10, 250, Settings.AimFOV, function(v) Settings.AimFOV = v end)
    addSlider("Combat", "Aimbot Stickiness %", 10, 100, math.floor(Settings.AimbotSmoothness * 100), function(v) Settings.AimbotSmoothness = v / 100 end)
    addSlider("Combat", "Fling Power", 10, 300, Settings.FlingPower, function(v) Settings.FlingPower = v end)

    -- Movement Tab (FastWalk, Fly, Desync Anti-Lock)
    addToggle("Movement", "Fast Walk", Settings.FastWalkEnabled, function()
        Settings.FastWalkEnabled = not Settings.FastWalkEnabled
        local h = getHumanoid(LocalPlayer)
        if h then h.WalkSpeed = Settings.FastWalkEnabled and Settings.WalkSpeed or 16 end
        return Settings.FastWalkEnabled
    end)
    addToggle("Movement", "Fly", Settings.FlyEnabled, function()
        Settings.FlyEnabled = not Settings.FlyEnabled
        if not Settings.FlyEnabled then disableFly() end
        return Settings.FlyEnabled
    end)
    addToggle("Movement", "Anti-Lock Client Desync", Settings.DesyncEnabled, function()
        Settings.DesyncEnabled = not Settings.DesyncEnabled
        return Settings.DesyncEnabled
    end)
    addModeSelector("Movement", "Desync Mode", Settings.DesyncMode, function()
        if Settings.DesyncMode == "Velocity" then
            Settings.DesyncMode = "Underground"
        elseif Settings.DesyncMode == "Underground" then
            Settings.DesyncMode = "FakeLag"
        else
            Settings.DesyncMode = "Velocity"
        end
        return Settings.DesyncMode
    end)
    addSlider("Movement", "Walk Speed", 16, 200, Settings.WalkSpeed, function(v)
        Settings.WalkSpeed = v
        local h = getHumanoid(LocalPlayer)
        if h and Settings.FastWalkEnabled then h.WalkSpeed = v end
    end)
    addSlider("Movement", "Fly Speed", 10, 150, Settings.FlySpeed, function(v) Settings.FlySpeed = v end)

    -- Visuals Tab (2D Box ESP, Names, HP%, Distance)
    addToggle("Visuals", "Player ESP Master", Settings.ESPEnabled, function()
        Settings.ESPEnabled = not Settings.ESPEnabled
        updateESP()
        return Settings.ESPEnabled
    end)
    addToggle("Visuals", "ESP 2D Box", Settings.ESPBoxes, function()
        Settings.ESPBoxes = not Settings.ESPBoxes
        return Settings.ESPBoxes
    end)
    addToggle("Visuals", "ESP Player Name", Settings.ESPNames, function()
        Settings.ESPNames = not Settings.ESPNames
        return Settings.ESPNames
    end)
    addToggle("Visuals", "ESP Health %", Settings.ESPHealth, function()
        Settings.ESPHealth = not Settings.ESPHealth
        return Settings.ESPHealth
    end)
    addToggle("Visuals", "ESP Distance", Settings.ESPDistance, function()
        Settings.ESPDistance = not Settings.ESPDistance
        return Settings.ESPDistance
    end)
    addToggle("Visuals", "Big Head Target", Settings.BigHeadEnabled, function()
        Settings.BigHeadEnabled = not Settings.BigHeadEnabled
        return Settings.BigHeadEnabled
    end)
    addSlider("Visuals", "Head Scale Size", 1, 10, Settings.BigHeadSize, function(v) Settings.BigHeadSize = v end)

    -- Settings Tab
    addToggle("Settings", "Menu Keybind Toggle [F6 / RCtrl]", true, function() return true end)

    -- Keybind listener for Menu Open/Close
    UserInputService.InputBegan:Connect(function(input, gProc)
        if not gProc and (input.KeyCode == Enum.KeyCode.F6 or input.KeyCode == Enum.KeyCode.RightControl) then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)

    -- Heartbeat Loop for Player Desync
    RunService.Heartbeat:Connect(function()
        if Settings.DesyncEnabled then
            updatePlayerDesync()
        end
    end)

    -- Main Render Loop
    RunService.RenderStepped:Connect(function()
        updateFly()
        updateAimbot()
        updateFOVCirclePosition()
        updateESP()
        if Settings.BigHeadEnabled then updateBigHead() end
    end)
end

----------------------------------------------------
-- PASSWORD PROMPT GUI
----------------------------------------------------
local function showPasswordPrompt()
    local gui = Instance.new("ScreenGui")
    gui.Name = "XSOSBOYS_Auth"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 300, 0, 160)
    card.Position = UDim2.new(0.5, -150, 0.5, -80)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    card.Parent = gui
    makeCorner(card, 8)
    makeStroke(card, Color3.fromRGB(255, 40, 40), 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 30)
    lbl.Position = UDim2.new(0, 0, 0, 15)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "XSOSBOYS AUTH"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 16
    lbl.Parent = card

    local txtBox = Instance.new("TextBox")
    txtBox.Size = UDim2.new(1, -30, 0, 32)
    txtBox.Position = UDim2.new(0, 15, 0, 55)
    txtBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    txtBox.Font = Enum.Font.Gotham
    txtBox.PlaceholderText = "Enter password..."
    txtBox.Text = ""
    txtBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    txtBox.TextSize = 14
    txtBox.Parent = card
    makeCorner(txtBox, 6)
    makeStroke(txtBox, Color3.fromRGB(60, 60, 60), 1)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, 32)
    btn.Position = UDim2.new(0, 15, 0, 102)
    btn.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "UNLOCK MENU"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Parent = card
    makeCorner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        if txtBox.Text == PASSWORD then
            gui:Destroy()
            initializeHackMenu()
        else
            txtBox.Text = ""
            txtBox.PlaceholderText = "Incorrect password!"
        end
    end)
end

showPasswordPrompt()
