fs = require 'fs'
#= require Boilerpipe


getContentFromHTML = (html) ->
	boilerpipe = new Boilerpipe
	boilerpipe.contentFromHTML(html, Boilerpipe.ArticleExtractor)


getContentFromFile = (filePath) ->
	fs.readFile filePath, (err, data) ->
		result = getContentFromHTML(data)


getContentFromFile('index.html')