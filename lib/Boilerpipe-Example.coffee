

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
	@.substring(0, match.length) == match



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





class TextBlock
	
	# Standard block labels
	@Title: "Title"
	@ArticleMetadata: "ArticleMetadata"
	@MightBeContent: "MightBeContent"
	# @StrictlyNotContent: "StrictlyNotContent"
	# @HorizontalRule = "@HorizontalRule"
	# @MarkupPrefix = "<"
	@EndOfText: "EndOfText"
	
	
	@DefaultFullTextWordsThreshold: 9
	
	constructor: (text, containedTextElements, tagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, offset) ->
		@text = text?.replace /^\s+|\n+$/g, ""
		
		@containedTextElements = containedTextElements || []
		@numWords = numWords || text?.split(/\W+/).length || 0
		@numWordsInAnchorText = numWordsInAnchorText
		@numWordsInWrappedLines = numWordsInWrappedLines
		@numWrappedLines = numWrappedLines
		@offsetStart = offset or 0
		@offsetEnd = offset or 0
		@tagLevel = tagLevel || 0
		@labels = []
		@isContent = false
		
		@calculateDensities()
	
	
	description: ->
		description = "TextBlock:\n"
		description += "   offsetStart - offsetEnd = #{@offsetStart} - #{@offsetEnd}\n"
		description += "   tagLevel = #{@tagLevel}\n"
		description += "   numWords = #{@numWords}\n"
		description += "   numWordsInAnchorText = #{@numWordsInAnchorText}\n"
		description += "   numWrappedLines = #{@numWrappedLines}\n"
		description += "   linkDensity = #{@linkDensity}\n"
		description += "   isContent = #{if @isContent then 'True' else 'False'}\n"
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
		@text += '\n' + nextTextBlock.text
		@numWords += nextTextBlock.numWords
		@numWordsInAnchorText += nextTextBlock.numWordsInAnchorText
		@numWordsInWrappedLines += nextTextBlock.numWordsInWrappedLines
		@numWrappedLines += nextTextBlock.numWrappedLines
		@offsetStart = Math.min @offsetStart, nextTextBlock.offsetStart
		@offsetEnd = Math.max @offsetEnd, nextTextBlock.offsetEnd
		
		@isContent |= nextTextBlock.isContent
		@containedTextElements.merge nextTextBlock.containedTextElements
		@labels.merge nextTextBlock.labels
		@tagLevel = Math.min @tagLevel, nextTextBlock.tagLevel
		
		@calculateDensities()
	
	
	addLabel: (label) ->
		@labels.push(label)
	
	hasLabel: (label) ->
		@labels.contains(label)
	
	numFullTextWords: (minTextDensity = TextBlock.DefaultFullTextWordsThreshold) ->
		if @textDensity >= minTextDensity then @numWords else 0



class BoilerpipeTextDocument
	###
	Text document encapsulates a title and a series of textBlocks
	###
	
	constructor: (title, textBlocks) ->
		@title = title
		@textBlocks = textBlocks
	
	content: () ->
		@text(true, false)

	contentBlocks: () ->
		@textBlocks.filter (textBlock) ->
			textBlock.isContent
	
	#	  * Returns the BoilerpipeTextDocument's content, non-content or both
	#	  * @param includeContent Whether to include TextBlocks marked as "content".
	#	  * @param includeNonContent Whether to include TextBlocks marked as "non-content".
	#	  * @return The text.
	
	text: (includeContent, includeNonContent) ->
		text = ""
		
		for textBlock in @textBlocks
			if (textBlock.isContent and includeContent) or (!textBlock.isContent and includeNonContent)
				text += textBlock.text + '\n'
		
		text
	
	numberOfContentBlocks: () ->
		numberOfContentBlocks = 0
		
		for textBlock in @textBlocks
			if textBlock.isContent
				numberOfContentBlocks++
		
		numberOfContentBlocks
	
	
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
		@offset = 0
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
		
		new BoilerpipeTextDocument(@title, @textBlocks)
	
	
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
				@title ||= @textBuffer.stripWhitespace()
			
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
			textBlock = new TextBlock(currentText, @currentContainedTextElements, @blockTagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, @offset)
			@textBlocks.push(textBlock)
			
			@offset++
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


