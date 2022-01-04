-- library
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/LegoHacks/Utilities/main/UI.lua"))();

--[[
    Made by DaDude#3044
    LegoHacks tbh

    -- 06/02/21
    Added ScriptWare support - Spencer#0003
]]

-- default locals
local replicatedFirst = game:GetService("ReplicatedFirst");
local runService = game:GetService("RunService");
local stepped = runService.stepped;
local players = game:GetService("Players");
local client = players.LocalPlayer;
local userInputService = game:GetService("UserInputService");
local camera = workspace.CurrentCamera;
local mouse = client:GetMouse();
local tweenService = game:GetService("TweenService");
local random = Random.new(os.time());
for i, v in next, debug do
    if (not getfenv()[i]) then
        getfenv()[i] = v;
    end;
end;

-- game specifc locals
local gameScript = getmenv(replicatedFirst.GameScript);
local oldWorldCFrame = require(replicatedFirst.VR.VRModule).GetWorldCFrame;
local oldReset = gameScript.ResetCamera;
local oldUpdateCubes = getupvalue(gameScript.UpdateCubes, 20);
local guiScript = getsenv(client.PlayerScripts["3DGuiScript"]);
local oldHiding = guiScript.HideLoading;
local loadingSongFinished = false;
local gui = workspace.Client.Gui;
local cubes = {};
local difficulties = {
    Easy = 0;
    Medium = 1;
    Hard = 2;
    Logic = 3;
};

-- functions and events
workspace.Client.ChildAdded:Connect(function(cube)
    if (cube.Name == "Cube" or cube.Name == "Cube_Mesh") then
        table.insert(cubes, cube);

        if (library.flags.antiGhostEnabled) then
            local box = cube:FindFirstChildWhichIsA("SelectionBox");

            if (box) then
                box:GetPropertyChangedSignal("Transparency"):Connect(function()
                    box.Transparency = 0;
                end);
            else
                cube:GetPropertyChangedSignal("Transparency"):Connect(function()
                    cube.Transparency = 0;
                end);
            end;
        end;

        if (library.flags.cubeMatchEnabled) then
            local box = cube:FindFirstChildWhichIsA("SelectionBox") or cube:FindFirstChildWhichIsA("SpecialMesh");

            spawn(function()
                repeat
                    if (box:IsA("SelectionBox")) then
                        box.Color3 = library.flags.cursorColour;
                    else
                        box.VertexColor = Vector3.new(library.flags.cursorColour.r, library.flags.cursorColour.g, library.flags.cursorColour.b);
                    end;
                    runService.RenderStepped:Wait();
                until not table.find(cubes, cube);
            end);
        end;
    end;
end);
workspace.Client.ChildRemoved:Connect(function(cube)
    if (cube.Name == "Cube" or cube.Name == "Cube_Mesh") then
        table.remove(cubes, table.find(cubes, cube));
    end;
end);

local function closestCube()
    local shortestDistance, closest = math.huge, nil;
    for __, cube in next, cubes do
        local distance = (cube.Position - camera.CFrame.p).Magnitude;

        if (distance < shortestDistance) then
            closest = cube;
            shortestDistance = distance;
        end;
    end;

    return closest, shortestDistance;
end;

local function expectedCFrame()
    local cube, distance, originalXPos = closestCube();

    if (library.flags.autoPlayerEnabled and cube) then
        tweenService:Create(fakeCursor, TweenInfo.new(1 - (10 / (math.floor(distance * 100) / 100))), {Value = CFrame.new(camera.CFrame.p, library.flags.cameraLockEnabled and Vector3.new(0.05, cube.Position.Y, cube.Position.Z) or cube.Position)}):Play();
        camera.CFrame = fakeCursor.Value;

        return fakeCursor.Value;
    end;
    return (client:WaitForChild("MapData").Playing and ((not library.flags.autoPlayerEnabled or cube == nil) and CFrame.new(camera.CFrame.p, mouse.Hit.p)) or camera.CFrame);
end;

local function playableMaps()
    local maps = {};

    for __, songId in next, getrenv()._G.PlayerData.Inventory.Maps do
        local map = getrenv()._G.Content.Maps[songId]
        if (not map.MemberOnly) then
            table.insert(maps, map);
        end;
    end;

    return maps;
