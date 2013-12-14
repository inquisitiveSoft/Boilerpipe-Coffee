#= require <Parser.coffee>
#= require <Document.coffee>
#= require <Filters.coffee>


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
