local skynet = require 'skynet'
local cjson = require 'cjson'
local md5 = require 'md5'
local urllib = require 'http.url'
local crypt = require 'skynet.crypt'
local sockethelper = require "http.sockethelper"
local shared = require 'lwf.skynet.shared'
local util = require 'lwf.util'

local ngx_base = {
	OK = 0,
	ERROR = -1,
	AGAIN = -2,
	DONE = -4,
	DECLINED = -5,
	null = cjson.null,

	-- HTTP Methods
	HTTP_GET = "GET",
	HTTP_HEAD = "HEAD",
	HTTP_PUT = "PUT",
	HTTP_POST = "POST",
	HTTP_DELETE = "DELETE",
	HTTP_OPTIONS = "OPTIONS",

	-- HTTP STATUS CONSTRANTS
	HTTP_CONTINUE = 100,
	HTTP_SWITCHING_PROTOCOLS = 101,
	HTTP_OK = 200,
	HTTP_CREATED = 201,
	HTTP_ACCEPTED = 202,
	HTTP_NO_CONTENT = 204,
	HTTP_PARTIAL_CONTENT = 206,
	HTTP_SPECIAL_RESPONSE = 300,
	HTTP_MOVED_PERMANENTLY = 301,
	HTTP_MOVED_TEMPORARILY = 302,
	HTTP_SEE_OTHER = 303,
	HTTP_NOT_MODIFIED = 304,
	HTTP_TEMPORARY_REDIRECT = 307,
	HTTP_BAD_REQUEST = 400,
	HTTP_UNAUTHORIZED = 401,
	HTTP_PAYMENT_REQUIRED = 402,
	HTTP_FORBIDDEN = 403,
	HTTP_NOT_FOUND = 404,
	HTTP_NOT_ALLOWED = 405,
	HTTP_NOT_ACCEPTABLE = 406,
	HTTP_REQUEST_TIMEOUT = 408,
	HTTP_CONFLICT = 409,
	HTTP_GONE = 410,
	HTTP_UPGRADE_REQUIRED = 426,
	HTTP_TOO_MANY_REQUESTS = 429,
	HTTP_CLOSE = 444,
	HTTP_ILLEGAL = 451,
	HTTP_INTERNAL_SERVER_ERROR = 500,
	HTTP_METHOD_NOT_IMPLEMENTED = 501,
	HTTP_BAD_GATEWAY = 502,
	HTTP_SERVICE_UNAVAILABLE = 503,
	HTTP_GATEWAY_TIMEOUT = 504,
	HTTP_VERSION_NOT_SUPPORTED = 505,
	HTTP_INSUFFICIENT_STORAGE = 507,

	-- HTTP LOG LEVEL constants
	STDERR = 'stderr',
	EMERG = 'emerg',
	ALERT = 'alert',
	CRIT = 'crit',
	ERR = 'err',
	WARN = 'warn',
	NOTICE = 'notice',
	INFO = 'info',
	DEBUG = 'debug',

	config = {
		subsystem = 'http',
		debug = false,
		prefix = function() return '' end,
		nginx_version = '1.4.3',
		nginx_configure = function() return '' end,
		ngx_lua_version = '0.9.3',
	},
}

local ngx_log = function(level, ...)
end

local null_impl = function()
	assert(false, 'Not implementation')
end

