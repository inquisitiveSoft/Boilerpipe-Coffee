#!/bin/bash
coffeescript-concat -I source -o build/Boilerpipe.coffee
coffee --compile build/Boilerpipe.coffee
coffee build/Boilerpipe.coffee

# coffee build/Boilerpipe.coffee > coffee-output.txt