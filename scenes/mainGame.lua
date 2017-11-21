----------------------------------------------------------------------------------
-- Tower Defense 1.1
-- Author: Eduardo Hauck - eduardohauck@gmail.com
-- MAIN GAME
-- This file contains the code for the main scene of the game.
----------------------------------------------------------------------------------
local sceneName = ...

local composer = require( "composer" )
local mainGame = composer.newScene( sceneName )

-- Constant Variables
local _LANE1 = 5*20 - 10 
local _LANE2 = 12*20 - 10
local _NONE = 0
local _LEFT = 1
local _RIGHT = 2
local _WAVESIZE = 480
local _WAVESIZENEW = 600
local _SPAWNPROBABILITY = 0.8
local _INVUNERABLE = false

-- Context Variables
local background
local physics
local starSound
local deadSound
local score
local time
local player
local gameActive
local backgroundMusicId
local stops

-- Forward Declarations
local initializePlayer
local newStar
local newFire
local initializeLane
local resetPlayer
local spawnWave
local onCollision
local jumpOppositeSide
local updateObjects

-- Objects Group
local objectsGroup
local scenarioGroup
local interfaceGroup

-- Aux variables
local loading
local currentLevel 
local field = {}
local clean_field = {}
local lastObjSpawned


------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- ********************* RUNTIME LISTENER FUNCTIONS *******************
--- This block contains functions called by runtime listeners.
--- They need to be implemented before setting, so we implement them here.
--- ********************************************************************
------------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------
--  Key press event, used to detect "back" button of Android
--------------------------------------------------------------------------------------------------------
local function onKeyEvent( event )
    if loading == true then
        return true
    end
    if event.keyName=="back" or ("b" == event.keyName and event.phase == "down" and system.getInfo("environment") == "simulator") then
        gameActive = false
        if composer.isOverlay then
            composer.hideOverlay()
        end
        composer.gotoScene("scenes.reload", {effect = "fade", time = 500, params = {scene = "scenes.startMenu"}})
        return true
    end
end

--------------------------------------------------------------------------------------------------------
-- Function called when user taps the screen, moves player to left or right depending on current
-- position. Calls function stops() when completed, will take care of updating atributes and sprites
--------------------------------------------------------------------------------------------------------
jumpOppositeSide = function(event)
    if player.gliding == true then
        player.gliding = false
        if player.x < composer.centerW then 
            transition.to(player, { x = 140, delta= true, time = 800, tag = "jump", onComplete= function() stops(_LEFT) end } )
            
        elseif player.x > composer.centerW then
            transition.to(player, { x = -140, delta= true, time = 800, tag = "jump", onComplete= function() stops(_RIGHT) end } )
        end
        player.gliding = false
        return true;
    end
    return true
end

stops = function(direction)
    if(player.transition > -2) then
        player.changeSpriteDirection(direction)
        player.gliding = true
    else 
        local distance
        if direction == _LEFT then distance = 140 elseif direction == _RIGHT then distance = -140 end
        transition.to(player, {x = distance, delta= true, time = 800, tag = "jump"} )
    end
end


