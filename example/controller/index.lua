return {
	get = function(self)
		--[[
		print(lwf.session.data.user)
		lwf.session.data.user = 'Admin'
		lwf.session:save()
		]]--
		--print(lwf.auth.user)
		if lwf.auth.user == 'Guest' then
			lwf.auth:login_as('admin')
		end
		lwf.render('index.html')
	end
}
