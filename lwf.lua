local lfs = require 'lfs'
local util = require 'lwf.util'
local i18n = require 'lwf.i18n'

local class = {}

local function load_middleware(route, name)
	local m = require('resty.route.middleware.'..name)
	return m(route)
end

local function create_context(route, context)
	return setmetatable(context or {}, {__index=route})
end

local function load_i18n(root)
	local attr = lfs.attributes(root)
	if not attr or attr.mode ~= 'directory' then
		return {}
	end

	local po = require 'lwf.util.po'
	local dir = require 'lwf.util.dir'

	dir.do_each(root, function(path)
		local lang = path:match('.+/([^/]+)$')
		if lang ~= 'template' then
			po.attach(path, lang)
		end
	end)
	return po.get_translations()
end

function class:get_translator(session)
	local lang = nil
	if session then
		local lngx = self._ngx or ngx
		lang = session.data.lang or util.guess_lang(lngx.var.header)
	end

	local translator = i18n.make_translator(self._translations, lang)
	if self._base_lwf then
		return i18n.make_fallback(translator, self._base_lwf:get_translator(session))
	end

	return translator
	--[[
	if self.base_app then
		local ft = self.base_app.translations
		local translator = i18n.make_translator(self.translations, lang)
		local basetransaltor = i18n.make_translator(ft, lang)
		return i18n.make_fallback(translator, basetransaltor)
	else
		return i18n.make_translator(self.translations, lang)
	end
	]]--
end

function class:load_auth(config)
	if not config then
		return nil, "no Auth"
	end

	local auth = require 'resty.auth'
	assert(auth.setup(config))

	local config = config
	self._auth = function()
		local auth = require 'resty.auth'
		auth.new(config.scheme, config.domain):auth()
	end
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

		local assets = self._assets
		if assets then
			local assets_root = self._lwf_root.."/assets"
			route("#/assets/(.+)", function(self, file)
				return assets(self, assets_root, file)
			end)
		end

		route:on("error", function(self, code) 
			return template.render("error.html", create_context(self, {code = code}))
		end)

		self._session = util.loadfile_as_table(self._lwf_root..'/config/session.lua') or {
			secret = "0cc312cbaedad75820792070d720dbda"
		}
		self._session['cipher'] = 'none'

		self._route = route
		self._translations = load_i18n(self._lwf_root.."/i18n")

		local config, err = util.loadfile_as_table(self._lwf_root..'/config/auth.lua')
		if config then
			self:load_auth(config)
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

	local session = require('resty.session').start(self._session)
	local translator = self:get_translator(session)

	_ENV.lwf = {
		_NAME = "LWF_ENV",
		route = route,
		template = template,
		reqargs = reqargs,
		render = template.render,
		session = session,
		json = function(self, data)
			return self:json(data)
		end,
		translate = translator.translate,
		translatef = translator.translatef,
	}
	_ENV._ = function(...)
		if select("#") == 1 then
			return translator.translate(...)
		end
		return translator.translatef(...)
	end
	_ENV.html = require 'resty.template.html'

	if self._auth then
		self._auth()
	end
	self._route:dispatch()
end

local class_meta = {
	__index = class,
	__call = function(self, ...)
		return class.handle(self, ...)
	end,
}

return {
	new = function(lwf_root, wrap_func, assets_func)
		local lwf_root = lwf_root or "."
		local wrap_func = wrap_func or function() end
		local assets_func = assets_func or function() end

		local lngx = wrap_func(lwf_root.."/view")
		local lassets = assets_func(lngx)
		return setmetatable({
			_loaded = nil,
			_route = nil,
			_lwf_root = lwf_root,
			_ngx = lngx,
			_assets = lassets,
		}, class_meta)
	end
}