end;

guiScript.HideLoading = function()
    oldHiding();
    loadingSongFinished = true;
    return;
end;

setupvalue(gameScript.UpdateCubes, 20, function(cube, ...)
    return (library.flags.instantHitEnabled or (library.flags.silentAimEnabled and (cube.Position.X >= 0.05))) or oldUpdateCubes(cube, ...);
end);

setupvalue(gameScript.UpdateSaber, 1, expectedCFrame);
require(replicatedFirst.VR.VRModule).GetWorldCFrame = expectedCFrame;
camera.CameraType = Enum.CameraType.Track;
userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter;

-- library objects initialisation
local autoPlayerSection = library:CreateWindow("Auto Player");
local miscSection = library:CreateWindow("Miscellaneous");

local autofarm;
autoPlayerSection:AddToggle({
    text = "Auto Player";
    flag = "autoPlayerEnabled";
});
autoPlayerSection:AddToggle({
    text = "Auto Farm";
    flag = "autoFarmEnabled";
    callback = function(enabled)
        if (enabled) then
            spawn(function()
                repeat
                    if (getrenv()._G.IsInHub) then
                        -- stops the autofarm trying to invoke functions while you're in the lobby
                        return print("Make sure you are in the arcade to start the auto farm.");
                    end;
    
                    local maps = playableMaps();
                    local songId, chosenMap;
    
                    repeat
                        chosenMap = maps[random:NextInteger(1, table.getn(maps))]; -- selects a random map to play
                        
                        if (library.flags.mapDifficultyLimited) then
                            for difficulty, value in next, difficulties do
                                if (not library.flags[difficulty] and (chosenMap.Difficulty == value)) then
                                    chosenMap = nil;
                                    break;
                                end;
                            end;
                        end;
                    until chosenMap;
                    songId = table.find(getrenv()._G.Content.Maps, chosenMap);
                    getrenv()._G.SetPage(0, 0, 0); -- the song selection screen
    
                    for i = 0, 50 do
                        guiScript.ScrollSongPage(-1);
                        runService.RenderStepped:Wait();
                    end;
    
                    local chosenMapPart;
                    repeat
                        guiScript.ScrollSongPage(1); -- keep scrolling until you find the page with the selected song
                        runService.RenderStepped:Wait();
    
                        for __, descendant in next, gui.Maps:GetDescendants() do
                            if (descendant.Name == "SongId" and descendant.Value == songId) then
                                chosenMapPart = descendant.Parent;
                                break;
                            end;
                        end;
                    until chosenMapPart;
    
                    guiScript.OnClickPageMaps(chosenMapPart);
    
                    repeat wait() until loadingSongFinished; -- wait for it to load before attempting to play the song
    
                    getrenv()._G.TryStartGame(songId, chosenMap);
                    loadingSongFinished = false;
    
                    repeat wait(5) until not client:WaitForChild("MapData").Playing.Value;
    
                    print("Completed", chosenMap.Name);
    
                until not library.flags.autoFarmEnabled;
            end);
        end;
    end;
});
autoPlayerSection:AddToggle({
    text = "Silent Aim";
    flag = "silentAimEnabled";
});
autoPlayerSection:AddToggle({
    text = "Instant Hit";
    flag = "instantHitEnabled";
});
-- this lib doesn't have separators or combo boxes so this looks a lot more cringe
autoPlayerSection:AddToggle({
    text = "Limit Map Difficulties";
    flag = "mapDifficultyLimited";
});
autoPlayerSection:AddToggle({
    text = "Easy";
    flag = "Easy";
});
autoPlayerSection:AddToggle({
    text = "Medium";
    flag = "Medium";
});
autoPlayerSection:AddToggle({
    text = "Hard";
    flag = "Hard";
});
autoPlayerSection:AddToggle({
    text = "Logic";
    flag = "Logic";
});

