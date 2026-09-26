-- Gun Features
-- Controller+
-- Water Proof
-- Disable Trade
-- Client Sided Message
-- Estimated Server Pos
-- Auto Perk
-- Tool Tint

local table_insert = table.insert
local nicolas = {}
nicolas.__index = nicolas
function nicolas.new()
    return setmetatable({_tasks = {}, _destroyed = false}, nicolas)
end
function nicolas:GiveTask(task)
    if self._destroyed then
        self:_cleanupTask(task)
        return
    end
    table_insert(self._tasks, task)
    return task
end
function nicolas:GiveTasks(...)
    for _, task in ipairs({...}) do
        self:GiveTask(task)
    end
end
function nicolas:_cleanupTask(task)
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
        task:Disconnect()
    elseif taskType == "Instance" then
        task:Destroy()
    elseif taskType == "function" then
        task()
    elseif taskType == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end
function nicolas:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in ipairs(self._tasks) do
        self:_cleanupTask(task)
    end
    self._tasks = {}
end
function nicolas:Destroy()
    self:DoCleaning()
end

local RootNicolas = nicolas.new()
local shared = odh_shared_plugins

local myTab = shared.CreateTab("tuff stuff", "/nonchalantnicolas/drowsynicolas-ODH-icon/refs/heads/main/IMG_5786")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local SpectateService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SpectateService"))

local BLOCKED = {
    ["123606547020560"] = true,
    ["134826825394657"] = true,
    ["124281955370937"] = true,
    ["127786188145385"] = true,
}
local SOUND_ID = "rbxassetid://7158356564"
local START_OFFSET = 0.3

local gunFeatures = {
    blockAnims = false,
    equipSound = false,
    forceField = false,
    fireColor = false,
}
local charData = {}
local currentSounds = {}

local forceFieldConnection = nil
local forceFieldColor = Color3.fromRGB(0, 100, 255)
local forceFieldSize = 3.5
local forceFieldTransparency = 0.3
local FORCE_FIELD_NAME = "\u{200B}\u{200B}\u{200B}"

local fireColorConnection = nil
local customFireColor = Color3.fromRGB(0, 100, 255)
local DEFAULT_FIRE_COLOR = Color3.fromRGB(1, 76, 0)
local DEFAULT_FIRE_SECONDARY = Color3.fromRGB(0, 0, 0)

local function cleanCharacter(character)
    local data = charData[character]
    if data then
        if data.animNicolas then
            data.animNicolas:DoCleaning()
            data.animNicolas = nicolas.new()
        end
        if data.equipNicolas then
            data.equipNicolas:DoCleaning()
            data.equipNicolas = nicolas.new()
        end
        charData[character] = nil
    end
    local sound = currentSounds[character]
    if sound then
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end

local function playSound(character, soundId)
    local existing = currentSounds[character]
    if existing then
        existing:Stop()
        existing:Destroy()
        currentSounds[character] = nil
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 1
    sound.Parent = hrp
    sound.TimePosition = START_OFFSET
    sound:Play()
    currentSounds[character] = sound
    sound.Ended:Once(function()
        if currentSounds[character] == sound then
            currentSounds[character] = nil
        end
        sound:Destroy()
    end)
end

