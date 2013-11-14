
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
