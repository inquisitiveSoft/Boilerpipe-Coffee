#= require Boilerpipe

#  Filters:
#= require NumWordsRulesClassifier
#= require BlockProximityFusion

#= require TestHelper

fs = require 'fs'
request = require 'request'

chai = require 'chai'
chai.should()


# 
# describe "NumWordsRulesClassifier filter", ->
# 	
#   it "negative match", ->
# 		#accepts or rejects block based on machine-trained decision tree rules
# 		#using features from previous, current and next block (tests middle block only)
# 		document = TestHelper.makeDocument([2, 10, 10], [0, 0, 0], [true, true, true])
# 		filter = new NumWordsRulesClassifier()
# 		isChanged = filter.process(document)
# 		document.textBlocks[0].isContent.should.be.false
# 		
# 	# it "positive match", ->
# 	# 	document = TestHelper.makeDocument([10, 10, 10], [0, 0, 0], [true, true, true])
# 	# 	filter = new NumWordsRulesClassifier()
# 	# 	isChanged = filter.process(document)
# 	# 	
# 	# 	console.log document.textBlocks
# 	# 	document.textBlocks[0].isContent.should.be.true
# 	# 
# 
# 
# describe "BlockProximityFusion filter", ->
# 	
# 	it "fuses blocks which are close to each other", ->
# 		#fuse blocks close to each other
# 		document = TestHelper.makeDocument([10, 10, 10, 10, 10, 10, 10], null, [false, true, true, true, true, true, false])
# 		filter = new BlockProximityFusion(1, true, false)
# 		
# 		indexesOfBlocks = ([textBlock.offsetBlocksStart, textBlock.offsetBlocksEnd] for textBlock in document.textBlocks)
# 		console.log indexesOfBlocks
# 		
# 		isChanged = filter.process(document)
# 		
# 		indexesOfBlocks = ([textBlock.offsetBlocksStart, textBlock.offsetBlocksEnd] for textBlock in document.textBlocks)
# 		console.log indexesOfBlocks
# 		
# 		indexesOfBlocks.should.equal [[0, 0], [1, 5], [6, 6]]
# 		isChanged.should.be.true
# 		
