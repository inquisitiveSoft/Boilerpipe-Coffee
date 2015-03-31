#!/bin/bash

#Build
coffeescript-concat -I source -o "lib/Boilerpipe.coffee"
coffee --compile "lib/Boilerpipe.coffee"

coffeescript-concat -I source -I example -o "lib/Boilerpipe-Example.coffee"
browserify --transform coffeeify --extension=".coffee" "lib/Boilerpipe-Example.coffee" -o "lib/Boilerpipe-Example.js"

# Run
node "lib/Boilerpipe-Example.js"