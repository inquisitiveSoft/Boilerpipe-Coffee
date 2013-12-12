#= require TextBlock

class TestHelper
	@defaultWords: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec fermentum tincidunt magna, eu pulvinar mauris dapibus pharetra. In varius, nisl a rutrum porta, sem sem semper lacus, et varius urna tellus vel lorem. Nullam urna eros, luctus eget blandit ac, imperdiet feugiat ipsum. Donec laoreet tristique mi a bibendum. Sed pretium bibendum scelerisque. Mauris id pellentesque turpis. Mauris porta adipiscing massa, quis tempus dui pharetra ac. Morbi lacus mauris, feugiat ac tempor ut, congue tincidunt risus. Pellentesque tincidunt adipiscing elit, in fringilla enim scelerisque vel. Nulla facilisi. ".split(' ')
	
	
	
	@documentWithParameters: (wordsArray, numAnchorWordsArray, isContentArray, labelArray) ->
		textBlocks = []
		
		for word, index in wordsArray
			if typeof(word) == 'number'
				text = @exampleText word
			else
				text = word
				numWords = text.split(' ').count
			
			
			numAnchorWords = numAnchorWordsArray?[index] or 0
			
			block = new TextBlock(text, null, null, numWords, numAnchorWords, 0, 0, index)
			block.isContent = isContentArray?[index]
			
			label = labelArray?[index]
			
			if label
				if label instanceof Array
					for l in label
						block.addLabel l
				else
					block.addLabel label
			
			textBlocks.push(block)
		
		new BoilerpipeTextDocument(null, textBlocks)
	
	
	
	@documentFromTemplate: (templateString, contentArray, filterType) ->
		templateArray = templateString.split '*'
		html = ""
		templateArrayLength = templateArray.length
		
		for templateSection, currentIndex in templateArray
			content = ''
			
			if currentIndex < templateArrayLength - 1
				content = contentArray[currentIndex]
			
				if typeof(content) == 'number'
					content = @exampleText content
			
			html += templateSection + content
		
		filterType ||= Boilerpipe.Unfiltered
		Boilerpipe.documentFromHTML(html, filterType)
		
		
	@exampleText: (desiredNumberOfWords = 10) ->
		TestHelper.defaultWords[...desiredNumberOfWords].join(' ')

