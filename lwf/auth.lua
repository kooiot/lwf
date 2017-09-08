local logger = require 'lwf.logger'

local function create_user(lwf, user, meta)
	local user = {
		lwf = lwf,
		user = user,
		meta = meta or {},
		-- TODO: more user meta
		logout = function(self)
			assert(self and self.lwf)
			lwf.auth:clear_identity(self.user)
			self.user = "Guest" 
			lwf.session.data.user = self.user
			lwf.session:save()
		end
	}
	return user
end

local function identity(lwf, app, auth)
	local session = lwf.ctx.session
	local username = session:get('username')
	local identity = session:get('identity')
	if username and identity then
		--logger:info('Identity '..username..' '..identity)
		local r, err = auth:identity(username, identity)
		if r then
			local meta = auth:get_metadata(username)
			--logger:info('Identity OK '..username..' '..identity)
			-- Create user object
			local user = create_user(lwf, app, username, meta)
			lwf.ctx.user = user
		else
			--logger:info('Identity Failure '..username..' '..identity)
			-- Clear session data
			session:clear()
		end
	else
		--[[
		local err = 'Identity lack of '
		if not username then
			err = err..'username'
		end
		if not identity then
			err = err..'identity'
		end
		logger:debug(err)
		]]--
	end
end

local function wrapper_auth(lwf, app, auth)
	assert(auth)
	local authenticate = auth.authenticate
	auth.authenticate = function(self, username, password, ...)
		local r, err = authenticate(self, username, password, ...)
		if not r then
			return nil, err
		end
		local identity, err = self:get_identity(username)
		if not identity then
			return nil, err
		end

		local session = lwf.ctx.session
		session:set('username', username)
		session:set('identity', identity)
		--logger:info(username, ', ', identity)
		local meta = self:get_metadata(username)

		local user = create_user(lwf, app, username, meta)
		lwf.ctx.user = user
		return true
	end
	return auth
end

return function (lwf, cfg)
	assert(cfg)
	local auth = nil
	local cfgt = {}
	if type(cfg) == 'string' then
		auth = require('lwf.auth.'..cfg)
	elseif type(cfg) == 'table' then
		local an = cfg.name
		auth = require('lwf.auth.'..an)
		cfgt = cfg
	elseif type(cfg) == 'function' then
		auth = { new = cfg }
	else
		assert('Incorrect configuration for auth')
	end
	assert(auth)
	return {
		create = function()
			local auth = auth.new(lwf, cfgt)
			if auth.startup then
				auth:startup()
			end
			identity(lwf, auth)
			return wrapper_auth(lwf, auth)
		end,
		close = function(auth)
			if auth.teardown then
				auth:teardown()
			end
		end
	}
end
