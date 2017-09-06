
route("=*/help", function(self)
	lwf.render("help.html", {})
end)

route('=*/zh', function(self)
	lwf.session.data.lang = 'zh_CN'
	lwf.session:save()
	self:redirect('/')
end)
route('=*/en', function(self)
	lwf.session.data.lang = 'en_US'
	lwf.session:save()
	self:redirect('/')
end)


