

String::stripWhitespace = () ->
	@.replace /^\s+|\s+$/g, ""

String::normalize = () ->
	@.stripWhitespace().toLowerCase()

String::isWord = () ->
	/[^\W_]/.test(@)


String::numberOfWords = () ->
	@.match(/\w+/g).length


String::isWhitespace = () ->
	@.length > 0 and /^\W+$/.test(@)

String::startsWith = (match) ->
	@.substring(0, match.length) == match if match?



Array::merge = (secondArray) ->
	Array::push.apply @, secondArray

Array::contains = (object) ->
	@.indexOf(object) >= 0 


Array::where = (query, matcher = (a,b) -> a is b) ->
	return [] if typeof query isnt "object"
	hit = Object.keys(query).length
	@filter (item) ->
		match = 0
		for key, val of query
			match += 1 if matcher(item[key], val)
		match is hit


Array::removeObject = (objectToRemove) ->
	if objectToRemove
		indexToRemove = @.indexOf(objectToRemove)
		@.splice(indexToRemove, 1)

