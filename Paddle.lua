--[[
Represents a paddle that can move up and down. Used in the main
program to deflect the ball back toward the opponent.
]]

Paddle = Class{}

--[[
    The `init` function on our class is called just once, when the object
    is first created. Used to set up all variables in the class and get it
    ready for use.

    Note that `self` is a reference to *this* object, whichever object is
    instantiated at the time this function is called. Different objects can
    have their own x, y, width, and height values, thus serving as containers
    for data. In this sense, they're very similar to structs in C.
]]
function Paddle:init(x, y, width, height, speed, up_key, down_key, player)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.dy = speed     -- velocity y in pixel per second
    self.up_key = up_key
    self.down_key = down_key
    self.pos_min_y = 0
    self.pos_max_y = VIRTUAL_HEIGHT - self.height
    self.mode = '1player'   -- determines if the paddle is controlled by the keyboard or by the AI (only if player 2)
    self.player = player    -- determines to which player the paddle belongs. can be 1 or 2.
    self.ball_last_y = 0    -- store the last y position of the ball
    self.is_activated = false   -- if true, enable controls
end

function Paddle:setPlayMode(play_mode)
    self.mode = play_mode
end

function Paddle:moveUp(dt)
    -- add negative paddle speed to current Y scaled by deltaTime
    -- math.max returns the greater of two values; 0 and player Y
    -- will ensure we don't go above it
    self.y = math.max(self.pos_min_y, self.y - self.dy * dt)
end

function Paddle:moveDown(dt)
    -- add positive paddle speed to current Y scaled by deltaTime
    -- math.min returns the lesser of two values; bottom of the egde minus paddle height
    -- and player Y will ensure we don't go below it
    self.y = math.min(self.pos_max_y, self.y + self.dy * dt)
end

--[[
    update paddle y position (movement)
    ball position is needed for computer controlled paddle (alternatively the whole ball object could be used as an argument, but this would be too easy)
]]
function Paddle:update(dt, ball_pos_x, ball_pos_y)
    if not self.is_activated then
        return
    end
    if self.mode == '2player' or self.player == 1 then  -- keyboard controlled paddle
        if love.keyboard.isDown(self.up_key) then
            self:moveUp(dt)
        end
        if love.keyboard.isDown(self.down_key) then
            self:moveDown(dt)
        end
    elseif self.mode == '1player' then   -- computer controlled paddle
        -- the paddle will adjust its <y position + height / 2> to the top edge of the ball
        -- if middle of paddle is below ball, move up. don't move up if ball moves down (or still), but move up if top edge of paddle is below ball
        if ((self.y + self.height / 2) > ball_pos_y) and ((self.ball_last_y > ball_pos_y) or (self.y > ball_pos_y)) then
            self:moveUp(dt)
        -- if middle of paddle is above ball, move down. don't move down if ball moves up (or still), but move down if bottom edge of paddle is above ball (some pixels margin needed here)
        elseif ((self.y + self.height / 2) < ball_pos_y) and ((self.ball_last_y < ball_pos_y) or (self.y + self.height < ball_pos_y + 3)) then
            self:moveDown(dt)
        end
        self.ball_last_y = ball_pos_y   -- keep track of the last position of the ball to determine if its moving up or down
    end
end

--[[
    To be called by our main function in `love.draw`, ideally. Uses
    LÖVE2D's `rectangle` function, which takes in a draw mode as the first
    argument as well as the position and dimensions for the rectangle. To
    change the color, one must call `love.graphics.setColor`. As of the
    newest version of LÖVE2D, you can even draw rounded rectangles!
]]
function Paddle:render()
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
end
