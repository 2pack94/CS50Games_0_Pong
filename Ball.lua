--[[
    Represents a ball which will bounce back and forth between paddles
    and walls until it passes a left or right boundary of the screen,
    scoring a point for the opponent.
]]

Ball = Class{}

function Ball:init(x, y, size, start_speed)
    self.size = size
    self:setPos(x, y)
    self.dx = 0     -- velocity x in pixel per second
    self.dy = 0     -- velocity y in pixel per second
    self.start_speed = start_speed
end

--[[
    Set Ball to middle of the screen.
    set the velocity. determine the x direction of the velocity according to the serving player
    serving_player: input. int. value between 1 and 2
]]
function Ball:prepareServe(serving_player)
    self:setPos()
    -- these variables are for keeping track of our velocity on both the
    -- X and Y axis, since the ball can move in two dimensions
    -- the and/or pattern here is Lua's way of accomplishing a ternary operation
    -- math.random(lower, upper) generates integer numbers between lower and upper (both inclusive)
    -- math.random(upper) generates integer numbers between 1 and upper (both inclusive)
    self.dx = serving_player == 1 and self.start_speed or -self.start_speed
    self.dy = math.random(-50, 50)
end

--[[
    Set the Coordinates of the Ball. Set to middle of the screen if no or "nil" parameters are given
]]
function Ball:setPos(x, y)
    -- if the parameter x, y is given, they will be used instead of the default value
    self.x = x or VIRTUAL_WIDTH / 2 - self.size / 2
    self.y = y or VIRTUAL_HEIGHT / 2 - self.size / 2
end

--[[
    return the coordinates of the ball as 2 return values
]]
function Ball:getPos()
    return self.x, self.y
end

--[[
    Expects a paddle as an argument (box with x, y, width, height members) and returns true or false, depending
    on whether their rectangles overlap.
]]
function Ball:collides(paddle)
    -- check if the left edge of the ball is farther to the right than the right edge of the paddle
    -- or if the right edge of the ball is farther to the left than the left edge of the paddle
    if self.x > paddle.x + paddle.width or self.x + self.size < paddle.x then
        return false
    end

    -- check if the top edge of the ball is lower than the bottom edge of the paddle
    -- or if the bottom edge of the ball is higher than the top edge of the paddle
    if self.y > paddle.y + paddle.height or self.y + self.size < paddle.y then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

--[[
    applies velocity to position, scaled by deltaTime (dt).
]]
function Ball:update(dt)
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt
end

function Ball:render()
    love.graphics.rectangle('fill', self.x, self.y, self.size, self.size)
end
