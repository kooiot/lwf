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
		local route = resty_route.new()

		load_middleware(route, 'ajax')
		load_middleware(route, 'form')
		load_middleware(route, 'pjax')
		--load_middleware(route, 'redis')
		load_middleware(route, 'reqargs')
		load_middleware(route, 'template')

		local template = route.template
		local env = setmetatable({
			route=route,
			lwf = {
				template = template,
				render = function(content, context)
					return template.render("view/"..content, context)
				end,
			},
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
	local template = route.template

	_ENV.lwf = {
		template = template,
		render = function(tfile, context)
			context.html = context.html or require 'resty.template.html'
			return template.render("view/"..tfile, context)
		end,
		session = require 'resty.session'.start(self._session)
	}
	self._route:dispatch(ngx.var.uri, ngx.var.method)
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
