#!/bin/bash

#Build
coffeescript-concat -I source -o "lib/Boilerpipe.coffee"
coffee --compile "lib/Boilerpipe.coffee"

coffeescript-concat -I source -I example -o "lib/Boilerpipe-Example.coffee"
browserify --transform coffeeify --extension=".coffee" "lib/Boilerpipe-Example.coffee" -o "lib/Boilerpipe-Example.js"

coffeescript-concat -I cocoa-environment -o "lib/Boilerpipe-Cocoa.coffee"
browserify --transform coffeeify --extension=".coffee" --standalone Boilerpipe "lib/Boilerpipe-Cocoa.coffee" -o "lib/Boilerpipe-Cocoa.js"

# Run
node "lib/Boilerpipe-Example.js"