###
	
	Filters
	=======
	
	Simple Filters:
	---------------
		MarkEverythingContentFilter - Marks all blocks as content.
		InvertedFilter - Reverts the "isContent" flag for all TextBlocks
		RemoveNonContentBlocksFilter - Removes TextBlocks which have explicitly been marked as "not content". 
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
		# Intended to be overridden by subclasses
		false



class FilterChain extends BaseFilter
	
	constructor: (filters) ->
		@filters = filters
	
	process: (document) ->
		foundChanges = false
		
		for filter in @filters
			foundChanges = filter.process(document)
		
		foundChanges




class MarkEverythingContentFilter extends  BaseFilter
	
	process: (document) ->
		for textBlock in document.textBlocks
			textBlock.isContent = true



class InvertedFilter extends  BaseFilter

	process: (document) ->
		textBlocks = document.textBlocks
		return false if textBlocks.length == 0
		
		for textBlock in textBlocks 
			textBlock.isContent = !textBlock.isContent
		
		true



class RemoveNonContentBlocksFilter extends BaseFilter
	
	process: (document) ->
		foundChanges = false
		
		for textBlock in document.textBlocks
			if !textBlock?.isContent
				document.removeTextBlock(textBlock) 
				foundChanges = true
		
		foundChanges 


class MinWordsFilter extends BaseFilter
	
	constructor: (minWords) ->
		@minWords = minWords
	
	
	process: (document) ->
		foundChanges = false
		
		for textBlock in document.textBlocks
			if textBlock.isContent and tb.getNumWords() < self.minWords
				textBlock.isContent = false
				foundChanges = true
		
		foundChanges


class MinClauseWordsFilter extends BaseFilter
	
	#  since clauses should *always end* with a delimiter, we normally
	#  don't consider text without one
	
	constructor: (minWords = 5, acceptClausesWithoutDelimiter = false) ->
		@minWords = minWords
		@acceptClausesWithoutDelimiter = acceptClausesWithoutDelimiter
	
	
	process: (document) =>
		foundChanges = false
		
		for textBlock in document.textBlocks
			if textBlock.isContent
				hasClause = false
				
				text = textBlock.text + ' '
				possibleClauses = text.split /\b[\,\.\:\;\!\?]+(?:\s+|\Z)/
				numberOfClauses = possibleClauses.length
				
				for possibleClause, currentIndex in possibleClauses
					if currentIndex < numberOfClauses - 1 or @acceptClausesWithoutDelimiter
						hasClause = @isClauseAccepted(possibleClause)
						break if hasClause
				
				if !hasClause
					textBlock.isContent = false
					foundChanges = true
		
		foundChanges
	
	
	isClauseAccepted: (text) ->
		words = text.split(/\s+/)
		words and words.length >= @minWords



class SplitParagraphBlocksFilter extends BaseFilter
	
	process: (document) ->
		foundChanges = false
		textBlocks= document.textBlocks
		newBlocks = []
		
		for textBlock in textBlocks
			paragraphs = textBlock.text.split /[\n\r]+/
			
			if paragraphs.length < 2
				newBlocks.push textBlock
			else
				isContent = textBlock.isContent
				labels = textBlock.labels
				
				for paragraph in paragraphs
					newTextBlock = new TextBlock(paragraph)
					newTextBlock.isContent = isContent
					newTextBlock.labels = labels
					newBlocks.push newTextBlock
				
				foundChanges = true
				
		document.textBlocks = newBlocks if foundChanges
		foundChanges