local camChangedEvent;
miscSection:AddToggle({
    text = "Camera Lock";
    flag = "cameraLockEnabled";
    callback = function(enabled)
        -- this function stops a few rare glitches where the camera would randomly TP somewhere
        if (enabled) then
            camChangedEvent = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
                if client:WaitForChild("MapData").Playing.Value then
                    camera.CFrame = CFrame.new(Vector3.new(7.1, 3, 0)) * CFrame.Angles(0, math.pi / 2, 0);
                    camera.CameraType = Enum.CameraType.Fixed;
                    userInputService.MouseBehavior = Enum.MouseBehavior.Default;
                end;
            end);
        else
            camera.CameraType = Enum.CameraType.Track;
            userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter;
            if (camChangedEvent) then
                camChangedEvent:Disconnect();
            end;
        end;
    end;
});
-- anti spectate makes the spectator spaz out and get stuck
miscSection:AddToggle({
    text = "Anti Spectate";
    flag = "antiSpecEnabled";
    callback = function(enabled)
        require(replicatedFirst.VR.VRModule).GetWorldCFrame = enabled and function()
            if (getfenv(1).script.Name == "GameScript") then
                return math.pow((math.huge % math.huge), math.huge); -- causes a lot of errors for the spectator
            end;
    
            return CFrame.new();
        end or expectedCFrame;
    end;
});
miscSection:AddToggle({
    text = "Anti Ghost/Strobe";
    flag = "antiGhostEnabled";
});

local cubeMatch, trailMatch;
cubeMatch = miscSection:AddToggle({
    text = "Cube Match";
    flag = "cubeMatchEnabled";
    callback = function(enabled)
        if (enabled) then
            trailMatch:SetState(false);
        end;
    end;
});
trailMatch = miscSection:AddToggle({
    text = "Trail Match";
    flag = "trailMatchEnabled";
    callback = function(enabled)
        if (enabled) then
            cubeMatch:SetState(false);
    
            spawn(function()
                repeat
                    local cube = closestCube();
    
                    if (cube) then
                        local box = cube:FindFirstChildWhichIsA("SelectionBox") or cube:FindFirstChildWhichIsA("SpecialMesh");
    
                        if (box:IsA("SelectionBox")) then
    
                            cursorColour:SetColor(box.Color3);
                            box.Color3 = library.flags.cursorColour;
                        else
                            cursorColour:SetColor(Color3.new(box.VertexColor.X, box.VertexColor.Y, box.VertexColor.Z));
                        end;
                    end;
                    runService.RenderStepped:Wait();
                until not library.flags.trailMatchEnabled;
            end);
        end;
    end;
});
miscSection:AddToggle({
    text = "Trail";
    flag = "trailEnabled";
    callback = function(enabled)
        if (enabled) then
            uiCursor.ImageLabel.BackgroundTransparency = 0;
            repeat
                local clonedCursor = partCursor:Clone();
                local trail = uiCursor:Clone();
    
                clonedCursor.Parent = cursorHolder;
                trail.ImageLabel.Visible = true;
                trail.Parent = clonedCursor;
                trail.Adornee = nil;
            
                for i, v in next, trail:GetChildren() do
                    if (v.Name == "ImageLabel") then
                        local trailAnim = tweenService:Create(v, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new()});
                        tweenService:Create(v, TweenInfo.new(0.75), {BackgroundTransparency = 1}):Play();
                        trailAnim.Completed:Connect(function()
                            clonedCursor:Destroy();
                        end);
                        trailAnim:Play();
                    end;
                end;
    
                runService.Stepped:Wait();
            until not library.flags.trailEnabled;
    
            wait(0.15);
            uiCursor.ImageLabel.BackgroundTransparency = 1;
            wait(0.85);
            for i, v in next, cursorHolder:GetChildren() do
                v:Destroy();
            end;
        end;
    end;
});
miscSection:AddToggle({
    text = "Song Speed";
    flag = "songSpeedEnabled";
    callback = function(enabled)
        if (enabled) then
            repeat
                replicatedFirst.GameScript.Music.PlaybackSpeed = (library.flags.songSpeed * 0.02);
                runService.RenderStepped:Wait();
            until not library.flags.songSpeedEnabled;
        end;
    end;
});
local songSpeed = miscSection:AddSlider({
    text = "Song Speed";
    flag = "songSpeed";
    max = 100;
    min = 1;
    value = 50;
});
miscSection:AddButton({
    text = "Reset Song Speed";
    callback = function()
        songSpeed:SetValue(50);
    end;
});

library:Init();
