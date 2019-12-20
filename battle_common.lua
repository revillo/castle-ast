function GameCommon:init()
    self.players = {};
end


function GameCommon:define()

    self:defineMessageKind('fullState', {
        reliable = true,
        channel = 0,
        selfSend = false,
    });

    self:defineMessageKind('addPlayer', {
        reliable = true,
        channel = 0,
        selfSend = true,
        to = 'all'
    });

    self:defineMessageKind('killPlayer', {
        reliable = true,
        selfSend = true,
        channel = 0,
        to = 'all'
    });
    
    self:defineMessageKind('removePlayer', {
        to = 'all',
        reliable = true,
        channel = 0,
        selfSend = true,
    })

     -- Client sends position updates for its own player, forwarded to all
     self:defineMessageKind('playerUpdate', {
        reliable = false,
        channel = 1,
        rate = 20,
        selfSend = false,
        forward = true,
    });

    self:defineMessageKind('laserHit', {
        reliable = true,
        channel = 0,
        selfSend = false,
        forward = true
    });

    self:defineMessageKind('laserMiss', {
        reliable = false,
        channel = 1,
        selfSend = false,
        forward = true
    });

    self:defineMessageKind('damagePlayer', {
        reliable = true,
        channel = 0,
        selfSend = true,
        to = 'all'
    });

end

function GameCommon.receivers:playerUpdate(time, clientId, player)
    local mPlayer = self.players[clientId];

    mPlayer.pos = player.pos;
    mPlayer.rot = player.rot;
end

function GameCommon.receivers:addPlayer(time, clientId, player)
    self.players[clientId] = player
    
    if(self.onPlayerAdded) then
        self:onPlayerAdded(clientId, player)
    end

    print("Add Player", clientId);
end

function GameCommon.receivers:removePlayer(time, clientId, x, y, z)
    self.players[clientId] = nil;
    
    if (self.removePlayer) then
        self:removePlayer(clientId);
    end

    print("Remove Player", clientId);
end

function GameCommon.receivers:killPlayer(time, clientId)

    self.players[clientId].shield = 1;
    self.players[clientId].health = 1;
    self.players[clientId].pos = {0,0,0};


    if (self.client) then
        if (self.clientId == clientId) then
            self:resetPlayer();
        end
    end
    print("Kill Player", clientId);
end

function GameCommon.receivers:laserMiss(time, client, ray, dist, hitId)
    if (self.client) then
        self:handleLaser(ray, dist);
    end
end

function GameCommon.receivers:laserHit(time, client, ray, dist, hitId)
    local player = self.players[hitId];

    if (player) then

        local shieldDmg = 0;
        local healthDmg = 0;

        if (player.shield > 0) then
            shieldDmg = 0.5;
        else
            healthDmg = 0.5;
        end

        if (self.server) then
            self:send({kind = 'damagePlayer'}, hitId, shieldDmg, healthDmg);
        end

        print("Damage Player", hitId, shieldDmg, healthDmg);
    end

    if (self.client) then
        print("over here");
        self:handleLaser(ray, dist);
    end
end

function GameCommon.receivers:damagePlayer(time, clientId, shieldDmg, healthDmg)
    local player = self.players[clientId];

    player.shield = math.max(0, player.shield - shieldDmg);
    player.health = math.max(0, player.health - healthDmg);

    if (player.health <= 0.0 and self.server) then
        self:send({kind = 'killPlayer'}, clientId);
    end
end

function GameCommon.receivers:fullState(time, state)
    self.players = state.players;
end