--------------------------------------------------------------------------------------------------------
-- Collision event 
--------------------------------------------------------------------------------------------------------
onCollision = function(event)   
    local obj1 = event.object1; 
    local obj2 = event.object2;
    
    -- event collision just began
    if event.phase == "began" then  
        local player_obj; local other_obj

        if obj1.name == "player" or obj2.name == "player" then

            -- get player and other_obj references
            if obj1.name == "player" then player_obj = obj1; other_obj = obj2
            elseif obj2.name == "player" then player_obj = obj2; other_obj = obj1
            end

            -- if collision was player vs. fire, stop the game
            if other_obj.name == "enemy" or other_obj.name == "SideBlockingBar" then
                if player.invunerable == true then
                    return
                end
                player.setDead()
                audio.play(deadSound, { channel = 2 } )
                composer.showOverlay("scenes.score", {isModal=true, params = {score = time.current + score.current}} )
                gameActive = false
        
            -- if collision was player vs. bonus star, increment score
            elseif other_obj.name == "bonus" then
                score.current = score.current + 1
                score.text = score.current
                display.remove(other_obj)
                audio.play(starSound, { channel = 1 } )
 
            -- this is a counter to check how many 20x20 rope sprites the player is currently
            -- colliding with. It's a workaround to determine better when it just "slipped"
            -- from a rope to the vertical walls
            elseif other_obj.name == "laneblock" then
                player.transition = player.transition + 1
            end

        else

            -- if the collision happened between the bottom bar and another object
            -- remove the object from screen
            if obj1.name == "BottomBlockingBar" or obj2.name == "BottomBlockingBar" then
                local other_obj
                if obj1.name == "BottomBlockingBar" then other_obj = obj2
                elseif obj2.name == "BottomBlockingBar" then other_obj = obj1 end
                display.remove(other_obj)
            end

        end
        
    -- if the collision just ended
    elseif event.phase == "ended" then
        local player_obj; local other_obj

        if obj1.name == "player" then player_obj = obj1; other_obj = obj2
        elseif obj2.name == "player" then player_obj = obj2; other_obj = obj1
        else return end

        -- only one possibility here: player just left a 20x20 rope pixel, therefore
        -- it's transition variable must be decremented. If transition < 0, means he's
        -- currently colliding with any rope and must hit the wall
        if other_obj.name == "laneblock" then 
            player.transition = player.transition - 1
            if player_obj.gliding == true then
                if player.transition < 0 then
                    player_obj.gliding = false          
                    if player_obj.x < composer.centerW then transition.to(player, {x = -150, delta=true, time = 1000, tag = "jump"} ); player_obj.changeSpriteDirection("left") 
                    elseif player_obj.x > composer.centerW then transition.to(player, {x = 150, delta=true, time = 1000, tag = "jump"} ); player_obj.changeSpriteDirection("right")  end
                end
            end
        end

    end

end


------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- ************************* INITIALIZE SCENE *************************
--- This block contains instructions related to the scene creation
--- Mostly initializers of objects
--- ********************************************************************
------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------
--  Scene create
---------------------------------------------------------------------------------
function mainGame:create( event )
	local sceneGroup = self.view
    local params = event.params
    loading = true
    
    -- initialize groups
    scenarioGroup = display.newGroup()
    objectsGroup = display.newGroup()
    interfaceGroup = display.newGroup()

    -- add created groups to scene group
    sceneGroup:insert(scenarioGroup)
    sceneGroup:insert(interfaceGroup)
    sceneGroup:insert(objectsGroup)

    -- import and start physics
    physics = require ("physics") 
    physics.start(); physics.pause(); physics.setGravity( 0, 0 )

    -- load sound effects
	starSound = audio.loadSound("sfx/star.wav")
    deadSound = audio.loadSound("sfx/dead.wav")

    -- load and position static images
    background = display.newImage("images/mainGame/background.png")
    local alarm = display.newImage("images/mainGame/time.png")
    local star = display.newImage("images/mainGame/points.png")

    alarm.x = composer.centerW-35 
    alarm.y = display.screenOriginY+30
    star.x = composer.centerW+15 
    star.y = display.screenOriginY+30
    
    -- add images to respective groups
    scenarioGroup:insert(background)
    interfaceGroup:insert(star)
    interfaceGroup:insert(alarm)

    -- load text textures (time and score counters)
    time = display.newText("0", composer.centerW-15, display.screenOriginY+30, "Font", 16)
    time:setFillColor(167/255, 142/255, 94/255)
    score = display.newText("0", composer.centerW+35, display.screenOriginY+30, "Font", 16)
    score:setFillColor(167/255, 142/255, 94/255)

    -- insert text textures into score group
    interfaceGroup:insert(time)
    interfaceGroup:insert(score)

    -- initialize blocking bars; there will be:
    --  - Two on bars on each side of the the screen, to detect player's collision
    --  - One on the bottom, to detect objects off-screen and deallocate them
    local blockingBars = {}
    blockingBars[1] = display.newRect(40, composer.centerH, 1, 480)
    blockingBars[2] = display.newRect(composer.centerW*2-40, composer.centerH, 1, 480)
    blockingBars[3] = display.newRect(composer.centerW, composer.centerH*2+400, 320, 1) 

    for i = 1, 3 do
        if i < 3 then blockingBars[i].name = "SideBlockingBar" 
        else blockingBars[i].name = "BottomBlockingBar" end 
        blockingBars[i].alpha = 0
        physics.addBody( blockingBars[i] , { isSensor = true } )
        sceneGroup:insert(blockingBars[i])
    end

    initializePlayer()
    sceneGroup:insert(player)

