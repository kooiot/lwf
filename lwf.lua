local util = require 'lwf.util'
local lfs = require 'lfs'

local class = {}

local function load_middleware(route, name)
	local m = require('resty.route.middleware.'..name)
	return m(route)
end

function class:load_config(resty_route, resty_template)
	local route = self._route
	if not route then
		route = resty_route.new()

		load_middleware(route, 'ajax')
		load_middleware(route, 'form')
		load_middleware(route, 'pjax')
		--load_middleware(route, 'redis')
		load_middleware(route, 'reqargs')
		load_middleware(route, 'template')

		local env = setmetatable({route=route, template=resty_template}, {__index=_ENV})
		util.loadfile(self._lwf_root..'/config/route.lua', env)

		route:fs(self._lwf_root.."/controller")

		route:on("error", function(self, code) 
			return resty_template.render("view/error.html", {code = code})
		end)

		self._route = route
	end
end

function class:handle(...)
	local lngx = self._ngx
	if lngx then
		lngx:bind(...)
		_ENV.ngx = lngx
	end

	local resty_route = require 'resty.route'
	local resty_template = require 'resty.template'

	self:load_config(resty_route, resty_template)

	_ENV.render = function(tfile, context)
		context.html = context.html or require 'resty.template.html'
		return resty_template.render("view/"..tfile, context)
	end

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
			_route = nil,
			_lwf_root = lwf_root,
			_ngx = wrap_func(lwf_root),
		}, class_meta)
	end
}
