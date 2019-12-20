--file://c:/castle/ast/battle_client.lua

--file://c:/castle/ast/x3/x3test_obj_scene.lua

local mods = require("client_base");
local Sound = require("lib/sound")
local LASER_SPEED = 50;
local PLAYER_RADIUS = 1;
local SHIP_FRICTION = 1.0;
local SHIP_ACCEL = 10;
local ARENA_RADIUS = 30;

local POD_SPEED = 5;

x3 = mods.x3;
local Y_AXIS = x3.vec3(0,1,0); 

GameClient = mods.GameClient;
GameCommon = mods.GameCommon;

print("loaded");
require("battle_common.lua");

local Assets = {
    Pod = x3.loadObj("assets/pod.obj")
}

local Meshes = {
    Particle = x3.mesh.newSphere(1,5,5)
}

local Materials = {
    Particle = x3.material.newUnlit({
        emissiveColor = {1.0, 0.5, 0.5}
    })
}

local Images = {
    Checker = love.graphics.newImage("assets/img/checker.jpg")
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
    self.bursts = {};
    self.numBursts = 0;
 
    --[[
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
]]

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
            emissiveColor = {1.0,0.5,0.5}
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

    local shieldShaderOpts = {
        defines = {
            LIGHTS = 0,
            INSTANCES = 1
        },

        transparent = true,

        shadeFragment = [[
            vec3 normal = getNormal();
            vec3 toEye = normalize(u_WorldCameraPosition - v_WorldPosition);
            float dt = dot(toEye, normal) * 0.5 + 0.5;
            float alpha = (1.0-dt);
            outColor.rgba = v_InstanceColor;
            outColor.a *= pow(alpha, 0.5);
        ]]
    };

    self.podEntities.shield = x3.newEntity(
        x3.mesh.newSphere(PLAYER_RADIUS * 1.3, 16, 16),
        x3.material.newCustom(
            x3.shader.newCustom(shieldShaderOpts), 
            {} --uniforms
        )
    );

    self.scene:add(self.podEntities.shield);

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
    love.graphics.setColor(0.2, 0.7, 1.0, 0.8);
    love.graphics.rectangle("fill", ox, h - 100, sx * player.shield, sy)

    love.graphics.setColor(1.0, 0.2, 0.2, 1.0);
    love.graphics.rectangle("line", ox, h - 80, sx, sy)
    love.graphics.setColor(1.0, 0.2, 0.2, 0.8);
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

--[[
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
    
end]]

function GameViewer:addBurst(pos)

    print("spawn", pos:__tostring());
    self.numBursts = self.numBursts+1;
    self.bursts[self.numBursts] = x3.newEntity(
        Meshes.Particle,
        Materials.Particle
    );

    local b = self.bursts[self.numBursts];
    b:setPosition(pos);
    b.age = 0;

    b:setNumInstances(30);
    
    for i = 1,b:getNumInstances() do
        local ins =  b:getInstance(i);

        local p = ins:getPosition();
        p:fromSphere(math.random() * 6, math.random() * 6, 0.01);
        ins:setPosition(p);
        ins:setScale(0.1);
        p:normalize();
        ins:orient(p, Y_AXIS);
    end

    self.scene:add(b);

end

function GameViewer:updateBursts(dt)

    for bid,b in pairs(self.bursts) do
        
        for i = 1,b:getNumInstances() do
            b:getInstance(i):moveLocalZ(-dt * 10);
        end

        b.age = b.age + dt;

        if (b.age > 0.2) then
            print("remove");
            self.scene:remove(b);
            self.bursts[bid] = nil; 
        end
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
        ins:orient(laser.ray.direction, Y_AXIS);
        ins:setScale(1,1,10);
        

        --print(laser.t, laser.dist);
        --ins.origin:print();

        if (laser.t > laser.dist) then
            self.laserData[id] = nil;
            self.numLasers = self.numLasers - 1;
            self:addBurst(laser.ray:at(laser.dist));
        end
    end
end

function GameViewer:update(dt)

    self.sun:copyPosition(self.camera);
    self:updateLasers(dt);
    self:updateBursts(dt);

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
    GameViewer.camera:getRelZAxis(fireRay.direction);

    local camY = GameViewer.camera:getRelYAxis();
    fireRay.origin:addScaled(camY, -0.3);

    local camX = GameViewer.camera:getRelXAxis();
    fireRay.origin:addScaled(camX, self.laserSide * 0.2);

    fireRay.direction:normalize();
    fireRay.direction:invert();

    local dist, hitId, hitData = self.collider:traceRay(fireRay);

    self.laserId = self.laserId + 1;
    local id = ""..(self.clientId or "local").."_"..self.laserId;

    print("hitd", dist);

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

function GameClient:initArena()


    self.collider:addInvereSphere("arenaSphere", x3.vec3(0.0), ARENA_RADIUS, {

    });

    local arenaRoot = x3.newEntity();

    local arenaSphere = x3.newEntity(
        x3.mesh.newSphere(ARENA_RADIUS, 24, 24, true --[[flip sides]]),
        x3.material.newLit({
            baseColor = {1,1,1},
            hemiColors = {{0.3,0.3,0.3}, {0.1, 0.1, 0.1}},
            --emissiveColor = {0.3, 0.3, 0.3},
            baseTexture = Images.Checker,
            --emissiveTexture = Images.Checker
        })
    );

    arenaRoot:add(arenaSphere);
    GameViewer.scene:add(arenaRoot);

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

    self:initArena();

    self.velocity = x3.vec3(0.0);

    --[[
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
    ]]
end

function GameClient:keypressed(key)
    if (key == "space") then
      love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
    end

    if (key == "r") then
        self:resetPlayer();
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
end

local ZERO = x3.vec3(0.0);

function GameClient:resetPlayer()

    local pos = x3.vec3();
    pos:fromSphere(math.random() * 6, math.random() * 6, ARENA_RADIUS - 3);
    GameViewer.camera:setPosition(pos);
    GameViewer.camera:lookAt(ZERO, Y_AXIS);

end


local tempPosition = x3.vec3();
function GameClient:update(dt)

    local k = love.keyboard.isDown;
    local cam = GameViewer.camera;

    if (love.mouse.isDown(1) and self.timer:ezCooldown("fire", 0.1)) then
        self:fire();
    end

    local accel = 0;

    if k("s") then
        accel = -SHIP_ACCEL;
        --cam:moveLocalZ(dt * POD_SPEED);
    elseif k("w") then
        accel = SHIP_ACCEL;
        --cam:moveLocalZ(-dt * POD_SPEED);
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

    --update ship motion

    self.velocity:addScaled(cam:getRelZAxis(), -accel * dt);
    self.velocity:scale(math.max(0.0, 1.0 - dt * SHIP_FRICTION));

    tempPosition:copy(cam:getPosition());

    cam:applyVelocity(self.velocity, dt);

    local hit = false;
    local curPos = cam:getPosition();

    self.collider:testSphere(curPos, PLAYER_RADIUS * 1.3, function()
        hit = true;
    end);

    if (hit) then
        cam:setPosition(tempPosition);
        self.velocity:set(0,0,0);
    end
    

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