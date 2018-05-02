local: spec.bs
	bikeshed spec spec.bs spec.html

remote: spec.bs
	curl https://api.csswg.org/bikeshed/ -f -F file=@spec.bs > spec.html
