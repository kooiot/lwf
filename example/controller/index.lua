return {
	get = function(self)
		--[[
		print(lwf.session.data.user)
		lwf.session.data.user = 'Admin'
		lwf.session:save()
		]]--

		--lwf.render('view.html', lwf.session.data)
		lwf.render('view.html', self)
	end
}
