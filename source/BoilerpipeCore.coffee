#= require BoilerpipeParser
#= require <Filters.coffee>




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
				
		