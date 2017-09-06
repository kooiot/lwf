return {
	get = function(self)
		print(lwf.session.data.user)
		lwf.session.data.user = 'Admin'
		lwf.session:save()
		--lwf.render('view.html', lwf.session.data)
		--
		--ngx.header['aaaa']= 'eee'
		--self.route:json(ngx.req.get_headers())
		lwf.render('view.html', self)
	end
}
