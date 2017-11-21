----------------------------------------------------------------------------------
-- Tower Defense 1.1
-- Author: Eduardo Hauck - eduardohauck@gmail.com
-- MAIN LUA FILE
-- This is the first file called by Corona and will redirect to the first scene.
----------------------------------------------------------------------------------

-- hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- require the composer library
local composer = require "composer"

-- information accesible by all scenes
composer.centerW = display.contentWidth * .5
composer.centerH = display.contentHeight * .5

-- load start menu
composer.gotoScene( "scenes.startMenu" )