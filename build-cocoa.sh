#!/bin/bash

coffeescript-concat -I source -o "lib/Boilerpipe.coffee"
coffeescript-concat -I cocoa-environment -o "lib/Boilerpipe-Cocoa.coffee"
browserify --transform coffeeify --extension=".coffee" --standalone BoilerpipeCoffee "lib/Boilerpipe-Cocoa.coffee" -o "lib/Boilerpipe-Cocoa.js"