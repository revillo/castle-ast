--file://c:/castle/ast/test_client.lua

--file://c:/castle/ast/x3/x3test_obj_scene.lua

local mods = require("client_base");

x3 = mods.x3;
GameClient = mods.GameClient;
GameCommon = mods.GameCommon;

print("loaded");
require("test_common.lua");

local GameViewer = {
    scene = x3.newEntity()
};

function GameViewer:init()
 
    self.boxes = x3.newEntity(
        x3.mesh.newBox(1,1,1),
        x3.material.newLit({
            baseColor = {0.9, 0.9, 1.0}
        })
    );
    self.scene:add(self.boxes);

    self.boxes:setPosition(0,0,0);
    self.boxes:setNumInstances(900);
 
    local i = 0;
    for x = 1,30 do for y = 1,30 do
        i = i + 1;
        self.boxes:getInstance(i):setPosition(x - 15, math.random() * 10, y - 15);
    end
    end

    
    self.balls = x3.newEntity(
        x3.mesh.newSphere(1,16,16),
        x3.material.newLit({
            baseColor = {1.0, 0.0, 0.0},
            emissiveColor = {0.5, 0.0, 0.0}
        })
    );

    self.scene:add(self.balls);

    self.sun = x3.newPointLight({
        color = {1,1,1},
        position = x3.vec3(0, 10, 0),
        intensity = 4
    });

    self.scene:add(self.sun);

    self.camera = x3.newCamera();
    self.camera:setPosition(5,5,5);
    self.UP = x3.vec3(0,1,0);

    self.camera:lookAt(x3.vec3(0,0,0), self.UP);
end

function GameViewer:draw()
    x3.render(self.camera, self.scene, self.canvas, {
        clearColor = {0,0,0,1}
    });

    local w, h = love.graphics.getDimensions();
    love.graphics.draw(GameViewer.canvas.color, 0, h, 0, 1, -1);
end

function GameViewer:update(dt)
    self.sun:copyPosition(self.camera);
end


function GameViewer:setPlayers(myId, players)

    local numPlayers = 0;
    for _, _ in pairs(players) do
        numPlayers = numPlayers + 1;
    end

    self.balls:setNumInstances(numPlayers);

    local i = 0;
    for cid, player in pairs(players) do
        i = i + 1;
        local pos = player.pos;
        if (pos and cid ~= myId) then
            self.balls:getInstance(i):setPosition(pos[1], pos[2], pos[3]);
        else
            self.balls:getInstance(i):copyPosition(self.camera);
        end
    end
end

function GameViewer:resize()
    local w,h = love.graphics.getDimensions();
    GameViewer.canvas = x3.newCanvas3D(w,h);
    self.camera:setPerspective(90, h/w, 0.5, 100.0);
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
end

function GameClient:keypressed(key)
    if (key == "space") then
      love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
    end
end

function GameClient:update(dt)

    local k = love.keyboard.isDown;
    local cam = GameViewer.camera;

    if k("s") then
        cam:moveLocalZ(dt * 2);
    elseif k("w") then
        cam:moveLocalZ(-dt * 2);
    end

    if k("d") then
        cam:rotateLocalZ(-dt * 2);
    elseif k("a")  then
        cam:rotateLocalZ(dt * 2);
    end


    if (self.clientId and self.players[self.clientId]) then
        GameViewer:setPlayers(self.clientId, self.players);
        

        local pos = GameViewer.camera:getPosition();
        self:send({
            kind = 'playerUpdate',
        }, self.clientId, {
            pos = {pos.x, pos.y, pos.z}
        })
    end
    

    GameViewer:update(dt);
end

--[[
function GameClient:onPlayerAdded(clientId, player)

end
]]

function GameClient:mousemoved(x, y, dx, dy)
    --GameViewer.camera:rotateAxis(GameViewer.UP, dx * 0.01);
    --GameViewer.camera:rotateLocalX(dy * 0.01);
    local scale = 0.01;
    GameViewer.camera:rotateLocalX(-dy * scale);
    GameViewer.camera:rotateLocalY(-dx * scale);
end

function GameClient:draw()
    GameViewer:draw();
  
end