end

---------------------------------------------------------------------------------
-- Player Initializer function. Will always spawn at his origin location.
---------------------------------------------------------------------------------
initializePlayer = function()

    -- load sprite information
    local aliveData = {
       {name = _RIGHT, frames = { 1,2 }, time = 800, loopCount = 0},
       {name = _LEFT, frames = { 3,4 }, time = 800, loopCount = 0},
       {name = "deadright", frames = {5,6,7,8,9,10,11,12}, time = 800, loopCount = 1},
       {name = "deadleft", frames = {13,14,15,16,17,18,19,20}, time = 800, loopCount = 1}
    }
    local frameSetup = {}
    for i = 1, 4 do frameSetup[i] = { x = (i-1)*30; y = 0, width = 30, height = 30} end
    for i = 5, 20 do frameSetup[i] = { x = 120+(i-5)*42, y =0, width = 42, height = 42 } end

    -- load sprite sheet and initialize player
    local pecSpriteSheet = graphics.newImageSheet("images/mainGame/pecSprite.png", {frames = frameSetup})
    player = display.newSprite(pecSpriteSheet, aliveData)
    player.name = "player"
    player.invunerable = _INVUNERABLE;
    physics.addBody( player , { radius=15, isSensor = true } )

    -- add an event to player to change the direction it's facing, based
    -- on the direction param (RIGHT or LEFT)
    function player.changeSpriteDirection(direction)
        player:setSequence(direction)
        player.facing = direction
        player:play()
    end

    -- add an event to set to player as dead; when this function is called
    -- the dying animation is called and every transition happening are stopped
    function player.setDead()
        player.gliding = false
        transition.cancel()
        player:pause()
        if player.facing == _RIGHT then
            player:setSequence("deadright")
        else
            player:setSequence("deadleft")
        end
        player:play()
    end
end

--------------------------------------------------------------------------------------------------------
-- Reset player to its initial position and initial values
--------------------------------------------------------------------------------------------------------
resetPlayer = function()
   
    player.x = _LANE2 
    player.y = 20 * 20 + 10
    
    player.direction = _NONE
    player.gliding = true       -- tells if the player is currently gliding in one of the lanes
    player.transition = -2      -- works like a semaphore, it counts how many "rope" tiles Pec has collided
                                -- if it reaches < 0, means it slipped from the rope and must float towards the wall
    player.changeSpriteDirection(_LEFT)
end

---------------------------------------------------------------------------------
-- Enemy Initializer, can be called whenever in the game.
-- x and y are the coordinates in which the enemy will be spawned.
---------------------------------------------------------------------------------
-- load sprite information
local fireSpriteSheet = graphics.newImageSheet("images/mainGame/fire.png", { width = 25, height = 25, numFrames = 3 } )
local fireData = { {name = "burning", frames={ 1,2,3 }, time=500, loopCount = 0} }

newFire = function(x, y)
    
    -- load sprite sheet and start animation
    local obj = display.newSprite(fireSpriteSheet, fireData)
    obj:setSequence("burning")
    obj:play()

    -- set enemy in the coordinates passed by param    
    obj.x = x
    obj.y = y-2

    -- set remaining enemy attributes
    obj.name = "enemy"
    physics.addBody( obj , { radius=10, isSensor = true } )
    return obj
end

