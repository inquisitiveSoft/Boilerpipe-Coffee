#= require Boilerpipe

#  Filters:
#= require TextBlock
#= require TerminatingBlocksFinder
#= require NumWordsRulesClassifier
#= require BlockProximityFusion
#= IgnoreBlocksAfterContentFilter

#= require TestHelper

chai = require 'chai'
chai.should()



describe "TerminatingBlocksFinder", ->
	
	it "", ->
		document = TestHelper.newDocumentWithParameters([
			"Comments",
			"Please have your say",
			"48 Comments today",
			"Comments can be the first word of article text.  If there are many words in the block, it is not comments",
			"Thanks for your comments - this feedback is now closed"
		])
		
		filter = new TerminatingBlocksFinder()
		isChanged = filter.process(document)
		
		isEndOfTextArray = document.textBlocks.map (textBlock) ->
			textBlock.labels.contains TextBlock.EndOfText
		
		[true, true, true, false, true].should.deep.equal isEndOfTextArray
		isChanged .should.be.true



describe "DocumentTitleMatchClassifier", ->
	
	it "finds the first block who's text matches the pages <title>", ->
		document = TestHelper.newDocumentWithParameters(["News", "This is the real title", "Red herring"])
		document.title = "News - This is the real title"
		
		filter = new DocumentTitleMatchClassifier(null, true)
		isChanged = filter.process(document)
		
		labels = document.textBlocks.map (textBlock) ->
			textBlock.labels
		
		labels.length.should.be.equal 3
		labels.should.deep.equal [[], [TextBlock.Title], []]
		isChanged.should.be.true



describe "NumWordsRulesClassifier", ->
	
  it "negative match", ->
		#accepts or rejects block based on machine-trained decision tree rules
		#using features from previous, current and next block (tests middle block only)
		document = TestHelper.newDocumentWithParameters([2, 10, 10], [0, 0, 0], [true, true, true])
		filter = new NumWordsRulesClassifier()
		isChanged = filter.process(document)
		
		document.textBlocks[1].isContent.should.be.false
		isChanged.should.be.true
	
	
	it "positive match", ->
		document = TestHelper.newDocumentWithParameters([10, 10, 10], [0, 0, 0], [true, true, true])
		filter = new NumWordsRulesClassifier()
		isChanged = filter.process(document)
		
		document.textBlocks[1].isContent.should.be.true
		isChanged.should.be.true



describe "IgnoreBlocksAfterContentFilter", ->
		
		it "", ->
			label = TextBlock.EndOfText
			document = TestHelper.newDocumentWithParameters([10, 30, 50, 80, 20], null, [false, true, true, true, true], [label, null, null,label, null])
			
			filter = new IgnoreBlocksAfterContentFilter(60)
			isChanged = filter.process(document)
			isContentArray = document.textBlocks.map (textBlock) ->
				textBlock.isContent
			
			isContentArray.should.deep.equals [false, true, true, false, false]
			isChanged.should.be.true



describe "BlockProximityFusion", ->
	
	it "fuses blocks which are close to each other", ->
		#fuse blocks close to each other
		document = TestHelper.newDocumentWithParameters([10, 10, 10, 10, 10, 10, 10], null, [false, true, true, true, true, true, false])
		filter = new BlockProximityFusion(1, true, false)
		
		indexesOfBlocks = document.textBlocks.map (textBlock) ->
			[textBlock.offsetStart, textBlock.offsetEnd]
		
		isChanged = filter.process(document)
		
		indexesOfBlocks = document.textBlocks.map (textBlock) ->
			[textBlock.offsetStart, textBlock.offsetEnd]
		
		indexesOfBlocks.should.deep.equal [[0, 0], [1, 5], [6, 6]]
		isChanged.should.be.true



describe "RemoveNonContentBlocksFilter", ->

	it "removes all blocks which are marked as not content", ->
		document = TestHelper.newDocumentWithParameters([5, 100, 10, 50, 80], null, [false, true, false, true, false])
		resultingTextBlocks = [document.textBlocks[1], document.textBlocks[3]]
		
		filter = new RemoveNonContentBlocksFilter()
		isChanged = filter.process(document)
		
		isContentArray = document.textBlocks.map (textBlock) ->
			textBlock.isContent
		
		isContentArray.should.deep.equals [true, true]
		document.textBlocks.should.deep.equals resultingTextBlocks
		isChanged.should.be.true



describe "KeepLargestBlockFilter", ->
	
	it "Marks the largest block as being the only content", ->
		document = TestHelper.newDocumentWithParameters([10, 10, 50, 10], null, [false, true, true, true])
		filter = new KeepLargestBlockFilter()
		isChanged = filter.process(document)
		
		isContentArray = document.textBlocks.map (textBlock) ->
			textBlock.isContent
		
		isContentArray.should.deep.equals [false, false, true, false]
		isChanged.should.be.true



describe "ExpandTitleToContentFilter", ->
	
	it "", ->
		mightBe = TextBlock.MightBeContent
		document = TestHelper.newDocumentWithParameters([10 ,10 ,10 ,10], null, [false, false, false, true], [mightBe, [mightBe, TextBlock.Title], mightBe, mightBe])
		filter = new ExpandTitleToContentFilter()
				
		isChanged = filter.process(document)
		
		isContentArray = document.textBlocks.map (textBlock) ->
			textBlock.isContent
		
		isContentArray.should.deep.equals [false, true, true, true]
		isChanged.should.be.true



describe "DensityRulesClassifier", ->
	
	it "", ->
		#accepts or rejects block based on a different set of machine-trained decision tree rules
		#using features from previous, current and next block
		document = TestHelper.newDocumentWithParameters([10, 10, 5], [10, 0, 0], [true, true, true])
		filter = new DensityRulesClassifier()
		isChanged = filter.process(document)
		
		document.textBlocks[1].isContent.should.be.false
		isChanged.should.be.true




describe "TextBlock", ->
	
	it "calculate tag levels", ->
		template = "<html><body><div><p><span><a href='x.html'>*</a></span></p>*</div></body></html>"
		document = TestHelper.newDocumentWithTemplateAndContent template, [5, 6]
		
		textBlocks= document.textBlocks
		tagLevelArray = textBlocks.map (textBlock) ->
			textBlock.tagLevel
		
		tagLevelArray.should.deep.equal [5, 3]
	
	
	it "merges text blocks into one", ->
		block1 = new TextBlock("AA BB CC ", [0], null, 3, 3, 3, 1, 0)
		block1.addLabel(TextBlock.MightBeContent)
		
		block2 = new TextBlock("DD EE FF GG HH II JJ .", [1], null, 6, 0, 6, 2, 1)
		block2.addLabel(TextBlock.ArticleMetadata)
		
		block1.mergeNext(block2)
		
		
		block1.text.should.equal "AA BB CC \nDD EE FF GG HH II JJ ."
		block1.numWords.should.equal 9
		block1.numWordsInAnchorText.should.equal 3
		block1.linkDensity.should.equal 1.0 / 3.0
		block1.textDensity.should.equal 3
		
		block1.labels.should.deep.equal [TextBlock.MightBeContent, TextBlock.ArticleMetadata]
		block1.offsetStart.should.equal 0
		block1.offsetEnd.should.equal 1

