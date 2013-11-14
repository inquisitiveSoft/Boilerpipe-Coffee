

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





class TextBlock
	
	# Standard block labels
	# @Title: "Title"
	# @ArticleMetadata: "ArticleMetadata"
	# @IndicatesEndOfText: "IndicatesEndOfText"
	# @MightBeContent: "MightBeContent"
	# @StrictlyNotContent: "StrictlyNotContent"
	# @HorizontalRule = "@HorizontalRule"
	# @MarkupPrefix = "<"
	
	@EndOfText: "EndOfText"
	
	
	constructor: (text, currentContainedTextElements, tagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, offsetBlocks) ->
		@text = text?.replace /^\s+|\n+$/g, ""
		
		@currentContainedTextElements = currentContainedTextElements
		@numWords = numWords
		@numWordsInAnchorText = numWordsInAnchorText
		@numWordsInWrappedLines = numWordsInWrappedLines
		@numWrappedLines = numWrappedLines
		@offsetBlocksStart = offsetBlocks
		@offsetBlocksEnd = offsetBlocks
		@tagLevel = tagLevel
		@isContent = true
		
		@labels = []
		
		@calculateDensities()
	
	
	description: ->
		description = "TextBlock:\n"
		description += "   offsetBlocksStart - offsetBlocksEnd = #{@offsetBlocksStart} - #{@offsetBlocksEnd}\n"
		description += "   tagLevel = #{@tagLevel}\n"
		description += "   numWords = #{@numWords}\n"
		description += "   numWordsInAnchorText = #{@numWordsInAnchorText}\n"
		description += "   numWrappedLines = #{@numWrappedLines}\n"
		description += "   linkDensity = #{@linkDensity}\n"
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
	
	
	mergeNext: (nextTextBlock) ->
		if !text?
			@text = ""
		
		@text += '\n' + nextTextBlock.text
		@numWords += nextTextBlock.numWords
		@numWordsInAnchorText += nextTextBlock.numWordsInAnchorText
		@numWordsInWrappedLines += nextTextBlock.numWordsInWrappedLines
		@numWrappedLines += nextTextBlock.numWrappedLines
		@offsetBlocksStart = Math.min @offsetBlocksStart, nextTextBlock.offsetBlocksStart
		@offsetBlocksEnd = Math.max @offsetBlocksEnd, nextTextBlock.offsetBlocksEnd
		
		@calculateDensities()
		@isContent |= nextTextBlock.isContent
		@containedTextElements |= nextTextBlock.containedTextElements
		@numFullTextWords += @numFullTextWords
		@labels |= nextTextBlock.labels
		@tagLevel = Math.min @tagLevel, nextTextBlock.tagLevel
	
	addLabel: (label) ->
		@labels.push(label) if label?



class TextDocument
	###
	Text document encapsulates a title and a series of textBlocks
	###
	
	constructor: (title, textBlocks) ->
		@title = title
		@textBlocks = textBlocks
	
	content: () ->
		@text(true, false)
	
	
	#	  * Returns the TextDocument's content, non-content or both
	#	  * @param includeContent Whether to include TextBlocks marked as "content".
	#	  * @param includeNonContent Whether to include TextBlocks marked as "non-content".
	#	  * @return The text.
	
	text: (includeContent, includeNonContent) ->
		text = ""
		
		for textBlock in @textBlocks
			if (textBlock.isContent and includeContent) or (!textBlock.isContent and includeNonContent)
				text += textBlock.text + '\n'
		
		text
	
	removeTextBlock: (textBlock) ->
		@textBlocks.removeObject(textBlock)
		




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
		return if @inIgnorableElement > 0 or !text? or text.length == 0
		
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
	
	addTextBlock: (textBlock) ->
	
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



