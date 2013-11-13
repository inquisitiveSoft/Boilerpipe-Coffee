fs = require 'fs'
htmlparser = require 'htmlparser2'


String::stripWhitespace = () ->
	@.replace /^\s+|\s+$/g, ""
		
String::normalize = () ->
	@.stripWhitespace().toLowerCase()

String::isWord = () ->
	/[^\W_]/.test(@)

String::isWhitespace = () ->
	@.length > 0 and /^\W+$/.test(@)



class TextBlock
	constructor: (@text, currentContainedTextElements, tagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, offsetBlocks) ->
		@text = @text
		@currentContainedTextElements = currentContainedTextElements
		@numWords = numWords
		@numWordsInAnchorText = numWordsInAnchorText
		@numWordsInWrappedLines = numWordsInWrappedLines
		@numWrappedLines = numWrappedLines
		@offsetBlocksStart = offsetBlocks
		@offsetBlocksEnd = offsetBlocks
		@tagLevel = tagLevel
		
		@calculateDensities()
	
	
	description: ->
		description = "TextBlock:\n"
		description += "  offsetBlocksStart - offsetBlocksEnd = #{@offsetBlocksStart} - #{@offsetBlocksEnd}\n"
		description += "  tagLevel = #{@tagLevel}\n"
		description += "  numWords = #{@numWords}\n"
		description += "  numWordsInAnchorText = #{@numWordsInAnchorText}\n"
		description += "  numWrappedLines = #{@numWrappedLines}\n"
		description += "  linkDensity = #{@linkDensity}\n"
		description += "'#{@text}'"
		description
	
	
	calculateDensities: () ->
		if @numWordsInWrappedLines == 0
			@numWordsInWrappedLines = @numWords
			@numWrappedLines = 1
		
		@textDensity = @numWordsInWrappedLines / @numWrappedLines
		
		if @numWords == 0
			@linkDensity = 0.0
		else
			@linkDensity = @numWordsInAnchorText / @numWords
	
	
	# def mergeNext(self, nextTextBlock):
	# 	if self.text==None: self.text=""
	# 	self.text+='\n'+nextTextBlock.text
	# 	self.numWords += nextTextBlock.numWords
	# 	self.numWordsInAnchorText += nextTextBlock.numWordsInAnchorText
	# 	self.numWordsInWrappedLines += nextTextBlock.numWordsInWrappedLines
	# 	self.numWrappedLines += nextTextBlock.numWrappedLines
	# 	self.offsetBlocksStart = min(self.offsetBlocksStart, nextTextBlock.offsetBlocksStart)
	# 	self.offsetBlocksEnd = max(self.offsetBlocksEnd, nextTextBlock.offsetBlocksEnd)
	# 	
	#		@calculateDensities()
	# 	self._isContent |= nextTextBlock.isContent()
	# 	self.containedTextElements|=nextTextBlock.containedTextElements
	# 	self.numFullTextWords += nextTextBlock.numFullTextWords
	# 	self.labels|=nextTextBlock.labels
	# 	self.tagLevel = min(self.tagLevel, nextTextBlock.tagLevel)



