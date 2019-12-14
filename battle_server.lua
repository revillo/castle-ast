--file://c:/castle/ast/battle_server.lua

USE_LOCAL_SERVER = true;

local mods = require("server_base");

GameServer = mods.GameServer;
GameCommon = mods.GameCommon;

require("battle_common");


function GameServer:start()
    self:init();

    self.players["test"] = {
        pos = {0, 0, 0},
        rot = {0,0,0,1},
        health = 1,
        shield = 1
    }
end


function GameServer:connect(clientId)
    self:send({
        to = clientId,
        kind = 'fullState',
    }, {
        players = self.players
    });


    self:send({ kind = 'addPlayer' }, clientId, {
        pos = {math.random() * 10, math.random() * 10, math.random() * 10},
        rot = {0,0,0,1},
        health = 1,
        shield = 1
    });

    print("Connected", clientId);

end

function GameServer:disconnect(clientId)
    self:send({ kind = 'removePlayer' }, clientId)
    
    print("Disconnected", clientId);
end