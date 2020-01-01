local BASE_URL = castle.game.getCurrent().url:gsub("\\","/");
local BASE_DIR;

do
    local index = BASE_URL:find("/[^/]*$");
    BASE_DIR = string.sub(BASE_URL, 1, index-1);

    print(BASE_URL);
end

local Game = require(BASE_DIR.."/multiplayer-tests/server.lua");

return {
    GameCommon = Game.Common,
    GameServer = Game.Server
}