---------------------------------------------------------------------------------
-- Star Initializer, can be called whenever in the game.
-- y is the coordinate in which the start will be spawned (x coordinate fixed)
---------------------------------------------------------------------------------
-- load sprite information
local starSpriteSheet = graphics.newImageSheet("images/mainGame/star.png", { width = 30, height = 30, numFrames = 4 } )
local starData = { {name = "spinning", frames={ 1,2,3,4 }, time = 650, loopCount = 0} }

newStar = function(y)

    -- load sprite sheet and start animation
    local obj = display.newSprite(starSpriteSheet, starData)
    obj:setSequence("spinning")
    obj:play()

    -- set star in the coordinates passed by param   
    obj.x = 9*20-10 
    obj.y = y

    -- set remaining star attributes
    obj.name = "bonus"
    physics.addBody( obj , { radius=15, isSensor = true } )    
    return obj
end

---------------------------------------------------------------------------------
-- Rope Initializer, can be called whenever in the game.
-- x and y are the coordinates, spriteId is the sprite of rope (whole or tips)
---------------------------------------------------------------------------------
-- load sprite information
local ropeSpriteSheet = graphics.newImageSheet("images/mainGame/rope.png", { width = 20, height = 20, numFrames = 4 } )

newRope = function(x, y, spriteId)
    -- set rope sprite and coordinates
    local obj = display.newImage(ropeSpriteSheet, spriteId)
    obj.x = x
    obj.y = y

    -- set remaining rope attributes
    obj.name = "laneblock"
    physics.addBody( obj , { isSensor = true } )
    return obj
end

--------------------------------------------------------------------------------------------------------
-- Initialize a rope lane. Rope param is a table of two arrays containing whether the rope
-- upwards is clean or has gaps. These arrays are read and corresponding sprites are loaded.
-- y param is the coordinate where the lane will be spawned (from top to bottom)
--------------------------------------------------------------------------------------------------------
initializeLane = function(rope, y)

    -- each sprite block occupies 20x20 pixels, so load one new sprite every 20 y
    for i = _WAVESIZE/20, 1, -1 do

        -- if this position in the left array is not 1 (gap in the hole) or 5 (fire)
        --[[if rope.lane1[i] ~= 1 and rope.lane1[i] ~= 5 then
            objectsGroup:insert(newRope(_LANE1, y+i*20, rope.lane1[i]))
        end

        -- same procedure from above, but for the right array (right side of the screen)
        if rope.lane2[i] ~= 1 and rope.lane2[i] ~= 5 then
            objectsGroup:insert(newRope(_LANE2, y+i*20, rope.lane2[i]))
        end

        if rope.lane1[i] == 5 then
            objectsGroup:insert(newFire(_LANE1, y + i *20 ))
        end

        if rope.lane2[i] == 5 then
            objectsGroup:insert(newFire(_LANE2, y + i *20 ))
        end]]

        -- if this position in the left array is not 1 (gap in the hole) or 5 (fire)
        if rope[0][i] ~= 5 and rope[0][i] ~= 1 then
            objectsGroup:insert(newRope(_LANE1, y+i*20, rope[0][i]))
        end

        -- same procedure from above, but for the right array (right side of the screen)
        if rope[1][i] ~= 5 and rope[1][i] ~= 1 then
            objectsGroup:insert(newRope(_LANE2, y+i*20, rope[1][i]))
        end

        if rope[0][i] == 5 then
            objectsGroup:insert(newFire(_LANE1, y + i *20 ))
        end

        if rope[1][i] == 5 then
            objectsGroup:insert(newFire(_LANE2, y + i *20 ))
        end

        lastObjSpawned = objectsGroup[objectsGroup.numChildren]

    end

end


