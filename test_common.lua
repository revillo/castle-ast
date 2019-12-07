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
end

function GameCommon.receivers:playerUpdate(time, clientId, player)
    local mPlayer = self.players[clientId];

    mPlayer.pos = player.pos;
    mPlayer.quat = player.quat;
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
end

function GameCommon.receivers:fullState(time, state)
    self.players = state.players;
end