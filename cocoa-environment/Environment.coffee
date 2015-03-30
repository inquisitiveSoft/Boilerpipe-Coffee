require('./Boilerpipe')

# Here we register @__performAction as a global function
# which Syml can use to invoke the action
@documentFromHTML = (input) ->
	return Boilerpipe.documentFromHTML(input)