###
	
	Filters
	=======
	
	Simple Filters:
	---------------
		MarkEverythingContentFilter - Marks all blocks as content.
		InvertedFilter - Reverts the "isContent" flag for all TextBlocks
		BoilerplateBlockFilter - Removes TextBlocks which have explicitly been marked as "not content". 
		MinWordsFilter - Keeps only those content blocks which contain at least k words.
		MinClauseWordsFilter - Keeps only blocks that have at least one segment fragment ("clause") with at least k words
		SplitParagraphBlocksFilter - Splits TextBlocks at paragraph boundaries
		SurroundingToContentFilter
		LabelToBoilerplateFilter - Marks all blocks that contain a given label as "boilerplate".
		LabelToContentFilter - Marks all blocks that contain a given label as "content".
	
	Heuristic Filters:
	------------------
		SimpleBlockFusionProcessor - Merges two subsequent blocks if their text densities are equal.
		ContentFusion
		LabelFusion - Fuses adjacent blocks if their labels are equal.
		BlockProximityFusion - Fuses adjacent blocks if their distance (in blocks) does not exceed a certain limit.
		KeepLargestBlockFilter - Keeps the largest {@link TextBlock} only (by the number of words)
		ExpandTitleToContentFilter - Marks all TextBlocks "content" which are between the headline and the part that has already been marked content, if they are marked MIGHT_BE_CONTENT
		ArticleMetadataFilter
		AddPrecedingLabelsFilter - Adds the labels of the preceding block to the current block, optionally adding a prefix.
		DocumentTitleMatchClassifier - Marks TextBlocks which contain parts of the HTML TITLE tag
	
	English-trained Heuristic Filters:
	----------------------------------
		MinFulltextWordsFilter - Keeps only those content blocks which contain at least k full-text words
		KeepLargestFulltextBlockFilter - Keeps the largest TextBlock only (by the number of words)
		IgnoreBlocksAfterContentFilter - Marks all blocks as "non-content" that occur after blocks that have been marked INDICATES_END_OF_TEXT
		IgnoreBlocksAfterContentFromEndFilter - like above
		TerminatingBlocksFinder - Finds blocks which are potentially indicating the end of an article text and marks them with INDICATES_END_OF_TEXT
		NumWordsRulesClassifier - Classifies TextBlocks as content/not-content through rules that have been determined using the C4.8 machine learning algorithm
		DensityRulesClassifier - lassifies TextBlocks as content/not-content through rules that have been determined using the C4.8 machine learning algorithm
		CanolaFilter - A full-text extractor trained on krdwrd Canola
###





class BaseFilter
	
	process: (document) ->
		# To be overridden by subclasses
		false



class FilterChain extends BaseFilter
	
	constructor: (filters) ->
		@filters = filters
	
	process: (document) ->
		hasDetectedChanges = false
		
		for filter in @filters
			hasDetectedChanges |= filter.process(document)
		
		hasDetectedChanges




class MarkEverythingContentFilter extends  BaseFilter
	
	process: (document) ->
		for textBlock in document.textBlocks
			textBlock.isContent = true


# InvertedFilter
# BoilerplateBlockFilter
# MinWordsFilter
# MinClauseWordsFilter
# SplitParagraphBlocksFilter
# SurroundingToContentFilte
# LabelToBoilerplateFilter
# LabelToContentFilter
# 

###
Heuristic Filters:
###

class SimpleBlockFusionProcessor extends BaseFilter
	
	process: (document) ->
		textBlocks = document.textBlocks
		return false if textBlocks.length < 2
		
		hasDetectedChanges = false
		previousTextBlock = textBlocks[0]
		count = 0
		
		for currentTextBlock in textBlocks[1..]
			if previousTextBlock? and previousTextBlock.textDensity == currentTextBlock.textDensity
				previousTextBlock.mergeNext(currentTextBlock)
				document.removeTextBlock(currentTextBlock)
				hasDetectedChanges = true
			else
				previousTextBlock = currentTextBlock
		
		console.log document.content()
		hasDetectedChanges


# ContentFusion
# LabelFusion

# 
#	  * Creates a new BlockProximityFusion instance.
#	  *
#	  * @param maxBlocksDistance The maximum distance in blocks.
#	  * @param contentOnly 

