--file://c:/castle/ast/battle_client.lua

--file://c:/castle/ast/x3/x3test_obj_scene.lua


local mods = require("client_base");

x3 = mods.x3;
GameClient = mods.GameClient;
GameCommon = mods.GameCommon;

--[[
local x3 = require("x3/x3", {root = true});
local CGame = require("multiplayer-tests/client", {root=true});
local GameClient = CGame.Client;
]]

local Sound = require("lib/sound");

local LASER_SPEED = 50;
local PLAYER_RADIUS = 1;
local SHIP_FRICTION = 1.0;
local SHIP_ACCEL = 20;
local ARENA_RADIUS = 60;
local TIME_TO_SHIELD_RECHARGE = 5;
local SHIELD_RECHARGE_RATE = 0.13; 
local ui = castle.ui;
--local POD_SPEED = 5;

local SHIELD_COLOR = {0.2, 0.7, 1.0};
local HEALTH_COLOR = {1.0, 0.2, 0.2};
local Y_AXIS = x3.vec3(0,1,0); 

print("loaded");
require("battle_common.lua");

local Assets = {
    Pod = x3.loadObj("assets/pod.obj"),
    Spheroid = x3.loadObj("assets/hc.obj")
}

local Meshes = {
    Particle = x3.mesh.newSphere(1,5,5)
}

local Materials = {
    Particle = x3.material.newUnlit({
        emissiveColor = {1.0, 0.5, 0.5}
    }),

    DeathParticle = x3.material.newUnlit({
        emissiveColor = {1.0, 1.0, 1.0}
    })
}

local Images = {
    Checker = love.graphics.newImage("assets/img/checker.jpg")
}

local Audio = {
    Laser = Sound:new("assets/audio/laser.mp3", 24),
    Shield_Hit = Sound:new("assets/audio/shield_hit.mp3", 10),
    Pod_Hit = Sound:new("assets/audio/pod_hit.mp3", 10),
    Sparks = Sound:new("assets/audio/sparks.mp3", 10)
}


Audio.Laser:setCooldown(0.05);

local GameViewer = {
    scene = x3.newEntity()
};

local MenuViewer = {};

local function initPodEntities(controller, root)
    
    controller.podEntities = {};

    for name, mesh in pairs(Assets.Pod.meshesByName) do
        local matProps = {
            baseColor = x3.hexColor(0xFFFFFF),
            specularColor = x3.COLOR.GRAY3,
            hemiColors = {{0.5, 0.5, 0.5}, {1.0, 1.0, 1.0}},
            shininess = 4
        }
        
        if (name == "glass_glass_geo") then
            matProps.baseColor = x3.hexColor(0xFFFFFF)
            matProps.shininess = 50
            matProps.hemiColors = {x3.COLOR.GRAY2, x3.COLOR.GRAY5}
            matProps.specularColor = {1,1,1};
        end

        controller.podEntities[name] = root:addNew(
            mesh,
            x3.material.newLit(matProps)
        );

    end
end

function MenuViewer:init()

    self.scene = x3.newEntity();
    self.camera = x3.newCamera();
    self.waitingForServer = false;

    self.podRoot = self.scene:addNew();

    self.camera:setPosition(0,0,5);
    self.camera:lookAt(x3.vec3(0,0,0), Y_AXIS);

    
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

    local light = x3.newPointLight({
        position = x3.vec3(0.0, 2.0, 2.0),
        color = {1,1,1},
        intensity = 2
    })

    self.scene:add(light);

    initPodEntities(self, self.podRoot);

end


function MenuViewer:draw(canvas)

    local t = love.timer.getTime();
    self.podRoot:setY(math.sin(love.timer.getTime() * 0.2) * 0.5);
    self.podRoot:resetRotation();
    self.podRoot:rotateRelY(t);


    --self.camera:orbit_Y_UP(x3.vec3(0.0), t * 0.1,  math.sin(t * 0.01) * 0, 4);
    self.camera:orbit_Y_UP(x3.vec3(0.0), t * 0.0,  math.sin(t * 0.01) * 0, 5);
    
    local w, h = love.graphics.getDimensions();
    self.camera:setPerspective(90, h/w, 0.5, 1000.0);

    x3.render(self.camera, self.scene, canvas, {
        clearColor = {0,0,0,1}
    });

    local w, h = love.graphics.getDimensions();
    love.graphics.draw(canvas.color, 0, h, 0, 1, -1);
