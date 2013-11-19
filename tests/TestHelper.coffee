#= require TextBlock

class TestHelper
	@defaultWords: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec fermentum tincidunt magna, eu pulvinar mauris dapibus pharetra. In varius, nisl a rutrum porta, sem sem semper lacus, et varius urna tellus vel lorem. Nullam urna eros, luctus eget blandit ac, imperdiet feugiat ipsum. Donec laoreet tristique mi a bibendum. Sed pretium bibendum scelerisque. Mauris id pellentesque turpis. Mauris porta adipiscing massa, quis tempus dui pharetra ac. Morbi lacus mauris, feugiat ac tempor ut, congue tincidunt risus. Pellentesque tincidunt adipiscing elit, in fringilla enim scelerisque vel. Nulla facilisi. ".split(' ')
	
	@makeDocument: (wordsArray, numAnchorWordsArray, isContentArray, labelArray) ->
		textBlocks = []
		
		for words, index in wordsArray
			if typeof(words) == 'number'
				numWords = words
				text = TestHelper.defaultWords[...numWords].join(' ')
			else
				text = words
				numWords = text.count(' ')
			
			
			numAnchorWords = numAnchorWordsArray?[index] || 0
			block = new TextBlock(text, null, null, numWords, numAnchorWords, 0, 0, index)
			block.isContent = isContentArray?[index]
			
			label = labelArray?[index]
			
			if label
				if typeof(label) == 'array'
					for l in label
						block.addLabel(l)
				else
					block.addLabel(label)
			
			textBlocks.push(block)
	
		return new TextDocument(null, textBlocks)