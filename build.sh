#!/bin/bash
coffeescript-concat -I source -I example -o build/Boilerpipe.coffee
coffeescript-concat -I source -I example -o build/Boilerpipe-Example.coffee
# coffee --compile build/Boilerpipe-Compiled.coffee

# Run
coffee build/Boilerpipe-Example.coffee
