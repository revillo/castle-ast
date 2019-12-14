Sound = {}

function Sound:new(filename, cacheSize) 
  
  local o = {};
  o.sources = {};
  o.cacheSize = cacheSize or 2;
  o.sources[1] = love.audio.newSource(filename, "static");
  o.index = 1;
  o.volume = 1;
  for i = 2, o.cacheSize do
    o.sources[i] = o.sources[1]:clone();
  end

  o.cooldown = nil;
  o.lastPlayed = -10;
  
  self.__index = self;
  setmetatable(o, self);
  return o;

end

function Sound:setCooldown(t)
  self.cooldown = t;
end

function Sound:resetCooldown()
  self.lastPlayed = -1;
end

function Sound:play()

  if (not self.cooldown or (love.timer.getTime() - self.lastPlayed) > self.cooldown) then
    self.sources[self.index]:play();
    self.index = (self.index % self.cacheSize) + 1;
    self.lastPlayed = love.timer.getTime();
  end

end

function Sound:stop()

  for i = 1, self.cacheSize do
    self.sources[i]:stop();
  end

end



function Sound:setNextVolume(vlm)  
  self.sources[self.index]:setVolume(vlm);
end


function Sound:setVolume(vlm)
  
  for i = 1, self.cacheSize do
    self.sources[i]:setVolume(vlm);
  end
  
end

function Sound:setLooping(shouldLoop)

  for i = 1, self.cacheSize do
    self.sources[i]:setLooping(shouldLoop);
  end
  
end


return Sound;
