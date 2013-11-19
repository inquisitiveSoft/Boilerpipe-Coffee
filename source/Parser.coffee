#= require <CommonExtensions.coffee>
#= require TextBlock
#= require TextDocument

htmlparser = require 'htmlparser2'



class BoilerpipeParser
	###
	Parses the input HTML into an array of TextBlock objects
	###
	
	# Keys
	@IgnorableElementAction: 'IgnorableElementAction'
	@BodyElementAction: 'BodyElementAction'
	@AnchorTextElementAction: 'AnchorTextElementAction'
	@InlineNoWhitespaceElementAction: 'InlineNoWhitespaceElementAction'
	@InlineWhitespaceElementAction: 'InlineWhitespaceElementAction'
	
	@EventStartTag: 'EventStartTag'
	@EventEndTag: 'EventEndTag'
	@EventWhitespace: 'EventWhitespace'
	@EventCharacters: 'EventCharacters'
	
	@AnchorTextStart: 'AnchorTextStart'
	@AnchorTextEnd: 'AnchorTextEnd'
	
	
	
	constructor: (mode) ->
		@parser = new htmlparser.Parser({
			onopentag: (elementName, attributes) =>
				@startElement(elementName, attributes)
		
			ontext: (text) =>
				@foundText(text)
			
			onclosetag: (elementName) =>
				@endElement(elementName)
		})
	
	
	resetToInitialState: () ->
		
		# Results
		@title = ''
		@textBlocks = []
	
		# Internal state
		@offsetBlocks = 0
		@lastStartTag = null
		@textBlocks = []
		@labelStacks = []
		@currentContainedTextElements = []
		
		@tagLevel = 0
		@blockTagLevel = null
		
		@ignorableElementDepth = 0
		@inBody = 0
		@inAnchor = 0
		@inAnchorText = false
		
		@clearTextBuffer()
		@flush = false
	
	
	
	parseDocumentFromHTML: (html) ->
		@resetToInitialState()
		
		@startParsingDocument()
		@parser.parseComplete(html);
		@endParsingDocument()
		
		new TextDocument(@title, @textBlocks)
	
	
	startParsingDocument: () ->
		
	
	endParsingDocument: () ->
		@flushBlock()

	
	startElement: (elementName, attributes) ->
		@labelStacks.push([])
		
		switch @elementTypeForTag(elementName)
			when BoilerpipeParser.IgnorableElementAction
				@ignorableElementDepth++
				@tagLevel++
			
			when BoilerpipeParser.BodyElementAction
				@flushBlock()
				@inBody++
				@tagLevel++
			
			when BoilerpipeParser.AnchorTextElementAction
				@inAnchor++
				@tagLevel++
				
				if @inAnchor > 1
					#  as nested A elements are not allowed per specification, we are probably
					#  reaching this branch due to a bug in the XML parser
					console.log("Warning: SAX input contains nested A elements -- You have probably hit a bug in your HTML parser (e.g., NekoHTML bug #2909310). Please clean the HTML externally and feed it to boilerpipe again. Trying to recover somehow...")
					endElement(elementName)
				
				if @ignorableElementDepth == 0
					@addToken(BoilerpipeParser.AnchorTextStart)
			
			
			when BoilerpipeParser.InlineWhitespaceElementAction, BoilerpipeParser.InlineNoWhitespaceElementAction
			
			else
				@tagLevel++
				@flush = true
		
		@lastStartTag = elementName
	
	
	
	foundText: (text) ->
		@textElementIdx++
		@flushBlock() if @flush
		
		return if @ignorableElementDepth > 0 or !text? or text.length == 0
		
		strippedContent = text.stripWhitespace()
		
		if strippedContent.length == 0
			return
		
		@textBuffer += text
		tokens = @tokenizeString(text)
		@tokenBuffer.merge tokens if tokens 
		@blockTagLevel = @tagLevel if !@blockTagLevel?
		
		@currentContainedTextElements.push(@textElementIdx)
	
	
	
	endElement: (elementName) ->
		
		switch @elementTypeForTag(elementName)
			when BoilerpipeParser.IgnorableElementAction
				@ignorableElementDepth--
				@tagLevel--
				@flush = true
			
			when BoilerpipeParser.BodyElementAction
				@flushBlock()
				@inBody--
				@tagLevel--
			
			
			when BoilerpipeParser.AnchorTextElementAction
				@inAnchor--
				
				if @inAnchor == 0 and @ignorableElementDepth == 0
					@addToken(BoilerpipeParser.AnchorTextEnd)
				
				@tagLevel--
			
			when BoilerpipeParser.InlineWhitespaceElementAction, BoilerpipeParser.InlineNoWhitespaceElementAction
			
			else
				@tagLevel--
				@flush = true
		
		
		@flushBlock() if @flush
		
		@lastEndTag = elementName
		@labelStacks.pop()
	
	
	
	flushBlock: () ->
		@flush = false
		
		if !@inBody? or @inBody <= 0
			if @lastStartTag?.normalize() == "title"
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
				
		
		for token in @tokenBuffer
			if token == BoilerpipeParser.AnchorTextStart
				@inAnchorText = true
			
			else if token == BoilerpipeParser.AnchorTextEnd
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
			@textBlocks.push(textBlock)
			
			@offsetBlocks++
			@blockTagLevel = null
			@currentContainedTextElements = []
		
		@clearTextBuffer()
	
	
	addToken: (token) ->
		@tokenBuffer.push(token) if token?
	
	
	clearTextBuffer: ->
		@textBuffer = ''
		@tokenBuffer = []
		
	
	elementTypeForTag: (tagName) ->
		@mapOFActionsToTags = {
			"style"			:	BoilerpipeParser.IgnorableElementAction,
			"script"		:	BoilerpipeParser.IgnorableElementAction,
			"option"		:	BoilerpipeParser.IgnorableElementAction,
			"object"		:	BoilerpipeParser.IgnorableElementAction,
			"embed"			:	BoilerpipeParser.IgnorableElementAction,
			"applet"		:	BoilerpipeParser.IgnorableElementAction,
			
			# Note: link removed because it can be self-closing in HTML5
			#"link"			: BoilerpipeParser.IgnorableElementAction ,
			"a"					:	BoilerpipeParser.AnchorTextElementAction,
			"body"			:	BoilerpipeParser.BodyElementAction,
			"strike"		:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"u"					:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"b"					:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"i"					:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"em"				:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"strong"		:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"span"			:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			
			# New in 1.1 (especially to improve extraction quality from Wikipedia etc.,
			"sup"				:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			
			# New in 1.2
			"code"			:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"tt"				:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"sub"				:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"var"				:	BoilerpipeParser.InlineNoWhitespaceElementAction,
			"abbr"			:	BoilerpipeParser.InlineWhitespaceElementAction,
			"acronym"		:	BoilerpipeParser.InlineWhitespaceElementAction,
			"font"			:	BoilerpipeParser.InlineNoWhitespaceElementAction,
		
			# could also use TA_FONT 
			# added in 1.1.1
			"noscript"	:	BoilerpipeParser.IgnorableElementAction 
		}
		
		tagName = tagName.toLowerCase()
		@mapOFActionsToTags[tagName]
	
	
	tokenizeString: (input) ->
		input.match /\ue00a?[\w\"'\.,\!\@\-\:\;\$\?\(\)/]+/g