class BoilerpipeParser
	
	# Keys
	IgnorableElementAction = 'IgnorableElementAction'
	BodyElementAction = 'BodyElementAction'
	AnchorTextElementAction = 'AnchorTextElementAction'
	InlineNoWhitespaceElementAction = 'InlineNoWhitespaceElementAction'
	InlineWhitespaceElementAction = 'InlineWhitespaceElementAction'
	
	EventStartTag = 'EventStartTag'
	EventEndTag = 'EventEndTag'
	EventWhitespace = 'EventWhitespace'
	EventCharacters = 'EventCharacters'
	
	AnchorTextStart = 'AnchorTextStart'
	AnchorTextEnd = 'AnchorTextEnd'
	
	
	
	constructor: (mode) ->
		@parser = new htmlparser.Parser({
			onopentag: (elementName, attributes) =>
				@startElement(elementName, attributes)
		
			ontext: (text) =>
				@foundText(text)
			
			onclosetag: (elementName) =>
				@endElement(elementName)
		})
		
		@resetToInitialState()
	
	
	resetToInitialState: () ->
		
		# Results
		@title = ''
		@textBlocks = []
	
		# Internal state
		@offsetBlocks = 0
		@lastEvent = null
		@lastStartTag = null
		@textBlocks = []
		@labelStacks = []
		@currentContainedTextElements = []
		
		@tagLevel = 0
		@blockTagLevel = 0
		
		@ignorableElementDepth = 0
		@inBody = 0
		@inAnchor = 0
		@inAnchorText = false
		
		@clearTextBuffer()
		@flush = false
	
	
	
	parseContent: (html) ->
		@resetToInitialState()
		
		@startParsingDocument()
		@parser.parseComplete(html);
		@endParsingDocument()
		
		for textBlock in @textBlocks
			console.log("#{textBlock.description()}")
		
		console.log("number of text blocks: #{@textBlocks.length}")
		
	
	startParsingDocument: () ->
		
	
	endParsingDocument: () ->
		@flushBlock()

	
	startElement: (elementName, attributes) ->
		@labelStacks.push([])
		
		switch @elementTypeForTag(elementName)
			when IgnorableElementAction
				@ignorableElementDepth++
				@tagLevel++
				@flush = true
			
			
			when BodyElementAction
				@flushBlock()
				@inBody++
				@tagLevel++
			
			when AnchorTextElementAction
				@inAnchor++
				@tagLevel++
				
				if @inAnchor > 1
					#  as nested A elements are not allowed per specification, we are probably
					#  reaching this branch due to a bug in the XML parser
					console.log("Warning: SAX input contains nested A elements -- You have probably hit a bug in your HTML parser (e.g., NekoHTML bug #2909310). Please clean the HTML externally and feed it to boilerpipe again. Trying to recover somehow...")
					endElement(elementName)
				
				if @ignorableElementDepth == 0
					@addToken(AnchorTextStart)
			
			
			# when InlineWhitespaceElementAction
				# @addWhitespaceIfNecessary()
			
			when InlineNoWhitespaceElementAction
				
			
			else
				@tagLevel++
				@flush = true
		
		@lastEvent = EventStartTag
		@lastStartTag = elementName
	
	
	
	foundText: (text) ->
		@textElementIdx++
		@flushBlock() if @flush
		return if @inIgnorableElement > 0 or !text? or text.length == 0
		
		strippedContent = text.stripWhitespace()
		
		if strippedContent.length == 0
			# @addWhitespaceIfNecessary()
			@lastEvent = EventWhitespace
			return
		
		# if text.charAt(0).isWhitespace()
		# 	@addWhitespaceIfNecessary()
		
		if @blockTagLevel == -1
			@blockTagLevel = @tagLevel
		
		@textBuffer += text
		
		tokens = @tokenizeString(text)
		@tokenBuffer.push(tokens)
		
		# if text.charAt(-1).isWhitespace()
		# 	self.addWhitespaceIfNecessary()
		# 
		@lastEvent = EventCharacters
		@currentContainedTextElements.push(@textElementIdx)
	
	
	
	endElement: (elementName) ->
		
		switch @elementTypeForTag(elementName)
			when IgnorableElementAction
				@ignorableElementDepth--
				@tagLevel--
				@flush = true
			
			when BodyElementAction
				@flushBlock()
				@inBody--
				@tagLevel--
			
			
			when AnchorTextElementAction
				@inAnchor--
				
				if @inAnchor == 0 and @ignorableElementDepth == 0
					@addToken(AnchorTextEnd)
				
				@tagLevel--
			
			
			# when InlineWhitespaceElementAction
				# @addWhitespaceIfNecessary()
			
			
			when InlineNoWhitespaceElementAction
				
			
			else
				@tagLevel--
				@flush = true
		
		
		@flushBlock() if @flush
		
		@lastEvent = EventEndTag
		@lastEndTag = elementName
		@labelStacks.pop()
	
	
	
	flushBlock: () ->
		@flush = false
		
		if !@inBody? or @inBody <= 0
			if @lastStartTag.normalize() == "title"
				@title = @textBuffer.stripWhitespace()
			
			@clearTextBuffer()
			return
		
		if !@tokenBuffer.length > 0
			@clearTextBuffer()
			return
		
		numWords = 0
		numWordsInAnchorText = 0
		numWrappedLines = 0
		currentLineLength = -1		#  don't count the first space
		maxLineLength = 80
		numTokens = 0
		numWordsCurrentLine = 0
		
		console.log("\n\n")
		
		for token in @tokenBuffer
			console.log("#{token} #{token.constructor}")
			
			if token == AnchorTextStart
				@inAnchorText = true
			
			else if token == AnchorTextEnd
				@inAnchorText = false
			
			else if token.isWord()
				numTokens++
				numWords++
				numWordsCurrentLine++
				
				if @inAnchorText
					numWordsInAnchorText++
				
				currentLineLength += token.length + 1
				
				if currentLineLength > maxLineLength
					numWrappedLines++
					currentLineLength = token.length
					numWordsCurrentLine = 1
			
			else
				numTokens++
		
		
		if numTokens > 0
			if numWrappedLines == 0
				numWordsInWrappedLines = numWords
				numWrappedLines = 1
			else
				numWordsInWrappedLines = numWords - numWordsCurrentLine
			
			currentText = @textBuffer
			textBlock = new TextBlock(currentText, @currentContainedTextElements, @blockTagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, @offsetBlocks)
			
			@currentContainedTextElements = []
			@offsetBlocks++
			@clearTextBuffer()
			
			@addTextBlock(textBlock)
			
			@blockTagLevel--
		else
			@clearTextBuffer()
	
	
	addToken: (token) ->
		@tokenBuffer.push(token) if token?
	
	addTextBlock: (textBlock) ->
		@textBlocks.push(textBlock) if textBlock?
	
	clearTextBuffer: ->
		@textBuffer = ''
		@tokenBuffer = []
		
	
	elementTypeForTag: (tagName) ->
		@mapOFActionsToTags = {
			"style"			:	IgnorableElementAction,
			"script"		:	IgnorableElementAction,
			"option"		:	IgnorableElementAction,
			"object"		:	IgnorableElementAction,
			"embed"			:	IgnorableElementAction,
			"applet"		:	IgnorableElementAction,
			
			# Note: link removed because it can be self-closing in HTML5
			#"link"			: IgnorableElementAction ,
			"a"					:	AnchorTextElementAction,
			"body"			:	BodyElementAction,
			"strike"		:	InlineNoWhitespaceElementAction,
			"u"					:	InlineNoWhitespaceElementAction,
			"b"					:	InlineNoWhitespaceElementAction,
			"i"					:	InlineNoWhitespaceElementAction,
			"em"				:	InlineNoWhitespaceElementAction,
			"strong"		:	InlineNoWhitespaceElementAction,
			"span"			:	InlineNoWhitespaceElementAction,
			
			# New in 1.1 (especially to improve extraction quality from Wikipedia etc.,
			"sup"				:	InlineNoWhitespaceElementAction,
			
			# New in 1.2
			"code"			:	InlineNoWhitespaceElementAction,
			"tt"				:	InlineNoWhitespaceElementAction,
			"sub"				:	InlineNoWhitespaceElementAction,
			"var"				:	InlineNoWhitespaceElementAction,
			"abbr"			:	InlineWhitespaceElementAction,
			"acronym"		:	InlineWhitespaceElementAction,
			"font"			:	InlineNoWhitespaceElementAction,
		
			# could also use TA_FONT 
			# added in 1.1.1
			"noscript"	:	IgnorableElementAction 
		}
		
		tagName = tagName.toLowerCase()
		@mapOFActionsToTags[tagName]
	
	
	tokenizeString: (input) ->
		input.match /\ue00a?[\w\"'\.,\!\@\-\:\;\$\?\(\)/]+/g



parseContentFromHTML = (html) ->
	parser = new BoilerpipeParser
	parser.parseContent(html)


parseFile = (filePath) ->
	fs.readFile filePath, (err, data) ->
		result = parseContentFromHTML(data)

parseFile('index.html')