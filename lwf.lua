local util = require 'lwf.util'
local lfs = require 'lfs'

local class = {}

local function load_middleware(route, name)
	local m = require('resty.route.middleware.'..name)
	return m(route)
end

local function create_context(route, context)
	return setmetatable(context or {}, {__index=route})
end

function class:load_config()
	if not self._loaded then
		local resty_route = require 'resty.route'
		local template = require 'resty.template'
		local route = resty_route.new()
		route._NAME = route._NAME or "route"

		local env = setmetatable({
			_NAME = "LWF_ENV",
			route=route,
		}, {__index=_ENV})
		util.loadfile(self._lwf_root..'/config/route.lua', env)

		route:fs(self._lwf_root.."/controller")

		route:on("error", function(self, code) 
			return template.render("view/error.html", create_context(self, {code = code}))
		end)

		self._route = route
		self._session = util.loadfile_as_table(self._lwf_root..'/config/session.lua') or {
			secret = "0cc312cbaedad75820792070d720dbda"
		}
		self._session['cipher'] = 'none'
		for k,v in pairs(self._session) do
			ngx.var['session_'..k] = v
		end

		self._loaded = true
	end
	return self._route
end

function class:handle(...)
	local lngx = self._ngx
	if lngx then
		lngx:bind(...)
		_ENV.ngx = lngx
	end

	local route = self:load_config()

	local template = require 'resty.template'
	local reqargs = require 'resty.reqargs'

	_ENV.lwf = {
		_NAME = "LWF_ENV",
		route = route,
		template = template,
		reqargs = reqargs,
		render = function(tfile, context)
			context.html = context.html or require 'resty.template.html'
			return template.render("view/"..tfile, context)
		end,
		session = require 'resty.session'.start(self._session),
		json = function(self, data)
			return self:json(data)
		end,
	}
	self._route:dispatch()
end

local class_meta = {
	__index = class,
	__call = function(self, ...)
		return class.handle(self, ...)
	end,
}

return {
	new = function(lwf_root, wrap_func)
		local lwf_root = lwf_root or "."
		local wrap_func = wrap_func or function() end
		return setmetatable({
			_loaded = nil,
			_route = nil,
			_lwf_root = lwf_root,
			_ngx = wrap_func(lwf_root),
		}, class_meta)
	end
}
