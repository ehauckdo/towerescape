----------------------------------------------------------------------------------
-- Tower Defense 1.1
-- Author: Eduardo Hauck - eduardohauck@gmail.com
-- MAIN GAME
-- This file contains the code a small score displaying screen which is shown
-- as soon as the player dies.
-- Transitions from this scene:
-- score > mainGame
----------------------------------------------------------------------------------

local sceneName = ...

local composer = require( "composer" )
local score = composer.newScene( sceneName )

local textbox
local tryAgain

local readScore
local writeScore
local restart
local parent

---------------------------------------------------------------------------------
-- initialize scene
---------------------------------------------------------------------------------
function score:create( event )
	local sceneGroup = self.view
	local params = event.params
    parent = event.parent
 	
 	textbox = display.newImage("images/score/textbox.png")
 	textbox.x = composer.centerW; textbox.y = composer.centerH - 600
 	sceneGroup:insert(textbox)

 	tryAgain = display.newImage("images/score/tryagain.png")
 	tryAgain.x = textbox.x + 52; tryAgain.y = textbox.y + 50
    tryAgain:addEventListener("touch",function() restart(sceneGroup) end)
 	sceneGroup:insert(tryAgain)

 	local gameOver = display.newText("GAME OVER", textbox.x, textbox.y-40, "Font", 25 )
	gameOver:setFillColor( 161/255, 129/255, 65/255 )
	sceneGroup:insert(gameOver)

	local scoreText = display.newText("Score: "..params.score, textbox.x-40, textbox.y, "Font", 16 )
	scoreText:setFillColor( 161/255, 129/255, 65/255 )
	sceneGroup:insert(scoreText)

    local highScore = readScore()
    if params.score > highScore then
        highScore = params.score
        writeScore(highScore);
    end

    local bestScoreText = display.newText("Best: "..highScore, textbox.x-40, textbox.y+20, "Font", 16 )
    bestScoreText:setFillColor( 161/255, 129/255, 65/255 )
    sceneGroup:insert(bestScoreText)

    local medalText = display.newText("Medal", textbox.x+52, textbox.y-15, "Font", 16 )
    medalText:setFillColor( 161/255, 129/255, 65/255 )
    sceneGroup:insert(medalText)

	local medal
    if highScore < 100 then medal = 1
    elseif highScore < 150 then medal = 2
    elseif highScore < 200 then medal = 3
    elseif highScore < 500  then medal = 4
    else medal = 5 end
    local medalSpriteSheet = graphics.newImageSheet("images/score/medals.png", { width = 25, height = 25, numFrames = 5 } )
    medal = display.newImage(medalSpriteSheet, medal)
    medal.x = textbox.x + 50; medal.y = textbox.y+15;
    sceneGroup:insert(medal)
end

restart = function(sceneGroup)
    composer.hideOverlay( "fade", 200 )
    composer.getScene( "scenes.mainGame" ):restart()
end

readScore = function()
    local path = system.pathForFile( "data/score.dat", system.ResourceDirectory )
    local file = io.open( path, "r" )
    local text = file:read("*l")
    local highScore
    if text == nil then highScore = 0
    else
        highScore = tonumber(text)
    end
    io.close( file )
    file = nil
    return highScore
end

writeScore = function(highScore)
    local path = system.pathForFile( "data/score.dat", system.ResourceDirectory )
    local file = io.open( path, "w" )
    file:write(tostring(highScore))
    io.close(file)
    file = nil
end

---------------------------------------------------------------------------------
-- show scene
---------------------------------------------------------------------------------
function score:show( event )
	local sceneGroup = self.view
    local phase = event.phase

    if phase == "will" then
        -- Called when the scene is still off screen and is about to move on screen
	elseif phase == "did" then
        transition.to(sceneGroup, {y = 580, time=2000, delta=true} )
    end

end

---------------------------------------------------------------------------------
-- hide scene
---------------------------------------------------------------------------------
function score:hide( event )
    local sceneGroup = self.view
    local phase = event.phase
    local parent = event.parent  --reference to the parent scene object

     if event.phase == "will" then
        -- Called when the scene is on screen and is about to move off screen
        -- INSERT code here to pause the scene
        -- e.g. stop timers, stop animation, unload sounds, etc.)
     elseif phase == "did" then
     	 -- Called when the scene is now off screen
         
     end
end

---------------------------------------------------------------------------------
-- destroy scene
---------------------------------------------------------------------------------
function score:destroy( event )
    local sceneGroup = self.view

    -- Called prior to the removal of scene's "view" (sceneGroup)
    -- 
    -- INSERT code here to cleanup the scene
    -- e.g. remove display objects, remove touch listeners, save state, etc
end

---------------------------------------------------------------------------------

-- Listener setup
score:addEventListener( "create", score )
score:addEventListener( "show", score )
score:addEventListener( "hide", score )
score:addEventListener( "destroy", score )

---------------------------------------------------------------------------------

return score