--[[
    GD50 2018
    Pong Remake

    -- Main Program --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.

    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on 
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

local PADDLE_SPEED = 200  -- movind speed of the paddles in pixels per second; multiplied by dt in update
local PADDLE_WIDTH = 5
local PADDLE_HEIGHT = 20
local PADDLE_POS_OFFSET_Y = 30    -- number of pixels the paddels are offset from the horizontal borders of the screen at the start
local PADDLE_POS_OFFSET_X = 10    -- number of pixels the paddels are offset from the vertical borders of the screen

local BALL_SIZE = 4             -- heigth and width of the ball
local BALL_START_SPEED = 150    -- velocity of the ball when the game starts in pixels per second
local BALL_INC_VELO = 1.03      -- factor by which the velocity of the ball increases every time it hits a paddle

local SCORE_TO_WIN = 5

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0/255, 255/255, 0/255, 255/255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 20, 10)
end

--[[
    Runs when the game first starts up, only once; used to initialize the game.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)

    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions. replaces love.window.setMode
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    -- set the title of the application window
    love.window.setTitle("Pong")

    -- set up our sound effects; later, we can just index this table and call each entry's `play` method
    -- type "static" means that the audio file is loaded in memory at initialization time
    -- sounds table. a table is a dictionary (key value pairs)
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }

    -- "seed" the RNG so that calls to random are always random
    -- use the current time, since that will vary on startup every time
    math.randomseed(os.time())

    -- initialize score variables, used for rendering on the screen and keeping track of the winner
    player1Score = 0
    player2Score = 0
    -- either going to be 1 or 2; whomever is scored on gets to serve the following turn
    servingPlayer = 1
    -- player who won the game; not set to a proper value until we reach that state in the game
    winningPlayer = 0
    -- playMode is either '1player' or '2player'.
    -- if '2player' both paddles are conrolled by the keyboard. if '1player' the right paddle is controlled by the computer
    playMode = '1player'

    -- left paddle is player1
    player1 = Paddle(
        PADDLE_POS_OFFSET_X, 
        PADDLE_POS_OFFSET_Y, 
        PADDLE_WIDTH, PADDLE_HEIGHT, PADDLE_SPEED, 'w', 's', 1)
    -- right paddle is player2
    player2 = Paddle(
        VIRTUAL_WIDTH - PADDLE_POS_OFFSET_X - PADDLE_WIDTH, 
        VIRTUAL_HEIGHT - PADDLE_POS_OFFSET_Y - PADDLE_HEIGHT, 
        PADDLE_WIDTH, PADDLE_HEIGHT, PADDLE_SPEED, 'up', 'down', 2)

    -- initialize the ball object. use default position by using "nil" (=None) as parameters for the x, y coordinates
    ball = Ball(nil, nil, BALL_SIZE, BALL_START_SPEED)

    -- game state variable used to transition between different parts of the game
    -- (used for beginning, menus, main game, high score list, etc.)
    -- we will use this to determine behavior during render and update
    gameState = 'start'
end

--[[
    Called by LÖVE whenever we resize the screen; here, we just want to pass in the
    width and height to push so our virtual resolution can be resized as needed.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Keyboard handling, called by LÖVE2D when a key is pressed; 
    passes in the key we pressed so we can access.
]]
function love.keypressed(key)
    -- keys can be accessed by string name
    if key == 'escape' then
        -- function LÖVE gives us to terminate application
        love.event.quit()
    -- if we press enter during the start state of the game, we'll go into play mode
    -- during play mode, the ball will move in a random direction
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' or gameState == 'done' then
            player1Score = 0
            player2Score = 0
            -- the serving player will be the player who lost the last match or player 1 if first match
            gameState = 'serve'
            player1.is_activated = true
            player2.is_activated = true
        elseif gameState == 'serve' then
            gameState = 'play'
            ball:prepareServe(servingPlayer)
        end
    elseif (key == 'right' or key == 'left') and gameState == 'start' then
        -- change the game mode
        -- the and/or pattern here is Lua's way of accomplishing a ternary operation
        playMode = playMode == '1player' and '2player' or '1player'
        player2:setPlayMode(playMode)
    end
end

--[[
    Runs every frame, with "dt" passed in, our delta in seconds 
    since the last frame, which LÖVE2D supplies us.
]]
function love.update(dt)
    -- if the games freezes (e.g. when the window gets moved), dt gets accumulated and will be applied in the next update.
    -- prevent the glitches caused by that by limiting dt to 0.07 (about 1/15) seconds.
    dt = math.min(dt, 0.07)

    if gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering dy based on the previous direction of dy
        -- if collision: put the ball in front of the surface so it won't still be inside the paddle/ playfield boundary on the next frame (then the ball would get stuck)
        if ball:collides(player1) or ball:collides(player2) then
            ball.dx = -ball.dx * BALL_INC_VELO
            sounds['paddle_hit']:play()

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end
            if ball:collides(player1) then
                ball.x = player1.x + player1.width
            end
            if ball:collides(player2) then
                ball.x = player2.x - ball.size
            end
        end

        -- detect upper and lower screen boundary collision and reverse if collided
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        if ball.y >= VIRTUAL_HEIGHT - ball.size then
            ball.y = VIRTUAL_HEIGHT - ball.size
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left or right edge of the screen, update the score and change the game state
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()
            ball:setPos()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == SCORE_TO_WIN then
                winningPlayer = 2
                gameState = 'done'
                player1.is_activated = false
                player2.is_activated = false
            else
                gameState = 'serve'
            end
        end

        if ball.x + ball.size > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()
            ball:setPos()

            if player1Score == SCORE_TO_WIN then
                winningPlayer = 1
                gameState = 'done'
                player1.is_activated = false
                player2.is_activated = false
            else
                gameState = 'serve'
            end
        end

        ball:update(dt)
    end

    player1:update(dt)                  -- player 1 movement
    player2:update(dt, ball:getPos())   -- player 2 movement (needs ball position if computer controlled)

end

--[[
    Called after update by LÖVE2D, used to draw anything to the screen, updated or otherwise.
]]
function love.draw()
    -- begin rendering at virtual resolution
    push:start()

    -- clear the screen with a specific color; in this case, a color similar
    -- to some versions of the original Pong
    love.graphics.clear(40/255, 45/255, 52/255, 255/255)

    love.graphics.setFont(smallFont)
    if gameState == 'start' then
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        if playMode == '1player' then
            love.graphics.printf('< 1 Player >', 0, 20, VIRTUAL_WIDTH, 'center')
        else
            love.graphics.printf('< 2 Player >', 0, 20, VIRTUAL_WIDTH, 'center')
        end
        love.graphics.printf('Press Enter to begin!', 0, 30, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        if playMode == '1player' then
            if servingPlayer == 1 then
                love.graphics.printf('You serve', 0, 10, VIRTUAL_WIDTH, 'center')
            else
                love.graphics.printf('Computer serves', 0, 10, VIRTUAL_WIDTH, 'center')
            end
        else    -- 2 Player Mode
            love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 0, 10, VIRTUAL_WIDTH, 'center')
        end
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'done' then
        love.graphics.setFont(largeFont)
        if playMode == '1player' then
            if winningPlayer == 1 then
                love.graphics.printf('You win!', 0, 10, VIRTUAL_WIDTH, 'center')
            else
                love.graphics.printf('You lose!', 0, 10, VIRTUAL_WIDTH, 'center')
            end
        else    -- 2 Player Mode
            love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' won!', 0, 10, VIRTUAL_WIDTH, 'center')
        end
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    -- draw score on the left and right center of the screen
    -- need to switch font to draw before actually printing
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 45, VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30, VIRTUAL_HEIGHT / 3)

    player1:render()    -- render left paddle (player1)
    player2:render()    -- render right paddle (player2)
    ball:render()       -- render ball

    displayFPS()

    -- end rendering at virtual resolution
    push:finish()
end
