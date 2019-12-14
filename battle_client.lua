--file://c:/castle/ast/battle_client.lua

--file://c:/castle/ast/x3/x3test_obj_scene.lua

local mods = require("client_base");
local Sound = require("lib/sound")
local LASER_SPEED = 50;
local PLAYER_RADIUS = 1;
local POD_SPEED = 5;

x3 = mods.x3;
GameClient = mods.GameClient;
GameCommon = mods.GameCommon;

print("loaded");
require("battle_common.lua");

local Assets = {
    Pod = x3.loadObj("assets/pod.obj")
}

local Audio = {
    laser = Sound:new("assets/audio/laser.mp3", 24);
}

Audio.laser:setCooldown(0.05);

local GameViewer = {
    scene = x3.newEntity()
};

function GameViewer:init()

    self.numLasers = 0;
    self.laserData = {};
 
    self.moons = x3.newEntity(
        x3.mesh.newSphere(1.0, 16, 16),
        x3.material.newLit({
            --baseColor = {0.9, 0.9, 1.0},
            baseTexture = love.graphics.newImage("assets/img/mercury.jpg"),
            hemiColors = {{0.5, 0.5, 0.5}, {1.0, 1.0, 1.0}},
        })
    );
    self.scene:add(self.moons);
    self.moons:setPosition(0,0,0);
    self.moons:hide();

    self.stars = x3.newEntity(
        x3.mesh.newSphere(0.5, 4, 4),
        x3.material.newUnlit({
            baseColor = {0.0, 0.0, 0.0},
            emissiveColor = {1.0, 1.0, 1.0}
        })
    );

    self.stars:setNumInstances(1000);

    for i = 1,self.stars:getNumInstances() do
        local th = math.random() * math.pi * 2;
        local rad = math.random() * 300 + 300;
        local z = math.random() * 2 - 1;

        local iz = math.sqrt(1 - z*z);
        local x = iz * math.cos(th);
        local y = iz * math.sin(th); 

        self.stars:getInstance(i):setPosition(x * rad, y * rad, z * rad);
    end

    self.scene:add(self.stars);

    --[[
    self.balls = x3.newEntity(
        x3.mesh.newSphere(1,16,16),
        x3.material.newLit({
            baseColor = {1.0, 0.0, 0.0},
            emissiveColor = {0.5, 0.0, 0.0}
        })
    );

    self.scene:add(self.balls);
    ]]

    self.lasers = x3.newEntity(
        x3.mesh.newSphere(0.05,16,16),
        x3.material.newUnlit({
            baseColor = {0,0,0},
            emissiveColor = {0.0,0.9,1.0}
        })
    );

    self.lasers:setNumInstances(1000);
    self.lasers:hide();
    self.scene:add(self.lasers);

    self.podEntities = {};

    for meshName, mesh in pairs(Assets.Pod.meshesByName) do

        local matProps = {
            baseColor = x3.hexColor(0xF0FFCE),
            specularColor = {0.5, 0.5, 0.5},
            hemiColors = {{0.5, 0.5, 0.5}, {1.0, 1.0, 1.0}},
            shininess = 10
        }

        if (meshName == "glass_glass_geo") then
            matProps.baseColor = x3.hexColor(0x280004);
            matProps.shininess = 25;
            matProps.specularColor = {1,1,1};
        end

        if (meshName == "fin_fin_geo") then
            matProps.baseColor = x3.hexColor(0xA53F2B)
        end


        self.podEntities[meshName] = x3.newEntity(
            mesh,
            x3.material.newLit(matProps)
        );

        self.scene:add(self.podEntities[meshName]);
    end

    self.sun = x3.newPointLight({
        color = {1,1,1},
        position = x3.vec3(0, 10, 0),
        intensity = 1
    });

    self.scene:add(self.sun);

    self.camera = x3.newCamera();
    self.camera:setPosition(5,5,5);
    self.UP = x3.vec3(0,1,0);

    self.camera:lookAt(x3.vec3(0,0,0), self.UP);
end

