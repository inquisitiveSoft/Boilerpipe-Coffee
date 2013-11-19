#= require <CommonExtensions.coffee>


class TextBlock
	
	# Standard block labels
	@Title: "Title"
	# @ArticleMetadata: "ArticleMetadata"
	# @MightBeContent: "MightBeContent"
	# @StrictlyNotContent: "StrictlyNotContent"
	# @HorizontalRule = "@HorizontalRule"
	# @MarkupPrefix = "<"
	@EndOfText: "EndOfText"
	
	
	@DefaultFullTextWordsThreshold: 9
	
	constructor: (text, currentContainedTextElements, tagLevel, numWords, numWordsInAnchorText, numWordsInWrappedLines, numWrappedLines, offsetBlocks) ->
		@text = text?.replace /^\s+|\n+$/g, ""
		
		@currentContainedTextElements = currentContainedTextElements
		@numWords = numWords
		@numWordsInAnchorText = numWordsInAnchorText
		@numWordsInWrappedLines = numWordsInWrappedLines
		@numWrappedLines = numWrappedLines
		@offsetBlocksStart = offsetBlocks or 0
		@offsetBlocksEnd = offsetBlocks or 0
		@tagLevel = tagLevel
		@isContent = false
		
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
		@labels |= nextTextBlock.labels
		@tagLevel = Math.min @tagLevel, nextTextBlock.tagLevel
	
	
	addLabel: (label) ->
		@labels.push(label) if label?
	
	
	hasLabel: (label) ->
		return @labels.contains(label) if label?
		false
	
	numFullTextWords: (minTextDensity = TextBlock.DefaultFullTextWordsThreshold) ->
		if @textDensity >= minTextDensity then @numWords else 0



class TextDocument
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
	
	numberOfContentBlocks: () ->
		numberOfContentBlocks = 0
		
		for textBlock in @textBlocks
			if textBlock.isContent
				numberOfContentBlocks++
		
		numberOfContentBlocks
	
	
	removeTextBlock: (textBlock) ->
		@textBlocks.removeObject(textBlock)
		