class BlockProximityFusion extends BaseFilter

	constructor: (maxBlocksDistance = 1, contentOnly = false, sameTagLevelOnly = false) ->
		@maxBlocksDistance = maxBlocksDistance
		@contentOnly = contentOnly
		@sameTagLevelOnly = sameTagLevelOnly
	
	
	process: (document) ->
		textBlocks = document.textBlocks
		return false if textBlocks.length < 2
		
		if @contentOnly
			startIndex = null
			
			for textBlock, index in textBlocks
				if textBlock.isContent
					startIndex = index
					break
			
			if !startIndex?
				return false
		else
			startIndex = 0
		
		
		previousTextBlock = textBlocks[startIndex]
		hasDetectedChanges = false
		
		for currentTextBlock in textBlocks[(startIndex + 1)..]
			if not currentTextBlock.isContent
				previousTextBlock = currentTextBlock
				continue 
			
			diffBlocks = currentTextBlock.offsetBlocksStart - previousTextBlock.offsetBlocksEnd - 1;
			
			if diffBlocks <= @maxBlocksDistance
				if not (@contentOnly and not previousTextBlock.isContent or not currentTextBlock.isContent) and
				not (@sameTagLevelOnly and previousTextBlock.tagLevel != currentTextBlock.tagLevel)
					previousTextBlock.mergeNext(currentTextBlock)
					document.removeTextBlock(currentTextBlock)
					hasDetectedChanges = true
					break
			
			previousTextBlock = currentTextBlock
		
		hasDetectedChanges


# KeepLargestBlockFilter
# ExpandTitleToContentFilter
# ArticleMetadataFilte
# AddPrecedingLabelsFilter


class DocumentTitleMatchClassifier extends BaseFilter
	
	constructor: (title, useDocumentTitle = false) ->
		@useDocumentTitle = useDocumentTitle 
		
		# if useDocumentTitle 
		# 	@potentialTitles = [] 
		# else
		@potentialTitles = @findPotentialTitles("title")
	
	
	findPotentialTitles: (title) ->
		title = title?.stripWhitespace()
		return null if !title? or title.length == 0
		
		potentialTitles = []
		potentialTitles.push title
		
		@longestMatch(title, pattern) for pattern in [
			/[ ]*[\||:][ ]*/,
			/[ ]*[\||:\(\)][ ]*/,
			/[ ]*[\||:\(\)\-][ ]*/,
			/[ ]*[\||,|:\(\)\-][ ]*/
		]
	
	
	process: (document) ->
		self.potentialTitles = @findPotentialTitles(document.title) if @useDocTitle
		return false if !@potentialTitles? or @potentialTitles.length == 0
		
		for textBlock in document.textBlocks
			text = textBlock.text.toLowerCase().stripWhitespace()
			
			for potentialTitle in @potentialTitles
				if potentialTitle?.toLowerCase() == text
					textBlock.addLabel(TextBlock.Title)
					return true
		
		false
	
	
	longestMatch: (title, pattern) ->
		sections = title.split pattern
		return null if sections.length == 1
		
		longestNumWords = 0
		longestPart = ""
		
		for section in sections
			continue if section.contains ".com"
			
			numWords = section.numberOfWords()
			
			if numWords > longestNumWords or section.len > longestPart.length
				longestNumWords = numWords
				longestPart = section
		
		if longestPart.length > 0 then longestPart.stripWhitespace() else false
	


 
# ###	
# English-trained Heuristic Filters:
# ###
# MinFulltextWordsFilter
# KeepLargestFulltextBlockFilter
# IgnoreBlocksAfterContentFilter
# IgnoreBlocksAfterContentFromEndFilter


class TerminatingBlocksFinder extends BaseFilter

	process: (document) ->
		hasDetectedChanges = false
		
		for textBlock in document.textBlocks
			continue if textBlock.numWords >= 15
			
			text = textBlock.text?.stripWhitespace()
			continue if text.length < 8
			
			lowercaseText = text.toLowerCase()
			
			startMatches = [" reuters", "please rate this", "post a comment"]
			inMatches = ["what you think...", "add your comment", "add comment", "reader views", "have your say", "reader comments", "rtta artikeln"]
			equalMatch = ["thanks for your comments - this feedback is now closed"]
			numbersMatch = [" comments", " users responded in"];
			
			foundMatch = false
			foundMatch |= lowercaseText in equalMatch?
			foundMatch |= lowercaseText.startsWith("comments")
			foundMatch |= !startMatches.every (match) -> !lowercaseText.startsWith(match)
			foundMatch |= !inMatches.every (match) -> !~lowercaseText.indexOf(match)
			foundMatch |= !equalMatch.every (match) -> lowercaseText != match
			foundMatch |= @startsWithNumber(lowercaseText, numbersMatch)
			
			if foundMatch
				textBlock.addLabel TextBlock.EndOfText
				hasDetectedChanges = true
		
		hasDetectedChanges


	# 
	# 	 * Checks whether the given text starts with a sequence of digits,
	# 	 * followed by one of the given strings.
	# 	 * 
	# 	 * @param t
	# 	 *			The text to examine
	# 	 * @param len
	# 	 *			The length of the text to examine
	# 	 * @param str
	# 	 *			Any strings that may follow the digits.
	# 	 * @return true if at least one combination matches
	# 	 
	startsWithNumber: (text, matchStrArr) ->
		matchesNumber = text.search /^\D/
		matchesNumber = text.length if matchesNumber < 0
		
		if matchesNumber == 0
			return false
		
		return any(text.startsWith(matchStr,pos) for matchStr in matchStrArr)
		true



