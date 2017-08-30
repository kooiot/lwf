local skynet = require 'skynet'
local sharedata = require 'skynet.sharedata'

local class = {}

local function get_time()
	local now = skynet.time()
	return os.time() + (now - math.floor(now))
end

function class:get(key)
	local key = self.name.."."..key
	local v = sharedata.query(key)
	if not v then
		return nil, "Not exists"
	end

	if v.exptime > get_time() then
		return nil, "Expired"
	end
	return v.value, v.flags
end

function class:get_stale(key)
	local key = self.name.."."..key
	local v = sharedata.query(key)
	if not v then
		return nil, "Not exists"
	end
	return v.value, v.flags
end

function class:set(key, value, exptime, flags)
	local key = self.name.."."..key
	return sharedata.update(key, {
		value = value,
		exptime = exptime,
		flags = flags,
	})
end

function class:safe_set(key, value, exptime, flags)
	if not self:get(key) then
		return self:set(key, value, exptime, flags)
	else
		return nil
	end
end

function class:add(key, value, exptime, flags)
	return sharedata.new(key, {
		value = value,
		exptime = exptime,
		flags = flags,
	})
end

function class:safe_add(key, value, exptime, flags)
	return self:add(key, value, exptime, flags)
end

function class:replace(key, value, exptime, flags)
	return self:set(key, value, exptime, flags)
end

function class:delete(key)
	local key = self.name.."."..key
	return sharedata.delete(key)
end

function class:incr(key, value, init)
	local key = self.name.."."..key
	local v = sharedata.query(key)
	if v then
		return sharedata.update(key, v.value + value, v.exptime, v.flags)
	else
		if not init then
			return nil, "not found"
		end
		return self:add(key, init + value)
	end
end

function class.new(name)
	return setmetatable({name=name}, {__index=class})
end

return class
