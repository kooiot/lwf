-- Authentification module
--

local md5 = require 'md5'

local _M = {}
local class = {}
local salt = "SimpleAuth"

local function load_auth_file(path)
	local keys = {}
	keys.admin = md5.sumhexa('admin'..salt)

	if not path then
		return keys
	end

	local file, err = io.open(path)
	if file then
		local c = file:read('*a')
		for k, v in string.gmatch(c, "(%w+)=(%w+)") do
			keys[k] = v
		end
	end

	return keys
end

local function save_auth_file(path, keys)
	if not path then
		return nil, "file not configured"
	end

	local file, err = io.open(path, 'w+')
	if not file then
		return nil, err
	end

	for k, v in pairs(keys) do
		file:write(k)
		file:write('=')
		file:write(v)
	end

	file:close()

	return true
end

_M.new = function(lwf, app, cfg)
	local obj = {
		lwf = lwf,
		app = app,
		_file = cfg.file,
		_keys = load_auth_file(cfg.file),
	}

	return setmetatable(obj, {__index=class})
end

function class:authenticate(username, password)
	local md5passwd = md5.sumhexa(password..salt)
	if self._keys[username] and self._keys[username] == md5passwd then
		return true
	end
	return false, 'Incorrect username or password'
end

function class:identity(username, identity)
	local key = username..self._keys[username] or ''
	local dbidentity = md5.sumhexa(key..salt)
	return dbidentity == identity
end

function class:get_identity(username)
	local key = username..self._keys[username] or ''
	return  md5.sumhexa(key..salt)
end

function class:clear_identity(username)
	return true
end

function class:set_password(username, password)
	self._keys[username] = md5.sumhexa(password..salt)
	save_auth_file(self._file, self._keys)
end

function class:add_user(username, password, mt)
	self._keys[username] = md5.sumhexa(password..salt)
	save_auth_file(self._file, self._keys)
end

function class:get_metadata(username, key)
	return nil, 'Meta data is not support by simple auth module'
end

function class:has(username)
	if self._keys[username] then
		return true
	else
		return false
	end
end

return _M