end

local GAME_MODE = {
    MENU = 0,
    PLAY = 1
}

local GameMode = GAME_MODE.MENU;

function MenuViewer:uiupdate()

    local mv = self;

    if (not mv.podEntities) then
        return;
    end

    mv.colors = mv.colors or {};

    local colorPicker = function(label, color, meshes)

        color = mv.colors[label] or color;

        color[1], color[2], color[3] = ui.colorPicker(label, color[1], color[2], color[3], 1, {
            enableAlpha = false
        })

        mv.colors[label] = color;

        for i,name in pairs(meshes) do
            mv.podEntities[name].material.uniforms.u_BaseColor = color;
        end
    end

    colorPicker("Pod Color", x3.hexColor(0x52FFB8), {"pod_pod_geo", "guns_guns_geo"});
    colorPicker("Fin Color", x3.hexColor(0x830A48), {"fin_fin_geo"});
    colorPicker("Glass Color", x3.hexColor(0x4A051C), {"glass_glass_geo"});
    --colorPicker("Laser Color", x3.hexColor(0xFAB2EA), {});

    if (self.clientId and not self.waitingForServer) then
        local start = ui.button("Ready!");

        if (start) then
            self.waitingForServer = true;

            self.client:send({
                kind = "playerReady"
            }, 
            self.clientId,
               mv.colors
            );
        end
    end
end

--function MenuViewer:

function castle.uiupdate()
    if (GameMode == GAME_MODE.MENU) then
        MenuViewer:uiupdate();
    end
end

