#!/bin/bash
coffeescript-concat -I source -I tests -o lib/Boilerpipe-Test.coffee
mocha --compilers coffee:coffee-script  lib/Boilerpipe-Test.coffee