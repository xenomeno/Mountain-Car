TileCoding =
{
  tilings = false,
  min_x = false, max_x = false, min_y = false, max_y = false,
  displace_x = false, displace_y = false,
  size_x = false, size_y = false,
  tile_width = false, tile_height = false,
  actions = false,
  tiling_start = false,
  action_weights = false,
}

function TileCoding:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  if o.actions then
    o:Init()
  end
  
  return o
end

function TileCoding:Init()
  self.tiling_start = {}
  local offset_x = self.displace_x * self.tile_width / self.tilings
  local offset_y = self.displace_y * self.tile_height / self.tilings
  for tiling = 1, self.tilings do
    self.tiling_start[tiling] = {x = self.min_x + (tiling - 1) * offset_x, y = self.min_y + (tiling - 1) * offset_y}
  end
  
  self.size_x, self.size_y = self.max_x - self.min_x, self.max_y - self.min_y
  self.action_weights = {}
  local width, height = math.ceil(self.size_x / self.tile_width), math.ceil(self.size_y / self.tile_height)
  for _, action in ipairs(self.actions) do
    local weights = {}
    for tiling_idx = 1, self.tilings do
      local tiling = {}
      for tile_y = 1, height do
        tiling[tile_y] = {}
        for tile_x = 1, width do
          tiling[tile_y][tile_x] = 0.0
        end
      end
      weights[tiling_idx] = tiling
    end
    self.action_weights[action] = weights
  end
end

function TileCoding:GetRowCol(x, y, start)
  if x < start.x or y < start.y then return end
  
  local tile_width, tile_height = self.tile_width, self.tile_height
  local col = 1 + math.floor((x - start.x) / tile_width)
  local row = 1 + math.floor((y - start.y) / tile_height)
  col = col - ((col * tile_width >= self.size_x) and 1 or 0)
  row = row - ((row * tile_height >= self.size_y) and 1 or 0)
  
  return col, row
end

function TileCoding:GetValue(x, y, a)
  local weights = self.action_weights[a]
  local tiling_start = self.tiling_start
  local value = 0.0
  for tiling_idx, tiling in ipairs(weights) do
    local col, row = self:GetRowCol(x, y, tiling_start[tiling_idx])
    if row and col then
      value = value + tiling[row][col]
    end
  end
    
  return value
end

function TileCoding:Update(x, y, a, delta)
  local weights = self.action_weights[a]
  local tiling_start = self.tiling_start
  for tiling_idx, tiling in ipairs(weights) do
    local col, row = self:GetRowCol(x, y, tiling_start[tiling_idx])
    if row and col then
      tiling[row][col] = tiling[row][col] + delta
    end
  end
end
