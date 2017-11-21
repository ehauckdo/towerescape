----------------------------------------------------------------------------------
-- Tower Defense 1.1
-- Author: Eduardo Hauck - eduardohauck@gmail.com
-- START MENU
-- This file contains the code for the Main Menu scene of the game
-- Only two possible scene transitions from here:
-- startMenu -> mainGame
-- startMenu -> *opens Google Play page*
----------------------------------------------------------------------------------

local sceneName = ...
local composer = require( "composer" )
local startMenu = composer.newScene( sceneName )

    --Sounds
local backgroundMusic = {}

    --Images
local background
local titleBox 
local volumeBox
local playDialog 
local playText 
local rateDialog 
local rateText 
local stars
local pec
local volumeOn 
local volumeOff 

    --Aux
local volume
local sceneGroup
local backgroundMusicId
local loading

--------------------------------------------------------------------------------------------------------
--  Key press event, used to detect "back" button of Android
--------------------------------------------------------------------------------------------------------
local function onKeyEvent( event )
    return false
end

---------------------------------------------------------------------------------
-- initialize scene
---------------------------------------------------------------------------------
function startMenu:create( event )
	sceneGroup = self.view
    loading = true
	
    -- load and play background music
	backgroundMusic = audio.loadStream("sfx/background.mp3")
    backgroundMusicId = audio.play(backgroundMusic, { channel = 3, loops = -1, fadein = 3000 } )

    -- load image files
    background = display.newImage("images/startMenu/menuBackground.png")
    titleBox = display.newImage("images/startMenu/title.png")
    volumeBox = display.newImage("images/startMenu/volumeBox.png")
    playDialog = display.newImage("images/startMenu/dialogBox.png")
    rateDialog = display.newImage("images/startMenu/dialogBox.png")
    volumeOn = display.newImage("images/startMenu/volumeOn.png")
    volumeOff = display.newImage("images/startMenu/volumeOff.png")

    -- add static image files to scene in overlapping order
    sceneGroup:insert(background)    
    sceneGroup:insert(titleBox)
    sceneGroup:insert(volumeBox)
    sceneGroup:insert(playDialog)
    sceneGroup:insert(rateDialog)
    sceneGroup:insert(volumeOn)
    sceneGroup:insert(volumeOff)

    -- load text textures
    rateText = display.newText("Rate", composer.centerW - 70, composer.centerH + 130, "Font", 24)
    rateText:setFillColor(166/255, 134/255, 70/255)
    playText = display.newText("Play", composer.centerW + 70, composer.centerH + 130, "Font", 24)
    playText:setFillColor(166/255, 134/255, 70/255)

    -- add text textures to scene
    sceneGroup:insert(playText)
    sceneGroup:insert(rateText)

    -- load sprite sheet and sprite information tables
    local spriteSheet = graphics.newImageSheet("images/startMenu/sprites.png", {width = 30, height = 30, numFrames = 6} )
    local starData = { {name = "spinning", frames={ 1,2,3,4 }, time = 1000, loopCount = 0} }
    local pecData = { {name = "pec", frames={ 5,6 }, time = 1000, loopCount = 0} }

    -- initialize sprites and add them to scene
    pec = display.newSprite(spriteSheet, pecData)
    sceneGroup:insert(pec)
    stars = {}
    for i = 1, 5 do
        stars[i] = display.newSprite(spriteSheet, starData)
        sceneGroup:insert(stars[i])
    end

    -- load aux variables
    volume = true

    -- create event for touching the Play button
    function playDialog:touch(event)
        if event.phase == "ended" and loading == false then
            composer.gotoScene("scenes.mainGame", { effect = "fade", time = 600, params={volume=volume, bgmId=backgroundMusicId}})
        end
        return true
    end

    -- create event for touching the Rate button
    function rateDialog:touch(event)
        if event.phase == "ended" and loading == false then
            system.openURL("market://details?id=com.groundhog.games.Tower_Escape")
        end
        return true
    end

    -- create event for touching the volume toggle button
    function volumeBox:touch(event)
         if event.phase == "ended" and loading == false then
            if volume == true then
                toggleVolume(false)
            else
                toggleVolume(true)
            end
        end
    end 

