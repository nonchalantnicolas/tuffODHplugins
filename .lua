-- This plugin contains the following:
-- OG Gun
-- Controller+
-- Water Proof
-- Coin+
-- i dont skid! all made by @drowsynicolas

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

local ogFeatures = {
    blockAnims = false,
    equipSound = false,
}

local charData = {}
local currentSounds = {}

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
        if ogFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(equipConn)
    
    local unequipConn = tool.Unequipped:Connect(function()
        if ogFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(unequipConn)
    
    return equipConn, unequipConn
end

local function applyOGFeatures(character)
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

    if ogFeatures.blockAnims then
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

    if ogFeatures.equipSound then
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
    if ogFeatures.blockAnims or ogFeatures.equipSound then
        applyOGFeatures(character)
    end
end

local animBlockGlobalNicolas = nicolas.new()
local equipSoundGlobalNicolas = nicolas.new()

local function enableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    animBlockGlobalNicolas = nicolas.new()

    if LocalPlayer.Character then
        applyOGFeatures(LocalPlayer.Character)
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
        applyOGFeatures(LocalPlayer.Character)
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

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

local ogSection = shared.AddSection("OG Gun")
ogSection:AddParagraph("Additional Info", "This plugin works for both MM2 and MMV\n\nCredits: @drowsynicolas")
ogSection:AddToggle("Disable Gun Animations", function(bool)
    ogFeatures.blockAnims = bool
    if bool then
        enableBlockAnims()
    else
        disableBlockAnims()
    end
end)
ogSection:AddToggle("Equip/Unequip Gun Sound", function(bool)
    ogFeatures.equipSound = bool
    if bool then
        enableEquipSound()
    else
        disableEquipSound()
    end
end)

local controllerFeatures = {
    fixScoreboard = false,
    perkEnabled = false,
    shiftLockEnabled = false,
    spectateKeybinds = false,
    isSpectating = false,
}

local scoreboardMaid = nil
local shiftLockConnection = nil

SpectateService.SpectateStarted.Event:Connect(function()
    controllerFeatures.isSpectating = true
end)

SpectateService.SpectateCancelled.Event:Connect(function()
    controllerFeatures.isSpectating = false
end)

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
    local player = game.Players.LocalPlayer
    local character = player.Character
    
    if not character then return end
    
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
    
    scoreboardMaid:GiveTask(pg.ChildAdded:Connect(function(child)
        if child.Name:lower():find("scoreboard") then
            task.wait()
            child:Destroy()
        end
    end))
    
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

local controllerSection = shared.AddSection("Controller+")
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
end)
controllerSection:AddKeybind("Perk Keybind", "ButtonX", function()
    perkKeybind()
end)
controllerSection:AddKeybind("Shift Lock", "ButtonL3", function()
    shiftLockKeybind()
end)
controllerSection:AddKeybind("Spectate Next", "ButtonR1", function()
    if controllerFeatures.spectateKeybinds and controllerFeatures.isSpectating then
        SpectateService:NavigateSpectate(1)
    end
end)
controllerSection:AddKeybind("Spectate Previous", "ButtonL1", function()
    if controllerFeatures.spectateKeybinds and controllerFeatures.isSpectating then
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

local function CheckMaps()
    if not waterFeatures.waterImmunity then return end
    
    local yacht = Workspace:FindFirstChild("Yacht")
    if yacht then
        local intereactive = yacht:FindFirstChild("Intereactive")
        if intereactive then
            local water = intereactive:FindFirstChild("Water")
            if water then
                DisableWaterPart(water:FindFirstChild("WaterPart"))
            end
        end
    end
    
    local pier = Workspace:FindFirstChild("Pier")
    if pier then
        DisableWaterPart(pier:FindFirstChild("Respawn"))
    end
end

local function enableWaterImmunity()
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    
    waterMaid = nicolas.new()
    
    CheckMaps()
    
    waterMaid:GiveTask(Workspace.DescendantAdded:Connect(CheckMaps))
    waterMaid:GiveTask(Workspace.DescendantRemoved:Connect(CheckMaps))
end

local function disableWaterImmunity()
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    
    RestoreAllParts()
end

local waterSection = shared.AddSection("Water Proof")
waterSection:AddParagraph("Additional Info", "Makes you immune to water\n\nCredits: @drowsynicolas")
waterSection:AddToggle("Water Immunity", function(bool)
    waterFeatures.waterImmunity = bool
    if bool then
        enableWaterImmunity()
    else
        disableWaterImmunity()
    end
end)

local soundData = {
    enabled = false,
    soundId = nil,
    connections = {},
    monitoredParts = {},
}

local function playReplacementSound(parent)
    if not soundData.soundId or not soundData.enabled then return end
    
    local sound = Instance.new("Sound")
    sound.Name = "ReplacementSound"
    sound.SoundId = soundData.soundId
    sound.Volume = 1
    sound.Parent = parent
    sound:Play()
    
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

local function processCoinSound(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Sound") and child.Name == "CoinSound" then
            child.Volume = 0
            if soundData.enabled then
                playReplacementSound(part)
            end
        end
    end
end

local function monitorPart(part)
    if not part or soundData.monitoredParts[part] then return end
    soundData.monitoredParts[part] = true
    
    processCoinSound(part)
    
    local conn = part.ChildAdded:Connect(function(child)
        if child:IsA("Sound") and child.Name == "CoinSound" then
            child.Volume = 0
            if soundData.enabled then
                playReplacementSound(part)
            end
        end
    end)
    table.insert(soundData.connections, conn)
end

local function monitorPlayer(player)
    local function setup(character)
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            monitorPart(hrp)
        end
    end
    
    if player.Character then
        setup(player.Character)
    end
    
    local conn = player.CharacterAdded:Connect(setup)
    table.insert(soundData.connections, conn)
end

local function enableSoundSystem()
    soundData.enabled = true
    soundData.monitoredParts = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        monitorPlayer(player)
    end
    
    local playerAdded = Players.PlayerAdded:Connect(monitorPlayer)
    table.insert(soundData.connections, playerAdded)
end

local function disableSoundSystem()
    soundData.enabled = false
    for _, conn in ipairs(soundData.connections) do
        conn:Disconnect()
    end
    table.clear(soundData.connections)
    table.clear(soundData.monitoredParts)
end

local auraData = {
    enabled = false,
    thread = nil,
    radius = 8,
}

local function getCoinContainers()
    local containers = {}
    for _, map in ipairs(Workspace:GetChildren()) do
        local container = map:FindFirstChild("CoinContainer")
        if container then
            table.insert(containers, container)
        end
    end
    return containers
end

local function getCoinParts(containers)
    local parts = {}
    for _, container in ipairs(containers) do
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant:FindFirstChild("TouchInterest") then
                table.insert(parts, descendant)
            end
        end
    end
    return parts
end

local function collectNearbyCoins()
    local character = Players.LocalPlayer.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local rootPos = rootPart.Position
    local containers = getCoinContainers()
    local coinParts = getCoinParts(containers)
    
    for _, part in ipairs(coinParts) do
        if (rootPos - part.Position).Magnitude <= auraData.radius then
            firetouchinterest(rootPart, part, 0)
            firetouchinterest(rootPart, part, 1)
        end
    end
end

local function startAura()
    auraData.enabled = true
    auraData.thread = RunService.Heartbeat:Connect(collectNearbyCoins)
end

local function stopAura()
    auraData.enabled = false
    if auraData.thread then
        auraData.thread:Disconnect()
        auraData.thread = nil
    end
end

local coinSection = shared.AddSection("Coin+")
coinSection:AddParagraph("Additional Info", "idk what to put here\n\nCredits: @drowsynicolas")
coinSection:AddToggle("Coin Aura", function(bool)
    if bool then
        startAura()
    else
        stopAura()
    end
end)
coinSection:AddToggle("Custom Coin Collect Sound", function(bool)
    if bool then
        enableSoundSystem()
    else
        disableSoundSystem()
    end
end)
coinSection:AddTextBox("Enter Custom Coin Collect Sound ID", function(text)
    if text:match("^%d+$") then
        soundData.soundId = "rbxassetid://" .. text
    else
        shared.Notify("Sound IDs can only contain numbers", 3)
    end
end)

RootNicolas:GiveTask(function()
    ogFeatures.blockAnims = false
    ogFeatures.equipSound = false
    disableBlockAnims()
    disableEquipSound()
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
    
    controllerFeatures.fixScoreboard = false
    controllerFeatures.perkEnabled = false
    controllerFeatures.shiftLockEnabled = false
    controllerFeatures.spectateKeybinds = false
    controllerFeatures.isSpectating = false
    disableFixScoreboard()
    if shiftLockConnection then
        shiftLockConnection:Disconnect()
        shiftLockConnection = nil
    end
    
    waterFeatures.waterImmunity = false
    disableWaterImmunity()
    
    disableSoundSystem()
    stopAura()
end)
