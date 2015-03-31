#= require Boilerpipe

# fs = require 'fs'
# request = require "request"
# path = require 'path'
# 
# 
getContentFromHTML = (html) ->
	document = Boilerpipe.documentFromHTML(html, Boilerpipe.ArticleExtractor)
	
	console.log "number of text blocks: #{document.textBlocks.length}"
	console.log "number of content blocks: #{document.numberOfContentBlocks()}"
	console.log "content length: #{document.content().length}"
	console.log "text: '#{document.content()}'"

# 
# 
getContentFromFile = (filePath) ->
	data = "<html><body><div><p>Text</p></div></body></html>"
	getContentFromHTML(data)

# 
# 
# getContentFromURL = (sourceURL) ->
# 	request sourceURL, (error, response, body) ->
# 		if error?
# 			console.log error, response
# 			return null
# 		
# 		getContentFromHTML(body) 
# 	
# 
# getContentFromFile('example/index.html')
getContentFromFile()