local function hookTool(tool, character, nicolasObj)
    if tool.Name ~= "Gun" then return end
    local equipConn = tool.Equipped:Connect(function()
        if gunFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(equipConn)
    local unequipConn = tool.Unequipped:Connect(function()
        if gunFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(unequipConn)
    return equipConn, unequipConn
end

local function applyGunFeatures(character)
    local data = charData[character]
    if not data then
        data = {
            animNicolas = nicolas.new(),
            equipNicolas = nicolas.new(),
        }
        charData[character] = data
        data.animNicolas:GiveTask(character.AncestryChanged:Connect(function()
            if not character.Parent then
                cleanCharacter(character)
            end
        end))
    end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    if gunFeatures.blockAnims then
        data.animNicolas:GiveTask(RunService.RenderStepped:Connect(function()
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                local anim = track.Animation
                if anim then
                    local id = anim.AnimationId:match("%d+")
                    if BLOCKED[id] then
                        track:Stop(0)
                    end
                end
            end
        end))
    end
    if gunFeatures.equipSound then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") then
                hookTool(child, character, data.equipNicolas)
            end
        end
        data.equipNicolas:GiveTask(character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                hookTool(child, character, data.equipNicolas)
            end
        end))
    end
end

local function onCharacterAdded(character)
    character:WaitForChild("Humanoid")
    if gunFeatures.blockAnims or gunFeatures.equipSound then
        applyGunFeatures(character)
    end
end

local animBlockGlobalNicolas = nicolas.new()
local equipSoundGlobalNicolas = nicolas.new()

local function enableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    animBlockGlobalNicolas = nicolas.new()
    if LocalPlayer.Character then
        applyGunFeatures(LocalPlayer.Character)
    end
    animBlockGlobalNicolas:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
        onCharacterAdded(character)
    end))
end

local function disableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    for _, data in pairs(charData) do
        if data.animNicolas then
            data.animNicolas:DoCleaning()
            data.animNicolas = nicolas.new()
        end
    end
end

local function enableEquipSound()
    equipSoundGlobalNicolas:DoCleaning()
    equipSoundGlobalNicolas = nicolas.new()
    if LocalPlayer.Character then
        applyGunFeatures(LocalPlayer.Character)
    end
    equipSoundGlobalNicolas:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
        onCharacterAdded(character)
    end))
end

local function disableEquipSound()
    equipSoundGlobalNicolas:DoCleaning()
    for _, data in pairs(charData) do
        if data.equipNicolas then
            data.equipNicolas:DoCleaning()
            data.equipNicolas = nicolas.new()
        end
    end
    for character, sound in pairs(currentSounds) do
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end

