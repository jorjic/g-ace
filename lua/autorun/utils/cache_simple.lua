local class = Middleclass

local Cache = gace.Cache
local SimpleCache = class("SimpleCache", Cache)

function SimpleCache:initialize()
	Cache.initialize(self)

	self.cache = {}
end

-- Core methods

function SimpleCache:exists(key)
	return self.cache[key] ~= nil
end
function SimpleCache:get(key)
	return self.cache[key]
end
function SimpleCache:set(key, val, is_raw_set)
	local old_value = self:get(key)

	self.cache[key] = val

	if not is_raw_set then
		self:notifyChangeListeners(key, val, old_value)
	end
end

gace.SimpleCache = SimpleCache