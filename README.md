Boilerpipe-Coffee
=================

A port of the Boilerpipe html content extractor to Coffeescript


Requirements
____________

Requires the 'htmlparser2' node.js module
In addintion the example requires 'fs', 'request', and 'path' modules

Building (combining into a single javascript file) requires `coffeescript-concat`
Testing requires the `mocha` command line tool and the 'chai' module


Usage
----

Sinplest example:

	fs = require 'fs'
	
	fs.readFile 'index.html', (error, html) ->
		if html
			document = Boilerpipe.documentFromHTML(html, Boilerpipe.ArticleExtractor)
			content = document.content()
		else
			…error handling…