local function applyForceField(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    if gunDrop:FindFirstChild(FORCE_FIELD_NAME) then return end

    local sphere = Instance.new("Part")
    sphere.Name = FORCE_FIELD_NAME
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(forceFieldSize, forceFieldSize, forceFieldSize)
    sphere.Color = forceFieldColor
    sphere.Material = Enum.Material.ForceField
    sphere.Transparency = forceFieldTransparency
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.CanTouch = false
    sphere.CanQuery = false
    sphere.CastShadow = false
    sphere.Massless = true
    sphere.CFrame = gunDrop.CFrame
    sphere.Parent = gunDrop
end

local function enableForceField()
    if forceFieldConnection then
        forceFieldConnection:Disconnect()
        forceFieldConnection = nil
    end

    forceFieldConnection = workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            task.wait()
            applyForceField(obj)
        end
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            applyForceField(obj)
        end
    end
end

local function disableForceField()
    if forceFieldConnection then
        forceFieldConnection:Disconnect()
        forceFieldConnection = nil
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local sphere = obj:FindFirstChild(FORCE_FIELD_NAME)
            if sphere then
                sphere:Destroy()
            end
        end
    end
end

local function applyFireColor(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    local fire = gunDrop:FindFirstChild("Fire")
    if fire and fire:IsA("Fire") then
        fire.Color = customFireColor
        fire.SecondaryColor = customFireColor
    end
end

local function resetFireColor(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    local fire = gunDrop:FindFirstChild("Fire")
    if fire and fire:IsA("Fire") then
        fire.Color = DEFAULT_FIRE_COLOR
        fire.SecondaryColor = DEFAULT_FIRE_SECONDARY
    end
end

local function enableFireColor()
    if fireColorConnection then
        fireColorConnection:Disconnect()
        fireColorConnection = nil
    end

    fireColorConnection = workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            task.wait()
            applyFireColor(obj)
        end
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            applyFireColor(obj)
        end
    end
end

local function disableFireColor()
    if fireColorConnection then
        fireColorConnection:Disconnect()
        fireColorConnection = nil
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            resetFireColor(obj)
        end
    end
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

local gunFeaturesSection = myTab:AddSection("Gun Features", "Gun Stuff")
gunFeaturesSection:AddParagraph("Additional Info", "This plugin works for both MM2 and MMV\n\nCredits: @drowsynicolas")
gunFeaturesSection:AddToggle("Disable Gun Animations", function(bool)
    gunFeatures.blockAnims = bool
    if bool then
        enableBlockAnims()
    else
        disableBlockAnims()
    end
end)
gunFeaturesSection:AddToggle("Equip/Unequip Gun Sound", function(bool)
    gunFeatures.equipSound = bool
    if bool then
        enableEquipSound()
    else
        disableEquipSound()
    end
end)
gunFeaturesSection:AddToggle("Gun Force Field", function(bool)
    gunFeatures.forceField = bool
    if bool then
        enableForceField()
    else
        disableForceField()
    end
end)
gunFeaturesSection:AddToggle("Custom Dropped Gun Fire Color", function(bool)
    gunFeatures.fireColor = bool
    if bool then
        enableFireColor()
    else
        disableFireColor()
    end
end)
gunFeaturesSection:AddColorpicker("Force Field Color", Color3.fromRGB(0, 100, 255), function(color)
    forceFieldColor = color

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local sphere = obj:FindFirstChild(FORCE_FIELD_NAME)
            if sphere then
                sphere.Color = color
            end
        end
    end
end)
gunFeaturesSection:AddColorpicker("Dropped Gun Fire Color", Color3.fromRGB(0, 100, 255), function(color)
    customFireColor = color

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local fire = obj:FindFirstChild("Fire")
            if fire and fire:IsA("Fire") then
                fire.Color = color
                fire.SecondaryColor = color
            end
        end
    end
end)

local controllerFeatures = {
    fixScoreboard = false,
    perkEnabled = false,
    shiftLockEnabled = false,
    spectateKeybinds = false,
}
local scoreboardMaid = nil
local spectateMaid = nil

local function toggleShiftLock()
    local mouseLock = LocalPlayer.PlayerScripts:FindFirstChild("MouseLock")
    if not mouseLock then
        return
    end
    local enabled = mouseLock:GetAttribute("Enabled")
    mouseLock:Invoke(not enabled)
end

local function shiftLockKeybind()
    if controllerFeatures.shiftLockEnabled then
        toggleShiftLock()
    end
end

local function activatePerk()
    local character = LocalPlayer.Character
    if not character then return end
    local trap = character:FindFirstChild("Trap")
    if trap then
        local activate = trap:FindFirstChild("Activate")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if activate and hrp then
            activate:FireServer(hrp.CFrame)
            return
        end
    end
    for _, perk in ipairs(character:GetChildren()) do
        local activate = perk:FindFirstChild("Activate")
        if activate then
            activate:FireServer()
            break
        end
    end
end

local function perkKeybind()
    if controllerFeatures.perkEnabled then
        activatePerk()
    end
end

local function enableFixScoreboard()
    if scoreboardMaid then
        scoreboardMaid:DoCleaning()
        scoreboardMaid = nil
    end
    scoreboardMaid = nicolas.new()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local conn = pg.ChildAdded:Connect(function(child)
        if child.Name:lower():find("scoreboard") then
            task.wait()
            child:Destroy()
        end
    end)
    scoreboardMaid:GiveTask(conn)
    for _, v in pairs(pg:GetChildren()) do
        if v.Name:lower():find("scoreboard") then
            v:Destroy()
        end
    end
end

local function disableFixScoreboard()
    if scoreboardMaid then
        scoreboardMaid:DoCleaning()
        scoreboardMaid = nil
    end
end

local function setupSpectateUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local backpackUI = playerGui:FindFirstChild("BackpackUI")
    local backpackContext = playerGui:FindFirstChild("InputContext") and playerGui.InputContext:FindFirstChild("BackpackContext")
    return backpackUI, backpackContext
end

local function enableSpectateUI()
    if spectateMaid then
        spectateMaid:DoCleaning()
        spectateMaid = nil
    end
    spectateMaid = nicolas.new()
    local backpackUI, backpackContext = setupSpectateUI()
    local charConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        local newUI, newContext = setupSpectateUI()
        backpackUI = newUI
        backpackContext = newContext
    end)
    spectateMaid:GiveTask(charConn)
    local renderConn = RunService.RenderStepped:Connect(function()
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not backpackUI or not backpackContext then
            return
        end
        local camera = workspace.CurrentCamera
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        local disabled = distance >= 150
        backpackUI.Enabled = not disabled
        backpackContext.Enabled = not disabled
    end)
    spectateMaid:GiveTask(renderConn)
end

local function disableSpectateUI()
    if spectateMaid then
        spectateMaid:DoCleaning()
        spectateMaid = nil
    end
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local backpackUI = playerGui:FindFirstChild("BackpackUI")
        local backpackContext = playerGui:FindFirstChild("InputContext") and playerGui.InputContext:FindFirstChild("BackpackContext")
        if backpackUI then
            backpackUI.Enabled = true
        end
        if backpackContext then
            backpackContext.Enabled = true
        end
    end
end

local controllerSection = myTab:AddSection("Controller+", "Mobile Controller Support")
controllerSection:AddParagraph("Additional Info", "Gives you a better mobile controller experience.\n\nCredits: @drowsynicolas")
controllerSection:AddToggle("Fix Scoreboard Bug", function(bool)
    controllerFeatures.fixScoreboard = bool
    if bool then
        enableFixScoreboard()
    else
        disableFixScoreboard()
    end
end)
controllerSection:AddToggle("Enable Perk", function(bool)
    controllerFeatures.perkEnabled = bool
end)
controllerSection:AddToggle("Enable Shift Lock", function(bool)
    controllerFeatures.shiftLockEnabled = bool
end)
controllerSection:AddToggle("Enable Spectate Keybinds", function(bool)
    controllerFeatures.spectateKeybinds = bool
    if bool then
        enableSpectateUI()
    else
        disableSpectateUI()
    end
end)
controllerSection:AddKeybind("Perk Keybind", "ButtonX", function()
    perkKeybind()
end)
controllerSection:AddKeybind("Shift Lock", "ButtonL3", function()
    shiftLockKeybind()
end)
controllerSection:AddKeybind("Spectate Next", "ButtonR1", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:NavigateSpectate(1)
    end
end)
controllerSection:AddKeybind("Spectate Previous", "ButtonL1", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:NavigateSpectate(-1)
    end
end)
controllerSection:AddKeybind("Toggle Spectate", "ButtonR3", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:ToggleSpectate()
    end
end)

local waterFeatures = {
    waterImmunity = false,
}
local waterMaid = nil
local modifiedParts = {}
local waterPartConnections = {}

local function DisableWaterPart(part)
    if part and part:IsA("BasePart") then
        if not modifiedParts[part] then
            modifiedParts[part] = {
                CanTouch = part.CanTouch,
                CanCollide = part.CanCollide,
            }
        end
        part.CanTouch = false
        part.CanCollide = false
    end
end

local function RestoreAllParts()
    for part, originalStates in pairs(modifiedParts) do
        if part and part.Parent then
            part.CanTouch = originalStates.CanTouch
            part.CanCollide = originalStates.CanCollide
        end
    end
    modifiedParts = {}
end

local function GetWaterPart()
    local yacht = Workspace:FindFirstChild("Yacht")
    if yacht then
        local intereactive = yacht:FindFirstChild("Intereactive")
        if intereactive then
            local water = intereactive:FindFirstChild("Water")
            if water then
                return water:FindFirstChild("WaterPart")
            end
        end
    end
    local pier = Workspace:FindFirstChild("Pier")
    if pier then
        return pier:FindFirstChild("Respawn")
    end
    return nil
end

local function MonitorWaterPart(part)
    if not part or not waterFeatures.waterImmunity then return end
    DisableWaterPart(part)
    if not waterPartConnections[part] then
        waterPartConnections[part] = part.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                DisableWaterPart(child)
            end
        end)
        if waterMaid then
            waterMaid:GiveTask(waterPartConnections[part])
        end
    end
end

local function CheckWaterPart()
    if not waterFeatures.waterImmunity then return end
    local part = GetWaterPart()
    if part then
        MonitorWaterPart(part)
    end
end

local function enableWaterImmunity()
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    waterFeatures.waterImmunity = true
    waterMaid = nicolas.new()
    waterPartConnections = {}
    CheckWaterPart()
end

local function disableWaterImmunity()
    waterFeatures.waterImmunity = false
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    for _, conn in pairs(waterPartConnections) do
        conn:Disconnect()
    end
    waterPartConnections = {}
    RestoreAllParts()
end

local waterSection = myTab:AddSection("Water Proof", "Water Immunity")
waterSection:AddParagraph("Additional Info", "Makes you immune to water\n\nCredits: @drowsynicolas")
waterSection:AddToggle("Water Immunity", function(bool)
    if bool then
        enableWaterImmunity()
    else
        disableWaterImmunity()
    end
end)

local antiTradeMaid = nil

local function destroyTrade()
    local trade = ReplicatedStorage:FindFirstChild("Trade")
    if trade then
        trade:Destroy()
    end
end

local function enableAntiTrade()
    if antiTradeMaid then
        antiTradeMaid:DoCleaning()
        antiTradeMaid = nil
    end
    antiTradeMaid = nicolas.new()
    destroyTrade()
    antiTradeMaid:GiveTask(ReplicatedStorage.ChildAdded:Connect(function(child)
        if child.Name == "Trade" then
            child:Destroy()
        end
    end))
    antiTradeMaid:GiveTask(RunService.Heartbeat:Connect(function()
        destroyTrade()
    end))
end

local function disableAntiTrade()
    if antiTradeMaid then
        antiTradeMaid:DoCleaning()
        antiTradeMaid = nil
    end
end

local tradeSection = myTab:AddSection("Disable Trade", "fucks the trade system")
tradeSection:AddParagraph("Additional Info", "Destroys the system trade relies on\n\nCredits: @drowsynicolas")
tradeSection:AddToggle("Disable Trade", function(bool)
    if bool then
        enableAntiTrade()
    else
        disableAntiTrade()
    end
end)

local messageSection = myTab:AddSection("Client Sided Message", "just for fun")
messageSection:AddParagraph("Additional Info", "sends a message client sided, u can say anything it'll go through\n\nCredits: @drowsynicolas")
local messageText = ""
messageSection:AddTextBox("Your message", function(text)
    messageText = text
end)
messageSection:AddButton("Send Message", function()
    if messageText == "" then return end
    local character = LocalPlayer.Character
    if not character then return end
    game:GetService("Chat"):Chat(character, messageText, Enum.ChatColor.White)
end)

local serverPosSection = myTab:AddSection("Estimated Server Pos", "shows your server pos")
serverPosSection:AddParagraph("Additional Info", "creates a marker where the server thinks you are based on your ping\n\nCredits: @drowsynicolas")

local serverPosEnabled = false
local serverPosMarker = nil
local serverPosRoot = nil
local serverPosHumanoid = nil
local serverPosConnection = nil
local serverPosHealthConnection = nil
local serverPosCharAddedConn = nil
local serverPosHistory = {}
local serverPosColor = Color3.new(1, 1, 1)

local function destroyServerPosMarker()
    if serverPosConnection then
        serverPosConnection:Disconnect()
        serverPosConnection = nil
    end
    if serverPosHealthConnection then
        serverPosHealthConnection:Disconnect()
        serverPosHealthConnection = nil
    end
    if serverPosMarker then
        serverPosMarker:Destroy()
        serverPosMarker = nil
    end
    serverPosHistory = {}
end

local function getServerPosPing()
    local success, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and math.clamp(value, 10, 1000) or 10
end

local function createServerPosMarker(character)
    destroyServerPosMarker()

    serverPosRoot = character:WaitForChild("HumanoidRootPart")
    serverPosHumanoid = character:WaitForChild("Humanoid")

    serverPosMarker = Instance.new("Part")
    serverPosMarker.Name = "ServerPosition"
    serverPosMarker.Size = Vector3.new(2, 2, 1)
    serverPosMarker.Color = serverPosColor
    serverPosMarker.Material = Enum.Material.Plastic
    serverPosMarker.Transparency = 0.5
    serverPosMarker.Anchored = true
    serverPosMarker.CanCollide = false
    serverPosMarker.CanTouch = false
    serverPosMarker.CanQuery = false
    serverPosMarker.CastShadow = false
    serverPosMarker.Parent = workspace

    serverPosHealthConnection = serverPosHumanoid.HealthChanged:Connect(function(health)
        if health <= 0 then
            destroyServerPosMarker()
        end
    end)

    serverPosConnection = RunService.Heartbeat:Connect(function()
        if not serverPosMarker or not serverPosMarker.Parent then return end
        if not serverPosRoot or not serverPosRoot.Parent then return end

        table.insert(serverPosHistory, {
            position = serverPosRoot.Position,
            rotation = serverPosRoot.CFrame - serverPosRoot.Position,
            time = tick()
        })

        while #serverPosHistory > 120 do
            table.remove(serverPosHistory, 1)
        end

        local target = tick() - getServerPosPing() / 1000
        local closest = serverPosHistory[1]

        for _, entry in ipairs(serverPosHistory) do
            if math.abs(entry.time - target) < math.abs(closest.time - target) then
                closest = entry
            end
        end

        serverPosMarker.CFrame = CFrame.new(closest.position) * closest.rotation
    end)
end

local function enableServerPos()
    serverPosEnabled = true
    if not serverPosCharAddedConn then
        serverPosCharAddedConn = LocalPlayer.CharacterAdded:Connect(function(character)
            task.wait()
            if serverPosEnabled then
                createServerPosMarker(character)
            end
        end)
    end
    if LocalPlayer.Character then
        createServerPosMarker(LocalPlayer.Character)
    end
end

local function disableServerPos()
    serverPosEnabled = false
    if serverPosCharAddedConn then
        serverPosCharAddedConn:Disconnect()
        serverPosCharAddedConn = nil
    end
    destroyServerPosMarker()
end

serverPosSection:AddToggle("Show Server Pos", function(bool)
    if bool then
        enableServerPos()
    else
        disableServerPos()
    end
end)

serverPosSection:AddColorpicker("Marker Color", Color3.fromRGB(255, 255, 255), function(color)
    serverPosColor = color
    if serverPosMarker then
        serverPosMarker.Color = color
    end
end)

local autoPerkSection = myTab:AddSection("Auto Perk", "automatically equips perks")
autoPerkSection:AddParagraph("Additional Info", "equips the perk you picked for the current map when the map loads\n\nthe UI for the equipped perk doesn't change with this but this plugin works\n\nCredits: @drowsynicolas")

local autoPerkEnabled = false
local autoPerkMapConn = nil

local VALID_PERKS = {
    "Footsteps",
    "Xray",
    "Trap",
    "Sprint",
    "Sleight",
    "Ninja",
    "Haste",
    "Ghost",
    "FakeGun",
    "Decoy",
}

local MAP_LIST = {
    {name = "House 2", keyword = "House2"},
    {name = "Factory", keyword = "Factory"},
    {name = "Milbase", keyword = "MilBase"},
    {name = "Workplace", keyword = "Workplace"},
    {name = "Mansion 2", keyword = "Mansion2"},
    {name = "Research Facility", keyword = "ResearchFacility"},
    {name = "Police Station", keyword = "PoliceStation"},
    {name = "Bio Lab", keyword = "BioLab"},
    {name = "Bank 2", keyword = "Bank2"},
    {name = "Office 2014", keyword = "Office2014"},
    {name = "Hospital 2014", keyword = "Hospital2014"},
    {name = "Hotel 2014", keyword = "Hotel2014"},
}

local autoPerkChoices = {}

local function normalizePerk(text)
    if not text or text == "" then return nil end
    local cleaned = text:gsub("%s+", ""):lower()
    for _, perk in ipairs(VALID_PERKS) do
        if perk:lower() == cleaned then
            return perk
        end
    end
    return nil
end

local function getPerkEquipRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local inventory = remotes:FindFirstChild("Inventory")
    if not inventory then return nil end
    return inventory:FindFirstChild("Equip")
end

local function equipPerk(perkName)
    if not perkName then return end
    if LocalPlayer:GetAttribute("EquippedPerk") == perkName then return end
    local remote = getPerkEquipRemote()
    if remote then
        remote:FireServer(perkName, "Perks")
    end
end

local function getCurrentMap()
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            for _, entry in ipairs(MAP_LIST) do
                if child.Name == entry.keyword then
                    return entry.keyword
                end
            end
        end
    end
    return nil
end

local function isMapName(name)
    for _, entry in ipairs(MAP_LIST) do
        if entry.keyword == name then
            return true
        end
    end
    return false
end

local function tryAutoEquip()
    if not autoPerkEnabled then return end
    local mapKeyword = getCurrentMap()
    if not mapKeyword then return end
    local perk = autoPerkChoices[mapKeyword]
    if not perk then return end
    equipPerk(perk)
end

local function startAutoPerk()
    if autoPerkMapConn then
        autoPerkMapConn:Disconnect()
        autoPerkMapConn = nil
    end

    autoPerkMapConn = workspace.ChildAdded:Connect(function(child)
        if not child:IsA("Model") and not child:IsA("Folder") then return end
        if not isMapName(child.Name) then return end
        task.wait(0.5)
        tryAutoEquip()
    end)

    task.spawn(function()
        tryAutoEquip()
    end)
end

local function stopAutoPerk()
    if autoPerkMapConn then
        autoPerkMapConn:Disconnect()
        autoPerkMapConn = nil
    end
end

autoPerkSection:AddToggle("Auto Perk", function(bool)
    autoPerkEnabled = bool
    if bool then
        startAutoPerk()
    else
        stopAutoPerk()
    end
end)

autoPerkSection:AddParagraph("Valid Perks", "Type the perk name for each map. Valid inputs: Footsteps, Xray, Trap, Sprint, Sleight, Ninja, Haste, Ghost, FakeGun, Decoy")

for _, mapEntry in ipairs(MAP_LIST) do
    autoPerkSection:AddTextBox(mapEntry.name, function(text)
        if text == "" then return end
        local perk = normalizePerk(text)
        if perk then
            autoPerkChoices[mapEntry.keyword] = perk
            shared.Notify("Auto Perk: \"" .. perk .. "\" selected for " .. mapEntry.name, 3)
            if autoPerkEnabled then
                tryAutoEquip()
            end
        else
            autoPerkChoices[mapEntry.keyword] = "Footsteps"
            shared.Notify("Auto Perk: invalid input, fallback to Footsteps", 3)
            if autoPerkEnabled then
                tryAutoEquip()
            end
        end
    end)
end

local itemTintSection = myTab:AddSection("Tool Tint", "cosmetic")
itemTintSection:AddParagraph("Additional Info", "tints any tool you hold\n\nCredits: @drowsynicolas")

local toolTintEnabled = false
local toolTintColor = Color3.fromRGB(255, 255, 255)
local toolTintTransparency = 0.5
local toolTintCharacterConnection = nil
local toolTintChildConnection = nil

local function applyToolTint(tool)
    if not tool:IsA("Tool") then return end

    local highlight = tool:FindFirstChild("ToolTint")

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "ToolTint"
        highlight.OutlineTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Adornee = tool
        highlight.Parent = tool
    end

    highlight.FillColor = toolTintColor
    highlight.FillTransparency = toolTintTransparency
end

local function removeToolTint(tool)
    if not tool:IsA("Tool") then return end
    local highlight = tool:FindFirstChild("ToolTint")
    if highlight then
        highlight:Destroy()
    end
end

local function monitorToolTintCharacter(character)
    for _, object in ipairs(character:GetChildren()) do
        applyToolTint(object)
    end

    if toolTintChildConnection then
        toolTintChildConnection:Disconnect()
    end

    toolTintChildConnection = character.ChildAdded:Connect(function(object)
        if toolTintEnabled then
            applyToolTint(object)
        end
    end)
end

local function clearAllToolTints()
    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            removeToolTint(object)
        end
    end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, object in ipairs(backpack:GetChildren()) do
            removeToolTint(object)
        end
    end
end

local function enableToolTint()
    toolTintEnabled = true

    if toolTintCharacterConnection then
        toolTintCharacterConnection:Disconnect()
    end

    toolTintCharacterConnection = LocalPlayer.CharacterAdded:Connect(monitorToolTintCharacter)

    if LocalPlayer.Character then
        monitorToolTintCharacter(LocalPlayer.Character)
    end
end

local function disableToolTint()
    toolTintEnabled = false

    if toolTintCharacterConnection then
        toolTintCharacterConnection:Disconnect()
        toolTintCharacterConnection = nil
    end
    if toolTintChildConnection then
        toolTintChildConnection:Disconnect()
        toolTintChildConnection = nil
    end

    clearAllToolTints()
end

itemTintSection:AddToggle("Tool Tint", function(bool)
    if bool then
        enableToolTint()
    else
        disableToolTint()
    end
end)

itemTintSection:AddSlider("Tint Transparency", 1, 10, 5, function(value)
    toolTintTransparency = value / 10

    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            if object:IsA("Tool") then
                local highlight = object:FindFirstChild("ToolTint")
                if highlight then
                    highlight.FillTransparency = toolTintTransparency
                end
            end
        end
    end
end)
        shared.Notify("Tool Tint: invalid transparency, use 0.1 to 1", 3)
    end
end)

itemTintSection:AddColorpicker("Tool Tint Color", Color3.fromRGB(255, 255, 255), function(color)
    toolTintColor = color

    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            if object:IsA("Tool") then
                local highlight = object:FindFirstChild("ToolTint")
                if highlight then
                    highlight.FillColor = color
                end
            end
        end
    end
end)

RootNicolas:GiveTask(function()
    gunFeatures.blockAnims = false
    gunFeatures.equipSound = false
    gunFeatures.forceField = false
    gunFeatures.fireColor = false
    disableBlockAnims()
    disableEquipSound()
    disableForceField()
    disableFireColor()
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
    controllerFeatures.fixScoreboard = false
    controllerFeatures.perkEnabled = false
    controllerFeatures.shiftLockEnabled = false
    controllerFeatures.spectateKeybinds = false
    disableFixScoreboard()
    disableSpectateUI()
    waterFeatures.waterImmunity = false
    disableWaterImmunity()
    disableAntiTrade()
    disableServerPos()
    stopAutoPerk()
    disableToolTint()
end)
