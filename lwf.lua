local util = require 'lwf.util'
local lfs = require 'lfs'

local class = {}

function class:load_config(resty_route)
	local route = self._route
	if not route then
		route = resty_route.new()
		util.loadfile(self._lwf_root..'/config/route.lua', {route=route})
		self._route = route
		route:fs(self._lwf_root.."/controller")

		--route:on("error", function(self) end)
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

	self:load_config(resty_route)

	_ENV.render = function(tfile, ...)
		return resty_template.render("view/"..tfile, ...)
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