end

---------------------------------------------------------------------------------
-- show scene
---------------------------------------------------------------------------------
function startMenu:show( event )
	sceneGroup = self.view
    local phase = event.phase

    if phase == "will" then
        
        -- locate images on the screen
        background.x = composer.centerW
        background.y = composer.centerH

        titleBox.x = composer.centerW
        titleBox.y = display.screenOriginY+150

        rateDialog.x = composer.centerW - 70
        rateDialog.y = composer.centerH + 130

        playDialog.x = composer.centerW + 70 
        playDialog.y = composer.centerH + 130

        volumeBox.x = composer.centerW
        volumeBox.y = composer.centerH + 200

        print(audio.getVolume())
        if audio.getVolume() == 1 then
            volumeOn.x = composer.centerW
            volumeOn.y = composer.centerH + 200
            volumeOff.x =  composer.centerW
            volumeOff.y = composer.centerH + 500
        else
            volumeOn.x = composer.centerW
            volumeOn.y = composer.centerH + 500
            volumeOff.x =  composer.centerW
            volumeOff.y = composer.centerH + 200
        end

        -- locate sprites on the scren
        local starPosition = titleBox.x - 70
        for i = 1, 5 do
            stars[i].x = starPosition + (i-1)*35
            stars[i].y = titleBox.y + 35
        end

        pec.x = composer.centerW
        pec.y = composer.centerH+50
        
	elseif phase == "did" then

        loading = false
        -- animate sprites		
        for i = 1, 5 do
            stars[i]:setSequence("spinning")
            stars[i]:play()
        end
        pec:setSequence("pec")
        pec:play()

        -- add event listeners for each dialog
        playDialog:addEventListener( "touch", playDialog )
        rateDialog:addEventListener( "touch", rateDialog )
        volumeBox:addEventListener( "touch", volumeBox )

        Runtime:addEventListener( "key", onKeyEvent )

    end

end

---------------------------------------------------------------------------------
-- hide scene
---------------------------------------------------------------------------------
function startMenu:hide( event )
    sceneGroup = self.view
    local phase = event.phase

     if event.phase == "will" then

        -- stop sprite animation
        pec:pause()
        for i = 1, 5 do
            stars[i]:pause()
        end

        -- add event listeners for each dialog
        playDialog:removeEventListener( "touch", playDialog )
        rateDialog:removeEventListener( "touch", rateDialog )
        volumeBox:removeEventListener( "touch", volumeBox )

        Runtime:removeEventListener( "key", onKeyEvent )

     end
end

---------------------------------------------------------------------------------
-- destroy scene
---------------------------------------------------------------------------------
function startMenu:destroy( event )
    audio.dispose(backgroundMusic)
    --[[ Add here object cleaning after the game is closed! ]]
end

-------------------------------------------------------------------------------------------------------------
-- Toggle volume on or off, event listener for the volume icon
-------------------------------------------------------------------------------------------------------------
function toggleVolume(toggled)
     if toggled == true then
        volume = true
        audio.resume(backgroundMusicId)
        audio.setVolume( 1 )
        volumeOn.x = composer.centerW
        volumeOn.y = composer.centerH + 200
        
        volumeOff.x =  composer.centerW
        volumeOff.y = composer.centerH + 500
    else
        volume = false
        audio.pause(backgroundMusicId)
        audio.setVolume( 0 )
        volumeOff.x = composer.centerW
        volumeOff.y = composer.centerH + 200
        
        volumeOn.x =  composer.centerW
        volumeOn.y = composer.centerH + 500
    end
end


---------------------------------------------------------------------------------

-- Listener setup
startMenu:addEventListener( "create", startMenu )
startMenu:addEventListener( "show", startMenu )
startMenu:addEventListener( "hide", startMenu )
startMenu:addEventListener( "destroy", startMenu )

return startMenu