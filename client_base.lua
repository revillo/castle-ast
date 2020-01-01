local BASE_URL = castle.game.getCurrent().url:gsub("\\","/");
local BASE_DIR;

do
    local index = BASE_URL:find("/[^/]*$");
    BASE_DIR = string.sub(BASE_URL, 1, index-1);
end

local x3 = require(BASE_DIR.."/x3/x3.lua");

local Game = require(BASE_DIR.."/multiplayer-tests/client.lua");

local GameClient = Game.Client;
local GameCommon = Game.Common;

return {
    x3 = x3,
    GameClient = GameClient,
    GameCommon = GameCommon
}
