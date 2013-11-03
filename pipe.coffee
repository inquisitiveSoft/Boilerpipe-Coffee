htmlparser = require 'htmlparser2'
fs = require 'fs'


class BoilerpipeParser
	@tagDepth = 0
	@completedText = ''
	
	
	constructor: (mode) ->
		@parser = new htmlparser.Parser({
			onopentag: (elementName, attributes) =>
				@startElement(elementName, attributes)
		
			ontext: (text) =>
				@foundText(text)
			
			onclosetag: (elementName) =>
				@endElement(elementName)
		})
	
	
	
	parseContent: (html) ->
		@parser.parseComplete(html);
		console.log @completedText.length
	
	
	
	startElement: (elementName, attributes) ->
		console.log "start element: #{elementName}"
	
	foundText: (text) ->
		@completedText += text
	
	endElement: (elementName) ->
		console.log "end element: #{elementName}"
	
	
	
	
	




parseContentFromHTML = (html) ->
	parser = new BoilerpipeParser
	parser.parseContent(html)


parseFile = (filePath) ->
	fs.readFile filePath, (err, data) ->
		result = parseContentFromHTML(data)

parseFile('index.html')