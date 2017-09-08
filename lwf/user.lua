return {
	login = function(self)
		assert(ngx.var.method == 'POST')
		local msg = "incorrect login"
		if lwf.auth.user ~= 'Guest' then
			lwf.auth:clear()
		end
		ngx.req.read_body()

		local post = ngx.req.get_post_args()
		local username = post.username
		local password = post.password
		if username and password then
			local r, err = lwf.auth:login(username, password)	
			if r then
				msg = username
			else
				msg = err
			end
		end
		lwf.auth:save()
		self:json({message=msg})
	end,
	logout = function(self)
		lwf.auth:logout()
		lwf.auth:save()
		self:json({message="OK"})
	end,
	home = function(self)
		self:redirect('/')
	end,
}
