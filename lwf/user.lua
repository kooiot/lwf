return {
	login = function(self)
		if ngx.var.method ~= 'POST' then
			return lwf.render('user/login.html', self)
		end

		local msg = "incorrect login"
		if lwf.auth.user ~= 'Guest' then
			lwf.auth:clear()
		end
		ngx.req.read_body()

		local r = 401
		local post = ngx.req.get_post_args()
		local username = post.username
		local password = post.password
		if username and password then
			local r, err = lwf.auth:login(username, password)	
			if r then
				msg = username
				r = 200
			else
				msg = err
			end
		end
		lwf.auth:save()
		if not post.from_web then
			self:json({message=msg})
			if r ~= 200 then
				self:fail(r)
			end
		else
			lwf.render('user/login.html', {message=msg})			
		end
	end,
	logout = function(self)
		lwf.auth:logout()
		lwf.auth:save()
		if ngx.var.method == 'POST' then
			self:json({message="OK"})
		else
			self:redirect('/login')
		end
	end,
	home = function(self)
		if lwf.auth.user ~= 'Guest' then
			self:redirect('/')
		else
			self:redirect('/login')
		end
	end,
}
