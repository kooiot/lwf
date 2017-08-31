local skynet = require 'skynet'
local sharedata = require 'skynet.sharedata'

local class = {}

local function get_time()
	local now = skynet.time()
	return os.time() + (now - math.floor(now))
end

function class:gen_key(key)
	return 'shared.'..self.name..'.'..key
end

function class:get(key)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if not v then
		return false, "not exists"
	end

	if v.exptime and v.exptime > get_time() then
		return false, "expired"
	end
	return v.value, v.flags
end

function class:get_stale(key)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if not v then
		return false, "not exists"
	end
	return v.value, v.flags, v.exptime and v.exptime > get_time() or false
end

function class:set(key, value, exptime, flags)
	local kn = self:gen_ken(key)

	if not value then
		local r, err = sharedata.delete(kn)
		if r then
			self:pop_key(key)
		end
		return true, 'ok', false
	end

	local exptime = (exptime > 0) and (exptime + get_time()) or  nil
	local flags = flags ~= 0 and nil or flags

	local r = sharedata.query(kn)
	local f = r and 'update' or 'new'

	local r, err = sharedata[f](kn, {
		value = value,
		exptime = exptime,
		flags = flags,
	})
	if not r then
		return false, err
	end
	if r and f == 'new' then
		self:push_key(key)
	end
	return true, 'ok', false
end

function class:safe_set(key, value, exptime, flags)
	return self:set(key, value, exptime, flags)
end

function class:add(key, value, exptime, flags)
	local kn = self:gen_ken(key)
	local exptime = (exptime > 0) and (exptime + get_time()) or  nil
	local flags = flags ~= 0 and nil or flags
	local v = sharedata.query(kn)

	if not v then
		local r, err = sharedata.new(kn, {
			value = value,
			exptime = exptime,
			flags = flags,
		})
		if not r then
			return false, err
		end
		self:push_key(key)
		return true, 'ok', false
	end
	return false, 'exists'
end

function class:safe_add(key, value, exptime, flags)
	return self:add(key, value, exptime, flags)
end

function class:replace(key, value, exptime, flags)
	local kn = self:gen_ken(key)
	local exptime = (exptime > 0) and (exptime + get_time()) or  nil
	local flags = flags ~= 0 and nil or flags
	local v = sharedata.query(kn)

	if v then
		local r, err = sharedata.update(kn, {
			value = value,
			exptime = exptime,
			flags = flags,
		})
		if not r then
			return false, err
		end
		return true, 'ok', false
	end
	return false, 'not found'
end

function class:delete(key)
	local kn = self:gen_ken(key)
	local r, err = sharedata.delete(kn)
	if r then
		self:pop_key(key)
	end
end

function class:incr(key, value, init)
	if type(value) ~= 'number' then
		return nil, "not a number"
	end
	local init = tonumber(init)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if v then
		v.value = v.value + value
		local r, err = sharedata.update(kn, v)
		if r then
			return v.value, 'ok', false
		end
		return nil, err, false
	else
		if not init then
			return nil, "not found"
		end
		local value = init + value
		local r, err = sharedata.new(kn, { value=value })
		if r then
			self:push_key(key)
			return value, 'ok', false
		end
		return nil, err
	end
end

function class:lpush(key, value)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if v and type(v.value) ~= 'table' then
		return nil, "value not a list"
	end
	if not v then
		local r, err = sharedata.new(kn, { value={ value } })
		if not r then
			return nil, err
		end
		self:push_key(key)
		return 1
	else
		table.insert(v.value, 1, value)
		local r, err = sharedata.update(kn, v)
		if not r then
			return nil, err
		end
		return #v.value
	end
end

function class:rpush(key, value)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if v and type(v.value) ~= 'table' then
		return nil, "value not a list"
	end
	if not v then
		local r, err = sharedata.new(kn, { value={ value } })
		if not r then
			return nil, err
		end
		self:push_key(key)
		return 1
	else
		table.insert(v.value, value)
		local r, err = sharedata.update(kn, v)
		if not r then
			return nil, err
		end
		return #v.value
	end
end

function class:lpop(key)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if not v then
		return nil, 'not exists'
	end
	local value = v.value
	if type(value) ~= 'table' then
		return nil, "value not a list"
	end
	local val = table.remove(value, 1)
	sharedata.update(kn, v)
	return val
end

function class:rpop(key)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if not v then
		return nil, 'not exists'
	end
	local value = v.value
	if type(value) ~= 'table' then
		return nil, "value not a list"
	end
	local val = table.remove(value)
	sharedata.update(kn, v)
	return val
end

function class:llen(key)
	local kn = self:gen_ken(key)
	local v = sharedata.query(kn)
	if not v then
		return nil, 'not exists'
	end
	local value = v.value
	if type(value) ~= 'table' then
		return nil, "value not a list"
	end
	return #value
end

function class:flush_all()
	local kn = 'shared.'..self.name
	local keys = sharedata.query(kn)
	if not keys then
		return
	end
	for k, _ in pairs(keys) do
		local kn = self:gen_ken(k)
		local v = assert(sharedata.query(kn))
		v.exptime = v.exptime - 60
		sharedata.update(kn , v)
	end
end

function class:flush_expired()
	local kn = 'shared.'..self.name
	local keys = sharedata.query(kn)
	if not keys then
		return
	end
	local count = 0
	for k, _ in pairs(keys) do
		local kn = self:gen_ken(k)
		local v = assert(sharedata.query(kn))
		if v.exptime < get_time() then
			local r, err = sharedata.delete(kn)
			if r then
				self:pop_key(k)
				count = count + 1
			end
		end
	end
	return count
end

function class:get_keys()
	local v = sharedata.query('shared.'..self.name)
	local keys = {}
	for k, _ in pairs(v) do
		keys[#keys + 1] = k
	end
	return keys
end

function class:push_key(key)
	local kn = 'shared.'..self.name
	local keys = sharedata.query(kn)
	if keys then
		keys[key] = true
		sharedata.update(kn, keys)
	else
		sharedata.new(kn, {key})
	end
end

function class:pop_key(key)
	local kn = 'shared.'..self.name
	local keys = sharedata.query(kn)
	if keys then
		keys[key] = nil
		sharedata.update(kn, keys)
	end	
end

function class.new(name)
	return setmetatable({name=name}, {__index=class})
end

return class