function GameViewer:init()

    self.numLasers = 0;
    self.laserData = {};

    self.bursts = x3.newAutomap();
    self.damageIndicators = x3.newAutomap();

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

    initPodEntities(self, self.scene);

    local shieldShaderOpts = {
        defines = {
            LIGHTS = 0,
            INSTANCES = 1
        },

        transparent = true,

        fragShade = [[
            vec3 normal = getNormal();
            vec3 toEye = normalize(u_WorldCameraPosition - v_WorldPosition);
            float ia = v_InstanceColor.a;

            if (ia < 0.001) {
                discard;
            }

            float dt = dot(toEye, normal) * 0.5 + 0.5;
            dt = pow(dt, ia);
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

    self.podEntities.shield.renderOrder = 2;
    self.scene:add(self.podEntities.shield);

    --[[
    self.sun = x3.newPointLight({
        color = {1,1,1},
        position = x3.vec3(0, 10, 0),
        intensity = 1
    });

    self.scene:add(self.sun);
]]

    self.camera = x3.newCamera();
    self.camera:setPosition(5,5,5);
    self.UP = x3.vec3(0,1,0);

    self.camera:lookAt(x3.vec3(0,0,0), self.UP);
end

function GameViewer:drawHUD(player)
    local w, h = love.graphics.getDimensions();

    player = player or {shield = 1, health = 1};

    love.graphics.setLineWidth(1);
    love.graphics.setColor(1,1,1,0.5);
    love.graphics.circle("line", w * 0.5 - 4, h * 0.5, 3);
    love.graphics.circle("line", w * 0.5 + 4, h * 0.5, 3);

    local ox = 10;
    local sx = 100;
    local sy = 10;

    love.graphics.setColor(1,1,1,1);

    love.graphics.setColor(SHIELD_COLOR);
    love.graphics.rectangle("line", ox, h - 100, sx, sy)
    love.graphics.setColor(SHIELD_COLOR[1], SHIELD_COLOR[2], SHIELD_COLOR[3], 0.8);
    love.graphics.rectangle("fill", ox, h - 100, sx * player.shield, sy)

    love.graphics.setColor(HEALTH_COLOR);
    love.graphics.rectangle("line", ox, h - 80, sx, sy)
    love.graphics.setColor(HEALTH_COLOR[1], HEALTH_COLOR[2], HEALTH_COLOR[3], 0.8);
    love.graphics.rectangle("fill", ox, h - 80, sx * player.health, sy)

end

function GameViewer:draw(player)
    x3.render(self.camera, self.scene, self.canvas, {
        clearColor = {0,0,0,1}
    });

    local w, h = love.graphics.getDimensions();
    love.graphics.draw(GameViewer.canvas.color, 0, h, 0, 1, -1);

    self:drawDamageIndicators();
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

function GameViewer:addBurst(pos, scale)

    Audio.Sparks:setNextPosition(pos:components());
    Audio.Sparks:play();



    local b = x3.newEntity(
        Meshes.Particle,
        Materials.Particle
    );

    if (scale > 2.0) then
        b.material = Materials.DeathParticle;  
    end

    b:setPosition(pos);
    b.burstAge = 0;
    b.burstScale = scale;

    b:setNumInstances(30);
    
    for i = 1,b:getNumInstances() do
        local ins =  b:getInstance(i);

        local p = ins:getPosition();
        p:fromSphere(math.random() * 6, math.random() * 6, 0.01);
        ins:setPosition(p);
        ins:setScale(0.1 * scale);
        p:normalize();
        ins:orient(p, Y_AXIS);
    end

    self.scene:add(b);

    self.bursts:add(b);

end

function GameViewer:updateBursts(dt)

    self.bursts:filter(function(b)
        
        for i = 1,b:getNumInstances() do
            b:getInstance(i):moveRelZ(-dt * 10 * b.burstScale);
        end

        b.burstAge = b.burstAge + dt;

        if (b.burstAge > 0.2) then
            self.scene:remove(b);
            return true;
        end
    end)

end

function GameViewer:updateLasers(dt)

    local players = self.client.players;

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

            local pos = laser.ray:at(laser.dist);
            if (laser.hitSound) then
                laser.hitSound:setNextPosition(pos:components());
                laser.hitSound:play();

                if (laser.hitSound == Audio.Shield_Hit) then
                    if (players[laser.hitId]) then
                        players[laser.hitId].shieldAlpha = 1.0;
                    end
                end
            end

            local burstScale = 1.0;

            if (laser.hitId) then
                local player = players[laser.hitId];
                if (player) then
                    player.shield = player.shield - laser.shieldDmg;
                    player.health = player.health - laser.healthDmg;

                    if (player.shield < 0.0) then
                        player.shield = 0.0;
                    end

                    if (player.health <= 0) then
                        player.health = 0.0;
                        burstScale = 3.0;
                    end
                    player.shieldRechargeTime = love.timer.getTime() + TIME_TO_SHIELD_RECHARGE;
                end
            end

            self:addBurst(pos, burstScale);
        end
    end
end

function GameViewer:update(dt)

    --self.sun:copyPosition(self.camera);
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

    if (numPlayers == 0) then
        return;
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
                
                if (v3tmp:distancesq(instance:getPosition()) < 5.0) then
                    instance:lerp(v3tmp, math.min(dt * 10, 1.0));
                    instance:slerp(qtmp, math.min(dt * 10, 1.0));
                else
                    instance:setPosition(v3tmp);
                    instance:setRotation(qtmp);
                end
            else
                instance:copyPosition(self.camera);
                instance:copyRotation(self.camera);
            end

            if (name == "fin_fin_geo") then
                instance:setColor(player.colors["Fin Color"]);
            elseif (name == "pod_pod_geo" or name == "guns_guns_geo") then
                instance:setColor(player.colors["Pod Color"]);
            elseif (name == "glass_glass_geo") then
                instance:setColor(player.colors["Glass Color"]);
            elseif (name == "shield") then
                player.shieldAlpha = player.shieldAlpha or player.shield;
                local s = math.max(1.0, dt * 5);
                player.shieldAlpha = (1.0 - s) * player.shieldAlpha + player.shield * s;
                instance:setAlpha(player.shieldAlpha);
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

function GameViewer:addLaser(id, ray, dist, hitId, shieldDmg, healthDmg)

    self.numLasers = (self.numLasers or 0) + 1;

    local hitSound = nil;

    if (hitId)  then
        local hitPlayer = self.client.players[hitId];

        if (hitPlayer and shieldDmg > 0) then
            hitSound = Audio.Shield_Hit;
        else
            hitSound = Audio.Pod_Hit;
        end
    end

    self.laserData[id] = {
        ray = ray:clone(),
        dist = dist,
        t = 0,
        hitSound = hitSound,
        shieldDmg = shieldDmg,
        healthDmg = healthDmg,
        hitId = hitId
    };

    Audio.Laser:setNextPosition(ray.origin:components());

    local vx, vy, vz = ray.direction.x * LASER_SPEED, ray.direction.y * LASER_SPEED, ray.direction.z * LASER_SPEED;

    Audio.Laser:setNextVelocity(vx, vy, vz);
    Audio.Laser:play();

end

function GameViewer:drawDamageIndicators(dt)

    local now = love.timer.getTime();

    local w, h = love.graphics.getDimensions();

    local rad = math.min(w,h) * 0.5;
    local arcdist = rad * 0.15;

    local bloodSum = 0.0;

    self.damageIndicators:filter(function(indicator)
        
        local t = (now - indicator.time);
        
        if (t > 1.0) then
            return true;
        end

        if (t < 0.0) then
            return false;
        end

        --[[
        if (not indicator.dmgApplied) then
            indicator.dmgApplied = true;
            local player = self.client.players[self.client.clientId]; 
            player.shield = player.shield - indicator.shieldDmg;
            player.health = player.health - indicator.healthDmg;
        end
        ]]

        bloodSum = math.max(1.0-t, bloodSum);

        local sx, sy, sz = indicator.sx, indicator.sy, indicator.sz;
        local c = indicator.color;

        --Roughly Behind camera
        if (sz > -0.3) then
            love.graphics.setLineWidth(4);
            local angle = math.atan2(sx, sy) + math.pi * 0.5;
            love.graphics.setColor(c[1], c[2], c[3], 1.0 - t);

            local cx = math.cos(angle + math.pi) * (rad) + w * 0.5;
            local cy = math.sin(angle + math.pi) * (rad) + h * 0.5;

            love.graphics.arc("fill", cx, cy, arcdist, angle - 0.4, angle + 0.4, 10);
            --love.graphics.arc("line", cx, cy, arcdist, angle - 0.1, angle + 0.1, 10);
        end

    end);

    if (bloodSum > 0.0001) then
        love.graphics.setColor(HEALTH_COLOR[1], HEALTH_COLOR[2], HEALTH_COLOR[3], bloodSum * 0.5);
        love.graphics.rectangle("fill", 0,0,w, h);
    end


    self.whiteoutTime = self.whiteoutTime or -1000;
    local whiteoutT = (love.timer.getTime() - self.whiteoutTime) / 4.0;

    if (whiteoutT < 1.0 and whiteoutT > 0.0) then
        love.graphics.setColor(1,1,1,1-whiteoutT)
        love.graphics.rectangle("fill", 0,0,w, h);

        self.client.players[self.client.clientId].health = 1.0
        self.client.players[self.client.clientId].shield = 1.0
    end

end

function GameViewer:showDamage(hitPos, playerData, delay, shieldDmg, healthDmg)

    local hitDir = hitPos:clone();
    hitDir:sub(self.camera:getPosition());
    hitDir:normalize();

    local sx = hitDir:dot(self.camera:getRelXAxis());
    local sy = hitDir:dot(self.camera:getRelYAxis());
    local sz = hitDir:dot(self.camera:getRelZAxis());

    local color = SHIELD_COLOR;

    if (healthDmg > 0) then
        color = HEALTH_COLOR;
    end

    self.damageIndicators:add({
        sx = sx,
        sy = sy,
        sz = sz,
        color = color,
        time = love.timer.getTime() + delay
    });

end

local GameplayController = {};

local v3tmp = x3.vec3(0.0);

function GameClient:sendPlayerState()
    if (self.clientId and self.players[self.clientId]) then
    
        local player = self.players[self.clientId];
        local pos = GameViewer.camera:getPosition();
        local quat = GameViewer.camera:getRotation();

        self:send({
            kind = 'playerUpdate',
        }, self.clientId, {
            pos = {pos.x, pos.y, pos.z},
            rot = {quat.x, quat.y, quat.z, quat.w},
            shield = player.shield,
            health = player.health
        });
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

    --print("hitd", dist);

    --GameViewer:addLaser(id, fireRay, dist or 50, hitId);
        
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

    --[[
    local arenaSphere = x3.newEntity(
        Assets.Spheroid.mesh,
        x3.material.newLit({
            baseColor = {1,1,1},
            hemiColors = {x3.COLOR.GRAY5, x3.COLOR.GRAY9},
            --emissiveColor = {0.3, 0.3, 0.3},
            --baseTexture = Images.Checker,
            --emissiveTexture = Images.Checker
        })
    );
]]

--[[
    local arenaSphere = x3.newEntity(
        --x3.mesh.newSphere(ARENA_RADIUS, 24, 24, true),
        Assets.Spheroid.meshesByName.spheroid_lights_lights_geo,
        x3.material.newLit({
            baseColor = {1,1,1},
            hemiColors = {x3.COLOR.GRAY5, x3.COLOR.GRAY9},
            emissiveColor = x3.COLOR.GRAY5,
            --baseTexture = Images.Checker,
            --emissiveTexture = Images.Checker
        })
    );
]]


    --[[
    local arenaSphere2 = x3.newEntity(
        Assets.Spheroid.meshesByName.sphere_sphere_geo,
        x3.material.newLit({
            baseColor = x3.COLOR.GRAY9,
            specularColor = x3.COLOR.GRAY9,
            shininess = 100,
            --hemiColors = {x3.COLOR.GRAY4, x3.COLOR.GRAY6},
            --emissiveColor = {0.3, 0.4, 0.8},
            --baseTexture = Images.Checker,
            --emissiveTexture = Images.Checker
        })
    );

    --arenaSphere:setScale(ARENA_RADIUS);
    arenaSphere2:setScale(ARENA_RADIUS);

    --arenaRoot:add(arenaSphere);
    arenaRoot:add(arenaSphere2);

    local rl = x3.newPointLight({
        color = x3.hexColor(0x931621),
        intensity = 10,
        position = x3.vec3(0, ARENA_RADIUS * 0.9, 0)
    });

    local gl = x3.newPointLight({
        color = x3.hexColor(0x33FFAA),
        intensity = 10,
        position = x3.vec3(-ARENA_RADIUS * 0.63, -ARENA_RADIUS * 0.63, 0)
    });

    local bl = x3.newPointLight({
        color = x3.hexColor(0x2E5EAA),
        intensity = 10,
        position = x3.vec3(ARENA_RADIUS * 0.63, -ARENA_RADIUS * 0.63, 0)
    });


    arenaRoot:add(rl);
    arenaRoot:add(gl);
    arenaRoot:add(bl);
    ]]


    local arenaShaderOpts = {
        defines = {
            LIGHTS = 0,
            INSTANCES = 1
        },

        fragHead = [[
            extern float u_AlphaMin;
            extern float u_AlphaMax;
        ]],

        transparent = true,

        fragShade = [[
            float distPlayer = length(v_WorldPosition - u_WorldCameraPosition);
            highp float alpha = mix(u_AlphaMax, u_AlphaMin, min(1.0, distPlayer/100.0));

            if (u_AlphaMax < 0.8)
                alpha *= 0.9 + 0.1 * sin((v_WorldPosition.x + v_WorldPosition.z) * 20.0 + u_Time * 5.0);
            outColor = vec4(1.0, 1.0, 1.0, alpha);
        ]]
    };

    local panels = x3.newEntity(
        Assets.Spheroid.meshesByName.hc_panels_pns_geo,
        --x3.mesh.newSphere(1.0, 24, 24, true),

        x3.material.newCustom(
            x3.shader.newCustom(arenaShaderOpts), 
            {
                u_AlphaMin = 0.0,
                u_AlphaMax = 0.7
            } 
        )
    );

    panels.renderOrder = 1;

    local beams = x3.newEntity(
        Assets.Spheroid.meshesByName.hc_beams_bms_geo,
        --x3.mesh.newSphere(1.0, 24, 24, true),

        x3.material.newCustom(
            x3.shader.newCustom(arenaShaderOpts), 
            {
                u_AlphaMin = 0.1,
                u_AlphaMax = 1.0
            } 
        )
    );

    beams.renderOrder = 1;

    panels:setScale(ARENA_RADIUS);
    beams:setScale(ARENA_RADIUS);

    arenaRoot:add(panels);
    arenaRoot:add(beams);

    GameViewer.scene:add(arenaRoot);

end

function GameClient:start()
    print("initing...")
    GameViewer:init();
    MenuViewer:init();

    MenuViewer.client = self;
    GameViewer.client = self;

    GameViewer:resize();
    self:init();
    print("inited");


    self.timer = x3.newTimer();
    self.collider = x3.newCollider();
    self.laserId = 0;

    self:initArena();

    self.velocity = x3.vec3(0.0);

    self:resetPlayer();

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

    
    --GameViewer.players = self.players;
end

function GameClient:keypressed(key)

    if (GameMode == GAME_MODE.PLAY) then
        if (key == "space") then
            love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
        end

        if (key == "r") then
            self:resetPlayer();
        end
    end

    --DEBUG
    if (key == "return") then
        self:startPlaying();
    end
end

function GameClient:removePlayer(clientId)
    self.collider:remove("p"..clientId);
end

function GameClient:connect()
    MenuViewer.clientId = self.clientId;
end

function GameClient:inMenu()
    return GameMode == GAME_MODE.MENU;
end

local rayTemp = x3.ray();
function GameClient:handleLaser(rayData, dist, hitId, shieldDmg, healthDmg)

    if (self:inMenu()) then
        return;
    end

    self.laserId = self.laserId + 1;
    rayTemp:deserialize(rayData);
    GameViewer:addLaser(self.laserId, rayTemp, dist, hitId, shieldDmg, healthDmg);

    local delay = dist / LASER_SPEED;

    if (hitId and hitId == self.clientId) then
        GameViewer:showDamage(rayTemp:at(dist), self.players[self.clientId], delay, shieldDmg, healthDmg);
    end
end

--[[
function GameClient:handleDamage(clientId, shieldDmg, healthDmg)

    if (clientId == self.clientId) then

        

    end
end]]

local ZERO = x3.vec3(0.0);

function GameClient:die()
    GameViewer.whiteoutTime = love.timer.getTime();
    self:resetPlayer();
end

function GameClient:resetPlayer()
    local pos = x3.vec3();
    pos:fromSphere(math.random() * 6, math.random() * 6, ARENA_RADIUS - 3);
    GameViewer.camera:setPosition(pos);
    GameViewer.camera:lookAt(ZERO, Y_AXIS);

    local player = self.players[self.clientId];

    if (player) then
        player.health = 1.0;
        player.shield = 1.0;
    end
end


local tempPosition = x3.vec3();
function GameClient:update(dt)

    if (GameMode == GAME_MODE.MENU) then
        return;
    end

    --[[
    if (self.timer:ezCooldown("test", 1.0)) then
        local tp = x3.vec3(0.0, 100.0, 0.0);
        --tp:copy(GameViewer.camera:getPosition());
        --tp:addScaled(GameViewer.camera:getRelZAxis(), -2.0);
        GameViewer:showDamage(tp, {shield = 1.0})
    end
    ]]
    local cam = GameViewer.camera;

    local k = love.keyboard.isDown;

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
        cam:rotateRelZ(-dt * 2);
    elseif k("a")  then
        cam:rotateRelZ(dt * 2);
    end


    local me = self.players[self.clientId];
    me.shieldRechargeTime = me.shieldRechargeTime or 0;

    if (love.timer.getTime() - me.shieldRechargeTime > 0.0) then
        me.shield = me.shield + dt * SHIELD_RECHARGE_RATE;
        me.shield = math.min(1.0, me.shield);
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
    

    --Update audio listener
    
    love.audio.setPosition(cam:getPosition():components());

    local forward = cam:getRelZAxis();
    forward:invert();
    local fx, fy, fz = forward:components();
    local ux, uy, uz = cam:getRelYAxis():components();

    love.audio.setOrientation(fx,fy,fz,ux,uy,uz);
    love.audio.setVelocity(self.velocity:components());

end


function GameClient:onPlayerAdded(clientId, player)
    if (clientId == self.clientId) then
        self:startPlaying();
    end
end


function GameClient:startPlaying()

    if (GameMode ~= GAME_MODE.PLAY) then
        GameMode = GAME_MODE.PLAY; 
        GameViewer.scene:add(MenuViewer.stars);
    end
    print("start?");
end

function GameClient:mousepressed()
    --self:fire();
end

function GameClient:mousemoved(x, y, dx, dy)
    --GameViewer.camera:rotateAxis(GameViewer.UP, dx * 0.01);
    --GameViewer.camera:rotateLocalX(dy * 0.01);
    if (GameMode == GAME_MODE.MENU) then
        return;
    end

    local scale = 0.01;
    GameViewer.camera:rotateRelX(-dy * scale);
    GameViewer.camera:rotateRelY(-dx * scale);
end

function GameClient:draw()
    if (GameMode == GAME_MODE.MENU) then
        MenuViewer:draw(GameViewer.canvas);
        return;
    end

    local me = self.players[self.clientId];
    GameViewer:draw(me);
end