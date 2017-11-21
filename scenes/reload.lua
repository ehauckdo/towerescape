----------------------------------------------------------------------------------
-- Tower Defense 1.1
-- Author: Eduardo Hauck - eduardohauck@gmail.com
-- RELOAD FILE
-- This file is a workaround for reloading the game scene
-- Hopefully I'll be able to refactor it soon and remove tie file
----------------------------------------------------------------------------------
local sceneName = ...

local composer = require( "composer" )
local reload = composer.newScene( sceneName )

---------------------------------------------------------------------------------
-- show scene
---------------------------------------------------------------------------------
function reload:show( event )

	local sceneToLoad = event.params.scene

    if event.phase == "did" then
        composer.gotoScene(sceneToLoad, {effect = "fade", time = 500})
    end
end

---------------------------------------------------------------------------------

-- Listener setup
reload:addEventListener( "create", reload )
reload:addEventListener( "show", reload )
reload:addEventListener( "hide", reload )
reload:addEventListener( "destroy", reload )

---------------------------------------------------------------------------------

return reload