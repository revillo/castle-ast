--file://c:/castle/ast/test_server.lua

USE_LOCAL_SERVER = true;

local mods = require("server_base");

GameServer = mods.GameServer;
GameCommon = mods.GameCommon;

require("test_common");


function GameServer:start()
    self:init()
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
        quat = {0,0,0,1}
    });

    print("Connected", clientId);

end

function GameServer:disconnect(clientId)
    self:send({ kind = 'removePlayer' }, clientId)
    
    print("Disconnected", clientId);
end