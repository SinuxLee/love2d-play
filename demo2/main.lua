local camera = {}
camera.x = 0
camera.y = 0
camera.scaleX = 1 --scale比例
camera.scaleY = 1
camera.rotation = 0  --rotation旋转

local shader = {}

function camera:set()
  love.graphics.push()
  love.graphics.rotate(-self.rotation)
  love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
  love.graphics.translate(-self.x, -self.y)
end

function camera:unset()
  love.graphics.pop()
end

function camera:move(dx, dy)
  self.x = self.x + (dx or 0)
  self.y = self.y + (dy or 0)
end

function camera:rotate(dr)
  self.rotation = self.rotation + dr
end

function camera:scale(sx, sy)
  sx = sx or 1
  self.scaleX = self.scaleX * sx
  self.scaleY = self.scaleY * (sy or sx)
end

function camera:setPosition(x, y)
  self.x = x or self.x
  self.y = y or self.y
end

function camera:setScale(sx, sy)
  self.scaleX = sx or self.scaleX
  self.scaleY = sy or self.scaleY
end

function camera:mousePosition()
    return love.mouse.getX() * self.scaleX + self.x, love.mouse.getY() * self.scaleY + self.y
  end

function love.load()
    shader = love.graphics.newShader("shader.fs")
    camera:scale(1.2)
end

-- 在 update 之后调用，只用于绘图
function love.draw()
    camera:set()

    love.graphics.setShader(shader)
    love.graphics.rectangle("fill", 0, 0, 100, 100)
    love.graphics.setShader()

    camera:unset()
end
