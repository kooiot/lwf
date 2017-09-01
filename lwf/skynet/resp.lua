
local function to_ngx_resp(var)
	local var = var
	local headers = {}
	local body = {}
	return {
		get_headers = function() return headers end,
		add_header = function(header_name, header_value)
			headers[header_name] = header_value
		end,
		get_body = function() return table.concat(body) end,
		append_body = function(...) 
			for _,v in ipairs({...}) do
				body[#body + 1] = v
			end
		end,
	}
end

return to_ngx_resp