function GameViewer:drawHUD(player)
    local w, h = love.graphics.getDimensions();

    player = player or {shield = 1, health = 1};

    love.graphics.setLineWidth(3);
    love.graphics.setColor(0,1,1,0.5);
    love.graphics.circle("line", w * 0.5 - 7, h * 0.5, 5);
    love.graphics.circle("line", w * 0.5 + 7, h * 0.5, 5);

    local ox = 10;
    local sx = 100;
    local sy = 10;

    love.graphics.setColor(0.2, 0.7, 1.0, 1.0);
    love.graphics.rectangle("line", ox, h - 100, sx, sy)
    love.graphics.setColor(0.2, 0.7, 1.0, 0.7);
    love.graphics.rectangle("fill", ox, h - 100, sx * player.shield, sy)

    love.graphics.setColor(1.0, 0.2, 0.2, 1.0);
    love.graphics.rectangle("line", ox, h - 80, sx, sy)
    love.graphics.setColor(1.0, 0.2, 0.2, 0.7);
    love.graphics.rectangle("fill", ox, h - 80, sx * player.health, sy)

end

function GameViewer:draw(player)
    x3.render(self.camera, self.scene, self.canvas, {
        clearColor = {0,0,0,1}
    });

    local w, h = love.graphics.getDimensions();
    love.graphics.draw(GameViewer.canvas.color, 0, h, 0, 1, -1);
    self:drawHUD(player);
end

local moonColLow = x3.vec3(0.9);
local moonColHi = x3.vec3(1.0);

function GameViewer:setMoons(numMoons, moonPositions, moonScales)


    if (numMoons > 0) then
        self.moons:show();
    else
        self.moons:hide();
    end

    self.moons:setNumInstances(numMoons);
 
    for i = 1,numMoons do
        self.moons:getInstance(i):setPosition(moonPositions[i]);
        self.moons:getInstance(i):setScale(moonScales[i]);
        self.moons:getInstance(i).color:randomCube(moonColLow, moonColHi);
    end
    
end

function GameViewer:updateLasers(dt)
    if (self.numLasers > 0) then
        self.lasers:show();
        --print("nl", self.numLasers)

        self.lasers:setNumInstances(self.numLasers);
    else
        self.lasers:hide();
    end

    local i = 0;
    for id, laser in pairs(self.laserData) do
        i = i + 1;
        local ins = self.lasers:getInstance(i);
        ins:setPosition(laser.ray:at(laser.t));
        laser.t = laser.t + dt * LASER_SPEED;

        --print(laser.t, laser.dist);
        --ins.origin:print();

        if (laser.t > laser.dist) then
            self.laserData[id] = nil;
            self.numLasers = self.numLasers - 1;
        end
    end
end

function GameViewer:update(dt)

    self.sun:copyPosition(self.camera);
    self:updateLasers(dt);

end


local v3tmp = x3.vec3();
local qtmp = x3.quat();

function GameViewer:setPlayers(myId, players, dt)

    local numPlayers = 0;
    for _, _ in pairs(players) do
        numPlayers = numPlayers + 1;
    end


    for name, entity in pairs(self.podEntities) do
        entity:setNumInstances(numPlayers);

        local i = 0;
        for cid, player in pairs(players) do
            i = i + 1;
            local pos = player.pos;
            local rot = player.rot;

            local instance = entity:getInstance(i);

            if (pos and cid ~= myId) then

                v3tmp:fromArray(pos);
                qtmp:fromArray(rot);

                --instance:setPosition(pos[1], pos[2], pos[3]);
                --instance:setRotation(rot[1], rot[2], rot[3], rot[4]);
                
                instance:lerp(v3tmp, math.min(dt * 10, 1.0));
                instance:slerp(qtmp, math.min(dt * 10, 1.0));
            else
                instance:copyPosition(self.camera);
                instance:copyRotation(self.camera);
            end

            --[[
            if (name == "fin_fin_geo") then
                instance:setColor(1,0,0);
            end]]

        end
    end
end

function GameViewer:resize()
    local w,h = love.graphics.getDimensions();
    GameViewer.canvas = x3.newCanvas3D(w,h);
    self.camera:setPerspective(90, h/w, 0.5, 1000.0);
end

function GameViewer:addLaser(id, ray, dist)

    self.numLasers = (self.numLasers or 0) + 1;

    self.laserData[id] = {
        ray = ray:clone(),
        dist = dist,
        t = 0
    };

    Audio.laser:play();

end

local GameplayController = {};

local v3tmp = x3.vec3(0.0);

function GameClient:sendPlayerState()
    if (self.clientId and self.players[self.clientId]) then
    
        local pos = GameViewer.camera:getPosition();
        local quat = GameViewer.camera:getRotation();

        self:send({
            kind = 'playerUpdate',
        }, self.clientId, {
            pos = {pos.x, pos.y, pos.z},
            rot = {quat.x, quat.y, quat.z, quat.w}
        })
    end