------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ************************* SHOW SCENE *************************
--- This block contains instructions to the activation of the scene
--- Whenever the scene is (re)loaded, functions here are gonna be called
-- **************************************************************
------------------------------------------------------------------------------------------------------------------------------------------------------------------
function mainGame:show( event )
	local sceneGroup = self.view
    local phase = event.phase

    if phase == "will" then

        currentLevel = 1
        -- initialize first rope spawn ("clean", no gaps/fires)
        local rope = {}
        rope.lane1 = {}; for i = 0, _WAVESIZE/20 do rope.lane1[i] = 2 end
        rope.lane2 = {}; for i = 0, _WAVESIZE/20 do rope.lane2[i] = 2 end
        initializeLane(field[0], composer.centerH)
        initializeLane(field[0], composer.centerH-480)

        -- reset player attributes for a new game
        resetPlayer()

        -- set background position
        background.x = composer.centerW 
        background.y = 0--240-290

        -- reset all counters
        time.current = 0
        time.text = 0
        score.current = 0
        score.text = 0

        gameActive = true

	elseif phase == "did" then
        physics.start()
        loading = false
        
        -- start the background motion (will move downwards until almost off-screen, and
        -- then will be repositioned to the top of screen, where it'll go downwards again)
        --background.alpha = 1
        transition.to(background, { y = 580, tag="background", time=3830.18, delta=true, iterations=0, onComplete=function() background.y = 0 end})
        -- time counter
        timer.performWithDelay(1000, function(event) if gameActive == false then  timer.cancel(event.source); return else time.current = time.current+1; time.text = time.current end end, 0)

        -- function update ojects is responsible for moving every object (except for the
        -- player and background) down until reaching bottomLane and being deallocated
        updateObjects = function(event)
            if gameActive == false then  timer.cancel(event.source); return end

            -- Corona timers are imprecise, so we need a workaround to make sure the next wave
            -- spawns immediately after the last one AND that the pixels lost are compensated
            spawnWave(lastObjSpawned.y-10-_WAVESIZE)
            
            -- if we lost more than 200 pixels of space, spawn an extra wave
            if lastObjSpawned.y > -500 then
                spawnWave(lastObjSpawned.y-20-_WAVESIZE)
            end
            for i = 1, objectsGroup.numChildren do
                if objectsGroup[i].transitioning == nil or objectsGroup[i].transitioning == false then
                    transition.to(objectsGroup[i], {y = 1920, time = 12679.24, delta = true, tag="objects"})
                    objectsGroup[i].transitioning = true
                end
            end

            if time.current > 15 and currentLevel == 1 then currentLevel = 2 
            elseif time.current > 30 and currentLevel == 2 then currentLevel = 3 
            elseif time.current > 60 and currentLevel == 3 then currentLevel = 4 
            elseif time.current > 100 and currentLevel == 4 then currentLevel = 5  end
                
        end 
        updateObjects()
        timer.performWithDelay(3169.81, updateObjects, 0)

        


        -- Add listeners for collision and tap
        Runtime:addEventListener( "collision", onCollision )
        Runtime:addEventListener( "tap", jumpOppositeSide )
        Runtime:addEventListener( "key", onKeyEvent )
    end

end


---------------------------------------------------------------------------------
-- Spawn wave of obstacles at the vertical location y
-- type = 5 -> Fire; type = 1 -> gap; Types 3 and 4 are tips of the rope
---------------------------------------------------------------------------------


local lastField = {}; lastField[1] = 0; lastField[2] = 0; lastField[3] = 0;

function spawnWave(y)

    -- initializes two bonus stars in the "middle" of the path
    objectsGroup:insert(newStar(y+60))
    objectsGroup:insert(newStar(y+220))
    objectsGroup:insert(newStar(y+380))
    
    -- initialize a "clean" rope
    local rope = {}
    rope.lane1 = {}; rope.lane2 = {};
    for i = 1, _WAVESIZE/20 do
        rope.lane1[i] = 2; rope.lane2[i] = 2;
    end

    -- tries to get a new random field pattern different from the
    -- last three that were generated
    local newField = lastField[1]
    while newField == lastField[1] do --or newField == lastField[2] do --or newField == lastField[3] do
        newField = math.random(math.min(unpack(level[currentLevel])), math.max(unpack(level[currentLevel])))
    end
    

    f = field[newField]
    -- mirror defines if the field should be "mirrored"
    -- (fields on the left side goes to right and vice versa)
    local mirror = math.random(1,2)
    if mirror == 1 then
        for i =1, 25 do
            temp = f[0][i]
            f[0][i] = f[1][i]
            f[1][i] = temp
        end
    end

    -- reverse defines if the field should be reversed
    -- e.g. {1, 2, 3} turns into {3, 2, 1}
    local reverse = math.random(1,2)
    if reverse then
        for i = 1, 12 do
            temp = f[0][i]
            f[0][i] = f[0][25-i]
            if f[0][i] == 4 then f[0][i] = 3 elseif f[0][i] == 3 then f[0][i] = 4 end
            f[0][25-i] = temp
            if f[0][25-i] == 4 then f[0][25-i] = 3 elseif f[0][25-i] == 3 then f[0][25-i] = 4 end

            temp = f[1][i]
            f[1][i] = f[1][25-i]
            if f[1][i] == 4 then f[1][i] = 3 elseif f[1][i] == 3 then f[1][i] = 4 end
            f[1][25-i] = temp
            if f[1][25-i] == 4 then f[1][25-i] = 3 elseif f[1][25-i] == 3 then f[1][25-i] = 4 end
        end
    end

    -- initialize rope sprites and updates last field patterns
    initializeLane(f, y)
    lastField[3] = lastField[2]; lastField[2] = lastField[1]; lastField[1] = newField
end

--------------------------------------------------------------------------------------------------------
-- Prototype for the new spawn wave. It has increased size (spawns 4 stars) and spawns objects in a
-- random manner, calling spawnObstacles() function
--------------------------------------------------------------------------------------------------------
function spawnWaveNew(y)

    -- initialize bonus stars
    objectsGroup:insert(newStar(y+150))
    objectsGroup:insert(newStar(y+300))
    objectsGroup:insert(newStar(y+450))
    objectsGroup:insert(newStar(y+600))

    -- initialize "clean" ropes
    local rope = {}
    rope.lane1 = {}; rope.lane2 = {};
    for i = _WAVESIZENEW/20, 1, -1 do
        rope.lane1[i] = 2; rope.lane2[i] = 2;
    end

    -- randomize spawning obstacles
    for i = _WAVESIZENEW/20, 1, -1 do
        if(math.random() > 0.8) then i = spawnObstacle(rope, i, y) end
    end

    initializeLane(rope, y)

end

--------------------------------------------------------------------------------------------------------
-- Prototype for the spawning obstacles function. It receives:
-- rope: an array of arrays, where it'll insert the id of the randomized obstacles
-- index: index in which it finished spawning. This will be returned so the caller
--        knows up to which point the function spawned obstacles
-- y: vertical position to start spawning
--------------------------------------------------------------------------------------------------------
function spawnObstacle(rope, index, y)

    local double -- defines if it'll spawn an obstacle on both sides
    if math.random() > 0.2 then double = true else double = false end

    local side -- defines which side it'll start the spawn
    if math.random() > 0.5 then side = _LANE1 else side = _LANE2 end

    local changeside = 0.3-- defines the probability of the fire spawning changing sides

    local continue = _SPAWNPROBABILITY
    while(continue > math.random()) do
        --spawn a fire and do other stuff here
        objectsGroup:insert(newFire(side, y + index *20 ))
        continue = continue - 0.05
        index = index - 1

        if(changeside > math.random()) then
            if side == _LANE1 then side = _LANE2 else side = _LANE1 end
            changeside = 0
        end
    end

    -- -3 is an offset we want before any obstacle being spawning again in this rope
    return index - 3
end

-------------------------------------------------------------------------------------------------------------
-- hide scene
-------------------------------------------------------------------------------------------------------------
function mainGame:hide( event )
    local sceneGroup = self.view
    local phase = event.phase

     if event.phase == "will" then

        -- pause all animations
        physics.pause()
        -- cancel all transitions
        transition.cancel()
         -- Add listeners for collision and tap
        Runtime:removeEventListener( "collision", onCollision )
        Runtime:removeEventListener( "tap", jumpOppositeSide )
        Runtime:removeEventListener( "key", onKeyEvent )


     elseif phase == "did" then
     	
        -- remove all objetcs from the screen
        for i = objectsGroup.numChildren, 1, -1 do
            local obj = objectsGroup[i]
            display.remove(obj)
        end

        composer.removeScene( "scenes.mainGame" )
         
     end
end

-------------------------------------------------------------------------------------------------------------
-- This function may be called by any overlay scene (score scene, in this case)
-- Tells the current scene to reload a new game
-------------------------------------------------------------------------------------------------------------
function mainGame:restart()
    composer.gotoScene("scenes.reload", {effect = "fade", time = 500, params = {scene = "scenes.mainGame"}})
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- destroy scene
------------------------------------------------------------------------------------------------------------------------------------------------------------------
function mainGame:destroy( event )
    -- stops physics
    physics.stop()
    -- stops audio
    audio.stop(1)
    audio.stop(2)
    audio.dispose(starSound)
    audio.dispose(deadSound)

end

-------------------------------------------------------------------------------------------------------------
-- Field initialization
-------------------------------------------------------------------------------------------------------------

level = {}
field = {}
level[1] = {1, 2}
level[2] = {3, 4, 5}
level[3] = {5, 6, 7}
level[4] = {8, 9, 10}
level[5] = {9, 10, 11, 12, 13, 14, 15}

-- Clean field, no obstacles
field[0] = {}
field[0][0] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[0][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

-- LEVEL 1
field[1] = {}
field[1][0] = { 2, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[1][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[2] = {}
field[2][0] = { 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 2, 2, 2, 2, 2, 2 }
field[2][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

-- LEVEL 2 
field[3] = {}
field[3][0] = { 2, 2, 2, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 2, 2, 2, 2, 2, 2 }
field[3][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[4] = {}
field[4][0] = { 2, 2, 2, 2, 2, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[4][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2 }

field[5] = {}
field[5][0] = { 2, 2, 2, 3, 1, 1, 1, 1, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[5][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 4, 2, 2, 2, 2, 2, 2 }

-- LEVEL 3
field[6] = {}
field[6][0] = { 2, 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2 }
field[6][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[7] = {}
field[7][0] = { 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 2, 2, 2, 2, 2 }
field[7][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

-- LEVEL 4
field[8] = {}
field[8][0] = { 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2 }
field[8][1] = { 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[9] = {}
field[9][0] = { 2, 2, 2, 2, 3, 1, 1, 4, 2, 2, 2, 2, 2, 2, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2 }
field[9][1] = { 2, 2, 2, 2, 2, 2, 3, 1, 1, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[10] = {}
field[10][0] = { 2, 2, 2, 2, 3, 1, 1, 1, 1, 4, 2, 2, 2, 2, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2 }
field[10][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

-- LEVEL 5
field[11] = {}
field[11][0] = { 2, 2, 2, 2, 2, 2, 3, 1, 1, 4, 2, 2, 2, 2, 2, 2, 5, 5, 5, 2, 2, 2, 2, 2 }
field[11][1] = { 2, 2, 2, 2, 2, 2, 5, 5, 3, 1, 1, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[12] = {}
field[12][0] = { 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[12][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2 }

field[13] = {}
field[13][0] = { 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
field[13][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 2 }

field[14] = {}
field[14][0] = { 2, 2, 2, 2, 5, 5, 5, 5, 1, 1, 1, 1, 4, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2 }
field[14][1] = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }

field[15] = {}
field[15][0] = { 2, 2, 2, 5, 5, 5, 2, 2, 2, 2, 2, 2, 3, 1, 1, 1, 1, 4, 2, 2, 2, 2, 2, 2 }
field[15][1] = { 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }


---------------------------------------------------------------------------------

-- Listener setup
mainGame:addEventListener( "create", mainGame )
mainGame:addEventListener( "show", mainGame )
mainGame:addEventListener( "hide", mainGame )
mainGame:addEventListener( "destroy", mainGame )




return mainGame


