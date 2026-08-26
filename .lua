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
local LocalPlayer = Players.LocalPlayer
local BLOCKED = {
    ["123606547020560"] = true,
    ["134826825394657"] = true,
    ["124281955370937"] = true,
    ["127786188145385"] = true,
}
local SOUND_ID = "rbxassetid://7158356564"
local START_OFFSET = 0.3
local features = {
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
        if features.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(equipConn)
    local unequipConn = tool.Unequipped:Connect(function()
        if features.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(unequipConn)
    return equipConn, unequipConn
end
local function applyFeatures(character)
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
    if features.blockAnims then
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
    if features.equipSound then
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
    if features.blockAnims or features.equipSound then
        applyFeatures(character)
    end
end
local animBlockGlobalNicolas = nicolas.new()
local equipSoundGlobalNicolas = nicolas.new()
local function enableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    animBlockGlobalNicolas = nicolas.new()
    if LocalPlayer.Character then
        applyFeatures(LocalPlayer.Character)
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
        applyFeatures(LocalPlayer.Character)
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
local section = shared.AddSection("OG Gun")
section:AddParagraph("Additional Info", "This plugin works for both MM2 and MMV\n\nCredits: @drowsynicolas")
section:AddToggle("Disable Gun Animations", function(bool)
    features.blockAnims = bool
    if bool then
        enableBlockAnims()
    else
        disableBlockAnims()
    end
end)
section:AddToggle("Equip/Unequip Gun Sound", function(bool)
    features.equipSound = bool
    if bool then
        enableEquipSound()
    else
        disableEquipSound()
    end
end)
RootNicolas:GiveTask(function()
    features.blockAnims = false
    features.equipSound = false
    disableBlockAnims()
    disableEquipSound()
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
end)
