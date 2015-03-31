Boilerpipe = require('./Boilerpipe')

# Here we register @__performAction as a global function
# which Syml can use to invoke the action
@documentFromHTML = (input) ->
	document = Boilerpipe.documentFromHTML(input['html'], Boilerpipe.ArticleExtractor)
	
	{"title" : document.title, "text" : document.content(), "document": document}
	