end

function GameClient:fire()

    self.laserSide = (self.laserSide or 1) * -1;

    local fireRay = self.fireRay or x3.ray();
    
    self.fireRay = fireRay;

    fireRay.origin:copy(GameViewer.camera:getPosition());
    GameViewer.camera:getLocalZAxis(fireRay.direction);

    local camY = GameViewer.camera:getLocalYAxis();
    fireRay.origin:addScaled(camY, -0.3);

    local camX = GameViewer.camera:getLocalXAxis();
    fireRay.origin:addScaled(camX, self.laserSide * 0.2);

    fireRay.direction:normalize();
    fireRay.direction:invert();

    local dist, hitId, hitData = self.collider:traceRay(fireRay);

    self.laserId = self.laserId + 1;
    local id = ""..(self.clientId or "local").."_"..self.laserId;

    print("hitd", dist);

    dist = 50;
    GameViewer:addLaser(id, fireRay, dist or 50);
        
    local msgKind = 'laserMiss';
    if (hitData and hitData.type == "player") then
        msgKind = 'laserHit';
    end

    self:send({
        kind = msgKind,
    }, self.clientId,
        fireRay:serialize(),
        dist,
        hitId
    );

end

function GameClient:resize()
    GameViewer:resize();
end

function GameClient:start()
    print("initing...")
    GameViewer:init();
    GameViewer:resize();
    self:init();
    print("inited");

    self.timer = x3.newTimer();
    self.collider = x3.newCollider();
    self.laserId = 0;
    local numMoons = 40;

    local moonLocs = {};
    local moonSizes = {};

    local worldSize = 150;
    self.worldMin = x3.vec3(-worldSize, -worldSize, -worldSize);
    self.worldMax = x3.vec3(worldSize, worldSize, worldSize);

    for i = 1, numMoons do
        moonLocs[i] = x3.vec3();
        moonLocs[i]:randomCube(self.worldMin, self.worldMax);
        moonSizes[i] = math.random() * 5 + 2;
        
        
        self.collider:addSphere("moon"..i, moonLocs[i], moonSizes[i], {
            type = "moon",
            id = i
        });

    end

    GameViewer:setMoons(numMoons, moonLocs, moonSizes);

end

function GameClient:keypressed(key)
    if (key == "space") then
      love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
    end
end

function GameClient:removePlayer(clientId)
    self.collider:remove("p"..clientId);
end

local rayTemp = x3.ray();
function GameClient:handleLaser(rayData, dist)
    self.laserId = self.laserId + 1;
    rayTemp:deserialize(rayData);
    GameViewer:addLaser(self.laserId, rayTemp, dist);

    print("HandleLaser");
end

function GameClient:update(dt)

    local k = love.keyboard.isDown;
    local cam = GameViewer.camera;

    if (love.mouse.isDown(1) and self.timer:ezCooldown("fire", 0.1)) then
        self:fire();
    end

    if k("s") then
        cam:moveLocalZ(dt * POD_SPEED);
    elseif k("w") then
        cam:moveLocalZ(-dt * POD_SPEED);
    end

    if k("d") then
        cam:rotateLocalZ(-dt * 2);
    elseif k("a")  then
        cam:rotateLocalZ(dt * 2);
    end


    self:sendPlayerState();

    if (self.clientId) then
        GameViewer:setPlayers(self.clientId, self.players, dt);
            
        for cid, player in pairs(self.players) do
            if (cid ~= self.clientId) then
                v3tmp:fromArray(player.pos);
                self.collider:addSphere(cid, v3tmp, PLAYER_RADIUS, {
                    type = "player",
                    id = cid
                });
            end
        end
    end

    GameViewer:update(dt);
end

--[[
function GameClient:onPlayerAdded(clientId, player)

end
]]

function GameClient:mousepressed()
    --self:fire();
end

function GameClient:mousemoved(x, y, dx, dy)
    --GameViewer.camera:rotateAxis(GameViewer.UP, dx * 0.01);
    --GameViewer.camera:rotateLocalX(dy * 0.01);
    local scale = 0.01;
    GameViewer.camera:rotateLocalX(-dy * scale);
    GameViewer.camera:rotateLocalY(-dx * scale);
end

function GameClient:draw()
    local me = self.players[self.clientId];
    GameViewer:draw(me);
end