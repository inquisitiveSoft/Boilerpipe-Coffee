#!/bin/bash
coffeescript-concat -I source -I tests -o build/Boilerpipe-Test.coffee
mocha --compilers coffee:coffee-script  build/Boilerpipe-Test.coffee