# class SurroundingToContentFilter extends BaseFilter
# 	
# 	constructor: (condition) ->
# 		# condition is a function which can be passed in with 
# 		# additional logic to determine if a block can be made content
# 		@condition = condition or (textBlock) ->
# 			textBlock.linkDensity == 0 and textBlock.numberOfClauses > 6
# 	
# 	process: (document) ->
# 		tbs = doc.textBlocks
# 		n=len(tbs)
# 		hasChanges=False
# 		i=1
# 		while i<n-1:
# 			prev=tbs[i-1]
# 			cur=tbs[i]
# 			next=tbs[i+1]
# 			if not cur.isContent() and prev.isContent() and next.isContent() and self.cond(cur):
# 				cur.setIsContent(True)
# 				hasChanges = True
# 				i+=2
# 			else: i+=1
# 			# WARNING: POSSIBLE BUG - in original i+=2 regardless of whether content is found.  this seems illogica to me - should be +=1
# 
# 		return hasChanges

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
		
		foundChanges = false
		previousTextBlock = textBlocks[0]
		count = 0
		
		for currentTextBlock in textBlocks[1..]
			if previousTextBlock? and previousTextBlock.textDensity == currentTextBlock.textDensity
				previousTextBlock.mergeNext(currentTextBlock)
				document.removeTextBlock(currentTextBlock)
				foundChanges = true
			else
				previousTextBlock = currentTextBlock
		
		foundChanges


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
		
		startIndex = null
		
		if @contentOnly
			for textBlock, blockIndex in textBlocks
				if textBlock.isContent
					startIndex = blockIndex
					break
			
			return false if !startIndex
		else
			startIndex = 0
		
		previousBlock = textBlocks[startIndex]
		hasFoundChanges = false
		
		for textBlock in textBlocks[startIndex + 1..]
			if not textBlock.isContent
				previousBlock = textBlock
			else 
				diffBlocks = textBlock.offsetStart - previousBlock.offsetEnd - 1;
				ok = false
			
				if diffBlocks <= @maxBlocksDistance
					if !(@contentOnly and not previousBlock.isContent or not textBlock.isContent) or
					not (@sameTagLevelOnly and previousBlock.tagLevel != textBlock.tagLevel)
						ok = true
			
				if ok
					
					previousBlock.mergeNext(textBlock)
					document.removeTextBlock(textBlock)	#remove current block
					hasFoundChanges = true
				else
					previousBlock = textBlock
		
		hasFoundChanges




class KeepLargestBlockFilter extends BaseFilter

	constructor: (expandToSameLevelText = false) ->
		@expandToSameLevelText = expandToSameLevelText
	
	process: (document) ->
		textBlocks = document.textBlocks
		return false if textBlocks.length < 2
		
		contentBlocks = textBlocks.filter (textBlock) -> textBlock.isContent
		largestBlock = contentBlocks.reduce (a, b) -> if a.numWords > b.numWords then a else b
		largestBlock?.isContent = true
		
		for textBlock in textBlocks
			if textBlock != largestBlock
				textBlock.isContent = false
				textBlock.addLabel(TextBlock.MightBeContent)
		
		if @expandToSameLevelText and largestBlock?
			tagLevelOfLargestBlock = largestBlock.tagLevel
			largestBlockIndex = textBlocks.indexOf largestBlock
		
			for textBlock in textBlocks[largestBlockIndex..]
				tagLevel = textBlock.tagLevel
				
				break if tagLevel < tagLevelOfLargestBlock
				textBlock.isContent = true if tagLevel == tagLevelOfLargestBlock
			
			for textBlock in textBlocks[..largestBlockIndex]
				tagLevel = textBlock.tagLevel
				
				break if tagLevel < tagLevelOfLargestBlock
				textBlock.isContent = true if tagLevel == tagLevelOfLargestBlock
		
		return true
	



class ExpandTitleToContentFilter extends BaseFilter
	
	process: (document) ->
		titleIndex = null
		contentStart = null
		
		for textBlock, currentIndex in document.textBlocks
			if contentStart == null and textBlock.hasLabel(TextBlock.Title)
				titleIndex = currentIndex
			
			if contentStart == null and textBlock.isContent
				contentStart = currentIndex
		
		foundChanges = false
		
		return false if contentStart <= titleIndex or titleIndex == null
		
		for textBlock in document.textBlocks[titleIndex..contentStart]
			if textBlock.hasLabel(TextBlock.MightBeContent)
				textBlock.isContent = true
				foundChanges = true
		
		foundChanges



# ArticleMetadataFilte
# AddPrecedingLabelsFilter


