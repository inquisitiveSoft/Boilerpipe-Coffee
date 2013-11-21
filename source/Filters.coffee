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


# InvertedFilter


class RemoveNonContentBlocksFilter extends BaseFilter
	
	process: (document) ->
		foundChanges = false
		
		for textBlock in document.textBlocks
			if !textBlock?.isContent
				document.removeTextBlock(textBlock) 
				foundChanges = true
		
		foundChanges 


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


# CanolaFilter
