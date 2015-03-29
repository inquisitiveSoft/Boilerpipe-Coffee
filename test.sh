#!/bin/bash
coffeescript-concat -I source -I tests -o lib/Boilerpipe-Test.coffee
mocha --compilers coffee:coffee-script/register  lib/Boilerpipe-Test.coffee