class DocumentTitleMatchClassifier extends BaseFilter
	
	constructor: (title, useDocumentTitle = false) ->
		@useDocumentTitle = useDocumentTitle 
		
		if useDocumentTitle 
			@potentialTitles = [] 
		else
			@potentialTitles = @findPotentialTitles("title")
	
	
	
	process: (document) ->
		potentialTitles = @findPotentialTitles(document.title) if @useDocumentTitle		
		return false if !potentialTitles or potentialTitles.length == 0
		
		for textBlock in document.textBlocks
			text = textBlock.text.normalize()
			
			for potentialTitle in potentialTitles
				if potentialTitle.normalize() == text
					textBlock.addLabel(TextBlock.Title)
					return true
		
		false
	
	
	findPotentialTitles: (title) ->
		title = title?.stripWhitespace()
		return null if !title? or title.length == 0
		
		potentialTitles = []
		potentialTitles.push title
		
		patterns = [
			/[ ]*[\||:][ ]*/,
			/[ ]*[\||:\(\)][ ]*/,
			/[ ]*[\||:\(\)\-][ ]*/,
			/[ ]*[\||,|:\(\)\-][ ]*/
		]
		
		for pattern in patterns
			match = @longestMatch(title, pattern) 
			potentialTitles.push match if match
		
		potentialTitles	
	
	
	longestMatch: (title, pattern) ->
		sections = title.split pattern
		return null if sections.length == 0
		
		longestNumberOfWords = 0
		longestSection = ""
		
		for section in sections
			if section.search ".com" == -1
				numberOfWordsInSection = section.numberOfWords()
		
				if numberOfWordsInSection > longestNumberOfWords or section.length > longestSection.length
					longestNumberOfWords = numberOfWordsInSection
					longestSection = section
		
		if longestSection.length == 0 then false else longestSection.normalize()
		
	


 
# ###	
# English-trained Heuristic Filters:
# ###


# MinFulltextWordsFilter
# KeepLargestFulltextBlockFilter


class IgnoreBlocksAfterContentFilter extends BaseFilter
	
	constructor: (minimumNumberOfWords = 60) ->
		@minimumNumberOfWords = minimumNumberOfWords


	process: (document) ->
		numWords = 0
		foundEndOfText = false
		foundChanges = false
		
		for textBlock in document.textBlocks
			if textBlock.isContent
				numWords += textBlock.numFullTextWords()
		
			if textBlock.hasLabel(TextBlock.EndOfText) and numWords >= @minimumNumberOfWords
				foundEndOfText = true
			
			if foundEndOfText
				textBlock.isContent = false
				foundChanges = true
		
		foundChanges 
	
	
# IgnoreBlocksAfterContentFromEndFilter


class TerminatingBlocksFinder extends BaseFilter

	process: (document) ->
		foundChanges = false
		
		for textBlock in document.textBlocks
			if textBlock.numWords >= 15
				continue
			
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
			foundMatch |= @isNumberFollowedByString(lowercaseText, numbersMatch)
			
			if foundMatch
				textBlock.addLabel TextBlock.EndOfText
				foundChanges = true
		
		foundChanges
	
	isNumberFollowedByString: (text, possibleMatches) ->
		matchResult= /^\W*\d+/.exec text
		
		if matchResult
			matchEnd = matchResult['index'] + matchResult[0].length
			
			for possibleMatch in possibleMatches
				if text[matchEnd..].startsWith(possibleMatch)
					return true
		
		false



class NumWordsRulesClassifier extends BaseFilter
	
	process: (document) ->
		textBlocks = document.textBlocks
		foundChanges = false
		numberOfTextBlocks  = textBlocks.length

		for currentBlock, i in textBlocks
			previousBlock = if i > 0 then textBlocks[i-1] else @newPlaceholderTextBlock
			nextBlock = if (i + 1) < numberOfTextBlocks then textBlocks[i + 1] else @newPlaceholderTextBlock
			
			isContent = true
			
			if currentBlock.linkDensity > 0.333333
				isContent = false
			else if previousBlock.linkDensity <= 0.555556
				if currentBlock.numWords <= 16 and nextBlock.numWords <= 15 and previousBlock.numWords <= 4
					isContent = false
			else if currentBlock.numWords <= 40 and nextBlock.numWords <= 17
				isContent = false
			
			foundChanges = currentBlock.isContent != isContent if not foundChanges
			currentBlock.isContent = isContent
		
		foundChanges
	
	newPlaceholderTextBlock: () ->
		new TextBlock(null, null, null, null, null, null, null, -1)