local function response(sock, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(sock), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", sock, err))
	end
end

local function shared_index(tab, key)
	local s = rawget(tab, key)
	if not s then
		s = shared.new(key)
		rawset(tab, key, s)
	end
	return s
end

function ngx_base:bind(method, uri, header, body, httpver, sock)
	local to_ngx_req = require 'lwf.skynet.req'
	local to_ngx_resp = require 'lwf.skynet.resp'
	local path, query = urllib.parse(uri)
	assert(header)

	self.var.method = method
	self.var.header = header
	self.var.uri = uri
	self.var.path = path
	self.var.args = query

	self.req = to_ngx_req(self, body, httpver, socket)
	self.resp = to_ngx_resp(self)
	self.ctx = {}
	self.status = 200
end

local function create_wrapper()
	local ngx = {
		var = {},
		arg = {},
		ctx = {},
		location = {},
		status = 200,
	}
	ngx.location.capture = function(uri, options)
		assert(false, "NOT Implemented")
	end
	ngx.location.capture_multi = function(list)
		local res = {}
		for _, v in ipairs(list) do
			res[#res + 1] = ngx.location.capture(table.unpack(v))
		end
		return table.unpack(res)
	end

	ngx.exec = function(uri, args)
		assert(nil, uri, args)
	end
	ngx.redirect = function(uri, status)
		local status = status or 302
		response(sock, status, ngx.resp.get_body(), ngx.resp.get_headers())
	end
	ngx.send_headers = function()
		assert(nil, "NNNN")
	end
	ngx.headers_send = false
	ngx.print = function(...) 
		ngx.resp.append_body(...)
	end
	ngx.say = function(...)
		ngx.resp.append_body(...)
		ngx.resp.append_body("\r\n")
	end
	ngx.log = ngx_log
	ngx.flush = function(wait)
		return response(sock, ngx.status, ngx.resp.get_body(), ngx.resp.get_headers())
	end
	ngx.exit = function(status)
		return response(sock, status, ngx.resp.get_body(), ngx.resp.get_headers())
	end
	ngx.eof = function() end
	ngx.sleep = function(seconds)
		skynet.sleep(seconds * 100)
	end
	ngx.escape_uri = util.escape_url
	ngx.unescape_uri = util.unescape_url
	ngx.encode_args = function(args)
		return util.encode_query_string(args)
	end
	ngx.decode_args = function(str)
		return urllib.parse_query(str)
	end
	ngx.encode_base64 = function(str, no_padding)
		assert(not no_padding)
		return crypt.base64encode(str)
	end
	ngx.decode_base64 = function(str)
		return crypt.base64decode(str)
	end
	ngx.crc32_short = function(str)
		assert(false)
	end
	ngx.crc32_long = function(str)
		assert(false)
	end
	ngx.hmac_sha1 = function(secret_key, str)
		return crypt.hmac_sha1(secret_key, str)
	end
	ngx.md5 = function(str)
		return md5.sumhexa(str)
	end
	ngx.md5_bin = function(str)
		return md5.sum(str)
	end
	ngx.sha1_bin = function(str)
		return crypt.sha1(str)
	end
	ngx.quote_sql_str = function(raw_value)
		local mysql = require 'skynet.db.mysql'
		return mysql.quote_sql_str(raw_value)
	end

	--- TIME STUFF
	local now = os.time() -- local
	local skynet_now = skynet.time() -- UTC

	ngx.today = function()
		return os.date('%Y-%m-%d', now)
	end
	ngx.time = function()
		return now + (skynet_now - math.floor(skynet_now))
	end
	ngx.now = function()
		return skynet_now
	end
	ngx.update_time = function() 
		now = os.time()
		skynet_now = skynet.time()
	end
	ngx.localtime = function()
		return os.date('%F %T', now)
	end
	ngx.utctime = function()
		return os.date('%F %T', math.floor(skynet_now))
	end
	ngx.cookie_time = function(sec)
		return os.date('%a, %d-%b-%y %T %Z', sec)
	end
	ngx.http_time = function(sec)
		return os.date('%a, %d %b %Y %T %Z', sec)
	end
	ngx.parse_http_time = function(str)
		assert(false)
	end
	ngx.is_subrequest = function() return false end
	ngx.re = {
		match = function(subject, regex, options, ctx, res_table)
			assert(false)
		end,
		find = function(subject, regex, options, ctx, nth)
			assert(false)
		end,
		gmatch = function(subject, regex, options)
			assert(false)
		end,
		sub = function(subject, regex, replace, options)
			assert(false)
		end,
		gsub = function(subject, regex, replace, options)
			assert(false)
		end,
	}
	--TODO:
	ngx.shared = setmetatable({}, {__index=shared_index})

	ngx.get_phase = function()
		return 'content'
	end

	return setmetatable(ngx, {__index=ngx_base})
end

return create_wrapper
