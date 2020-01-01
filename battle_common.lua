function GameCommon:init()
    self.players = {};
end


function GameCommon:define()

    self:defineMessageKind('fullState', {
        reliable = true,
        channel = 0,
        selfSend = false,
    });

    self:defineMessageKind('playerReady', {
        reliable = true,
        channel = 0,
        selfSend = false,
        forward = false
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
        selfSend = true,
        forward = false
    });

    self:defineMessageKind('laserMiss', {
        reliable = false,
        channel = 1,
        selfSend = true,
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
    mPlayer.shield = player.shield;
    mPlayer.health = player.health;
end

function GameCommon.receivers:addPlayer(time, clientId, player)
    self.players[clientId] = player;
    
    
    if(self.onPlayerAdded) then
        self:onPlayerAdded(clientId, player)
    end

    print("Add Player = ", clientId, player.pos[1], player.pos[2]);
end

function GameCommon.receivers:removePlayer(time, clientId)
    self.players[clientId] = nil;
    
    if (self.removePlayer) then
        self:removePlayer(clientId);
    end

    print("Remove Player", clientId);
end

function GameCommon.receivers:killPlayer(time, clientId)

    self.players[clientId].shield = 1;
    self.players[clientId].health = 1;
    self.players[clientId].pos = {0,-200,0};

    if (self.client) then
        if (self.clientId == clientId) then
            self:die();
        end
    end

    print("Kill Player", clientId);
end

function GameCommon.receivers:laserMiss(time, client, ray, dist, hitId)
    if (self.client) then
        self:handleLaser(ray, dist);
    end
end

local function rayHitClose(ray, dist, player)
    local hx,hy,hz = ray.origin[1] + (ray.direction[1]) * dist,
    ray.origin[2] + (ray.direction[2]) * dist,
    ray.origin[3] + (ray.direction[3]) * dist;

    local dx, dy, dz = hx - player.pos[1], hy - player.pos[2], hz - player.pos[3];

    local distsq = (dx * dx + dy * dy + dz * dz);

    print("Distsq", distsq, player.health);
    return distsq < 4;
end

function GameCommon.receivers:laserHit(time, client, ray, dist, hitId)
    local player = self.players[hitId];

    if (player) then

        local shieldDmg = 0;
        local healthDmg = 0;

        if (player.shield > 0) then
            shieldDmg = 0.2;
        elseif (player.health > 0.0) then
            healthDmg = 0.1;
        end

        if (self.server) then
            --self:send({kind = 'damagePlayer'}, hitId, shieldDmg, healthDmg);
          
            --self:send({kind='laserHit', selfSend=false, to='all'}, client, ray, dist, hitId);
            
            if (rayHitClose(ray, dist, player)) then

                local player = self.players[hitId];

                player.shield = math.max(0, player.shield - shieldDmg);
                player.health = math.max(0, player.health - healthDmg);
    
                for cid, pl in pairs(self.players) do
                    if (cid ~= client) then
                        self:send({kind='laserHit', selfSend=false, to=cid}, client, ray, dist, hitId);
                    end
                end


                if (player.health <= 0.0) then
                    self:send({kind = 'killPlayer'}, hitId);
                end

            end
        else
            self:handleLaser(ray, dist, hitId, shieldDmg, healthDmg);
        end
    end

end



--[[
function GameCommon.receivers:damagePlayer(time, clientId, shieldDmg, healthDmg)
    local player = self.players[clientId];

    player.shield = math.max(0, player.shield - shieldDmg);
    player.health = math.max(0, player.health - healthDmg);

    if (player.health <= 0.0 and self.server) then
        self:send({kind = 'killPlayer'}, clientId);
    end
end
]]

function GameCommon.receivers:fullState(time, state)
    self.players = state.players;
end