class DensityRulesClassifier extends BaseFilter
	
	process: (document) ->
		textBlocks = document.textBlocks
		foundChanges = false
		
		numberOfTextBlocks = textBlocks.length
		
		
		for currentBlock, i in textBlocks
			previousBlock = if i > 0 then textBlocks[i-1] else @newPlaceholderTextBlock
			nextBlock = if (i + 1) < numberOfTextBlocks then textBlocks[i + 1] else @newPlaceholderTextBlock
			
			isContent = false
			
			if currentBlock.linkDensity <= 0.333333
				if previousBlock.linkDensity <= 0.555556
					if currentBlock.textDensity <= 9
						if nextBlock.textDensity <= 10
							if previousBlock.textDensity > 4
								isContent = true
						else
							isContent = true
					else if nextBlock.textDensity != 0
							isContent = true
				else if nextBlock.textDensity > 11
						isContent = true
			
			foundChanges = currentBlock.isContent != isContent if not foundChanges
			currentBlock.isContent = isContent
		
		foundChanges 
	
	newPlaceholderTextBlock: () ->
		new TextBlock(null, null, null, null, null, null, null, -1)


class CanolaFilter extends BaseFilter
	
	process: (document) ->
		textBlocks = document.textBlocks
		hasChanges = False
		
	# 	n=len(textBlocks)
	# 	for i,currentBlock in enumerate(textBlocks):
	# 		if i>0: prevBlock=textBlocks[i-1]
	# 		else: prevBlock=document.TextBlock.EMPTY_START
	# 		if i+1<n: nextBlock=textBlocks[i+1]
	# 		else: nextBlock=document.TextBlock.EMPTY_START
	# 		hasChanges |= self.classify(prevBlock, currentBlock, nextBlock)
	# 	return hasChanges
	# 
	# def classify(self, prev, curr, next):
	# 	""" generated source for method classify """
	# 	cond1=curr.getLinkDensity() > 0 and next.getNumWords() > 11
	# 	cond2=curr.getNumWords() > 19
	# 	cond3=next.getNumWords() > 6 and next.getLinkDensity() == 0 and prev.getLinkDensity() == 0 and (curr.getNumWords() > 6 or prev.getNumWords() > 7 or next.getNumWords() > 19)
	# 	isContent = cond1 or cond2 or cond3
	# 	return curr.setIsContent(isContent)






class Boilerpipe
	
	# Filter types
	@DefaultExtractor: "DefaultExtractor"
	@ArticleExtractor: "ArticleExtractor"
	@KeepEverythingExtractor: "KeepEverythingExtractor"
	@LargestContentExtractor: "LargestContentExtractor"
	@CanolaExtractor: "CanolaExtractor"
	@Unfiltered: "Unfiltered"
#	@Dynamic: "Dynamic"		# Chooses
	
	
	
	@documentFromHTML: (html, filterType) ->
		parser = new BoilerpipeParser
		document = parser.parseDocumentFromHTML(html)
		
		# filterType =  if filterType?
		filterChain = @filterChainForType(filterType)
		foundChanges = filterChain?.process(document)
		document
	
	
	@filterChainForType: (filterType) ->
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
					new IgnoreBlocksAfterContentFilter(),
					new BlockProximityFusion(1, false, false),
					new RemoveNonContentBlocksFilter(),
					new BlockProximityFusion(1, true, false),
					new KeepLargestBlockFilter(),
					new ExpandTitleToContentFilter()
				])
				
			
			when Boilerpipe.LargestContentExtractor
				###
				A full-text extractor which extracts the largest text component of a page.
				For news articles, it may perform better than the {@link DefaultExtractor},
				but usually worse than {@link ArticleExtractor}.
				###
				
				new FilterChain([
					new NumWordsRulesClassifier(),
					new BlockProximityFusion(1, false, false),
					new KeepLargestBlockFilter()
				])
			
			
			when Boilerpipe.CanolaExtractor
				###
				Trained on krdwrd Canola (different definition of "boilerplate").
				You may give it a try.
				###
				
				new FilterChain([
					new CanolaFilter(),
				])
			
			
			when Boilerpipe.KeepEverythingExtractor
				###
				Only really usefull for testing the parser
				###
				
				new FilterChain([
					new MarkEverythingContentFilter()
				])
			
			
			when Boilerpipe.Unfiltered
				###
				Do nothing
				###
			
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


module.exports = Boilerpipe


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
	data = "html><body><div><p>Text</p></div></body></html>"
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