class NumWordsRulesClassifier extends BaseFilter
	
	
	process: (document) ->
		textBlocks = document.textBlocks
		hasDetectedChanges= false
		
		numberOfTextBlocks = textBlocks.length
		
		for currentTextBlock, index in textBlocks
			previousTextBlock =  if index > 0 then textBlocks[index - 1] else new TextBlock()
			nextTextBlock = if index + 1 < numberOfTextBlocks then textBlocks[index + 1] else new TextBlock()
			
			hasDetectedChanges |= @classify(previousTextBlock, currentTextBlock, nextTextBlock)
		
		hasDetectedChanges
	
	
	
	classify: (previousTextBlock, currentTextBlock, nextTextBlock) ->
		isContent = true
		
		if currentTextBlock.linkDensity > 0.333333
			isContent = false
		else if previousTextBlock.linkDensity > 0.555556
			if currentTextBlock.numWords <= 16 and nextTextBlock.numWords <= 15 and previousTextBlock.numWords <= 4
				isContent = false
		else if currentTextBlock.numWords <= 40 && nextTextBlock.numWords <= 17
			isContent = false
		
		currentTextBlock.isContent = isContent


#class DensityRulesClassifier extends BaseFilter
	
	
	


# CanolaFilter







class Boilerpipe
	
	# Filter types
	@ArticleExtractor: "ArticleExtractor"
	@DefaultExtractor: "DefaultExtractor"
	@KeepEverythingExtractor: "KeepEverythingExtractor"
	
	
	contentFromHTML: (html, filterType) ->
		document = @documentFromHTML(html)
		
		# for textBlock in document.textBlocks
		# 	console.log("#{textBlock.description()}")
		
		console.log("number of text blocks: #{document.textBlocks.length}")
		
		# filterType =  if filterType?
		content = @filterTextBlocks(document, filterType)
		console.log("content: #{content.length}")
		
		content
	
	
	documentFromHTML: (html, filterType) ->
		parser = new BoilerpipeParser
		parser.parseDocumentFromHTML(html)
	
	
	filterTextBlocks: (document, filterType) ->
		filterChain = @filterChainForType(filterType)
		hasChanges = filterChain?.process(document)
		document.content()
		
	
	
	filterChainForType: (filterType) ->
		switch filterType
			
			when Boilerpipe.ArticleExtractor
				###
				A full-text extractor which is tuned towards news articles.
				In this scenario it achieves higher accuracy than DefaultExtractor.
				Works very well for most types of Article-like HTML.
				###
				
				new FilterChain([
					new TerminatingBlocksFinder(),
					new DocumentTitleMatchClassifier(null, false),
					new NumWordsRulesClassifier(),
					# new IgnoreBlocksAfterContentFilter(),
					# new BlockProximityFusion(1, false, false),
					# new BoilerplateBlockFilter(),
					# new BlockProximityFusion(1, true, false),
					# new KeepLargestBlockFilter(),
					# new ExpandTitleToContentFilter()
				])
			
			when Boilerpipe.KeepEverythingExtractor
				new FilterChain([
					new MarkEverythingContentFilter()
				])
			
			else
				###
				Boilerpipe.DefaultExtractor
				Usually worse than ArticleExtractor, but simpler/no heuristics
				A quite generic full-text extractor
				###
				
				new FilterChain([
					new SimpleBlockFusionProcessor(),
					new BlockProximityFusion(1, false, false),
					new DensityRulesClassifier()
				])
				
		
fs = require 'fs'



getContentFromHTML = (html) ->
	boilerpipe = new Boilerpipe
	boilerpipe.contentFromHTML(html, Boilerpipe.ArticleExtractor)


getContentFromFile = (filePath) ->
	fs.readFile filePath, (err, data) ->
		result = getContentFromHTML(data)


getContentFromFile('index.html')
