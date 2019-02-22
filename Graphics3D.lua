dofile("Bitmap.lua")
dofile("Geometry.lua")

local EPSILON       = 0.00001

local function Clamp(x, a, b)
  return (x < a) and a or ((x > b) and b or x)
end

local Camera =
{
  pos = false,
  lookat = false,
  zoom = 0.0,
  up = false,
  right = false,
  forward = false,
  screen_width = false,
  screen_height = false,
}

function Camera:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  if o.pos then
    o:Init()
  end
  
  return o
end

function Camera:Init()
  self.camera_zoom = self.camera_zoom or 0.0
  if self.ortographic_view then
    self:SetOrtographicView(self.ortographic_view)
  end
  self.zoomed_pos = {}
  self:SetZoom(self.zoom)
  self.up = {x = 0.0, y = 1.0, z = 0.0}
  self:SetPosLookAt(self.pos, self.lookat)
end

function Camera:SetOrtographicView(ortographic_view)
  self.ortographic_view = ortographic_view
  if ortographic_view then
    self.ortographic_view = 1.0 / ortographic_view
    self:SetZoom(0.0)
  end
end

function Camera:SetPosLookAt(pos, lookat, keep_pitch)
  local dot_unity, up = 1.0 - EPSILON, self.up
  
  local up = {x = up.x, y = up.y, z = up.z}
  local forward = {x = lookat.x - pos.x, y = lookat.y - pos.y, z = lookat.z - pos.z}
  Normalize(forward)
  local dot = Dot(forward, up)
  if dot < -dot_unity or dot > dot_unity then
    -- up and forward are parallel - rotate up a little bit
    RotateAxis(up, self.right, 0.001)
  end
  local right = Cross(up, forward)
  if keep_pitch then
		local proj_right = {x = right.x, y = 0.0, z = right.z}
		local angle = SignedAngleBetween(right, proj_right, forward)
		right = RotateAxis(right, forward, angle)
  end
  Normalize(right)
  up = Cross(forward, right)
  Normalize(up)
  
  self.pos, self.lookat = pos, lookat
  self.up, self.right, self.forward = up, right, forward
  self:SetZoom(self.zoom)
end

function Camera:SetZoom(zoom)
  self.zoom = zoom
  local pos, lookat, zoomed_pos = self.pos, self.lookat, self.zoomed_pos
  local dx, dy, dz = lookat.x - pos.x, lookat.y - pos.y, lookat.z - pos.z
  zoomed_pos.x, zoomed_pos.y, zoomed_pos.z = pos.x + zoom * dx, pos.y + zoom * dy, pos.z + zoom * dz
end

function Camera:SetScreenSize(width, height)
  self.screen_width, self.screen_height = width, height
end

function Camera:Transform2Camera(world_space)
  local zoomed_pos, right, up, forward = self.zoomed_pos, self.right, self.up, self.forward
  
  local trans_x = world_space.x - zoomed_pos.x
  local trans_y = world_space.y - zoomed_pos.y
  local trans_z = world_space.z - zoomed_pos.z
  
  local cam_x = trans_x * right.x + trans_y * right.y + trans_z * right.z   -- Dot(trans, right)
  local cam_y = trans_x * up.x + trans_y * up.y + trans_z * up.z   -- Dot(trans, up)
  local cam_z = trans_x * forward.x + trans_y * forward.y + trans_z * forward.z   -- Dot(trans, forward)
  
  return cam_x, cam_y, cam_z
end

function Camera:Transform2Screen(world_space)
  local cam_x, cam_y, cam_z = self:Transform2Camera(world_space)
  
  local screen_width, screen_height = self.screen_width, self.screen_height
  local scale = (screen_width > screen_height) and screen_width or screen_height
  local ortographic_view = self.ortographic_view
  local img_x, img_y
  if ortographic_view then
    img_x = screen_width / 2 + scale * cam_x * ortographic_view
    img_y = screen_height / 2 - scale * cam_y * ortographic_view
  else
    img_x = screen_width / 2 + scale * cam_x / cam_z
    img_y = screen_height / 2 - scale * cam_y / cam_z
  end
  
  return math.floor(img_x), math.floor(img_y)
end

local function Min(min, value)
  return (not min or value < min) and value or min
end

local function Max(max, value)
  return (not max or value > max) and value or max
end

local function DrawLine(bmp, v1, v2, color, camera)
  local v1_x, v1_y = camera:Transform2Screen(v1)
  local v2_x, v2_y = camera:Transform2Screen(v2)
  bmp:DrawLine(v1_x, v1_y, v2_x, v2_y, color)
end

local function SetCoord(pt, coord, value)
  local new_pt = {x = pt.x, y = pt.y, z = pt.z}
  new_pt[coord] = value
  
  return new_pt
end

local function DrawLabel(bmp, v1_x, v1_y, v2_x, v2_y, angle, label, label_min, label_max, color, scale, spacing)
  local w, h = bmp:MeasureText(label, scale)
  local label_dx, label_dy = RotatePoint(1000, 0, angle)
  local nx, ny = RotatePoint(1000, 0, angle + math.pi / 2)
  nx, ny = SetLen(nx, ny, h + spacing * scale, "int")
  w, h = bmp:MeasureText(label, scale)
  dx, dy = SetLen(label_dx, label_dy, w, "int")
  bmp:DrawTextRotated((v1_x + v2_x - dx) // 2 + nx, (v1_y + v2_y - dy) // 2 + ny, angle, label, color, scale)
  w, h = bmp:MeasureText(label_min, scale)
  dx, dy = SetLen(label_dx, label_dy, w, "int")
  bmp:DrawTextRotated(v1_x + nx + dx // 2, v1_y + ny + dy // 2, angle, label_min, color, scale)
  w, h = bmp:MeasureText(label_max, scale)
  dx, dy = SetLen(label_dx, label_dy, w, "int")
  bmp:DrawTextRotated(v2_x + nx - 3 * dx // 2, v2_y + ny - 3 * dy // 2, angle, label_max, color, scale)
end

local function DrawGridTile(bmp, x1, y1, x2, y2, x3, y3, x4, y4, color)
  bmp:DrawLine(x1, y1, x2, y2, color)
  bmp:DrawLine(x2, y2, x3, y3, color)
  bmp:DrawLine(x3, y3, x4, y4, color)
  bmp:DrawLine(x4, y4, x1, y1, color)
end

-- TODO: VEEEERY SLOW filling. Vertices should be projected to screen space and FillPoly implemented
local function FillGridTile(bmp, v1, v2, v3, v4, color, camera)
  local dx, dy = v2.x - v1.x, v2.y - v1.y
  local dydx = dy / dx
  local dx2, dy2 = v3.x - v4.x, v3.y - v4.y
  local dydx2 = dy2 / dx2
  local x, y = v1.x, v1.y
  local x2, y2 = v4.x, v4.y
  while x <= v2.x do
    y = v1.y + (x - v1.x) * dydx
    y2 = v4.y + (x - v4.x) * dydx2
    local img_x, img_y = camera:Transform2Screen({x = x, z = v1.z, y = y })
    local img_x2, img_y2 = camera:Transform2Screen({x = x, z = v3.z, y = y2})
    bmp:DrawLine(img_x, img_y, img_x2, img_y2, color)
    x = x + 0.001
  end
end

function DrawSurface(bmp, funcs_data, descr)
  descr = descr or {}
  
  local order = {}
  if descr.sort_cmp then
    local entries = {}
    for name, func in pairs(funcs_data.funcs) do
      table.insert(entries, {name = name, sort_idx = func.sort_idx})
    end
    table.sort(entries, descr.sort_cmp)
    for k, entry in ipairs(entries) do
      order[k] = entry.name
    end
  else
    for name in pairs(funcs_data.funcs) do
      table.insert(order, name)
    end
    table.sort(order)
  end
  
  local min_x, max_x, min_y, max_y, min_z, max_z
  for _, name in ipairs(order) do
    local func_points = funcs_data.funcs[name]
    for _, row_data in ipairs(func_points) do
      for _, pt in ipairs(row_data) do
        min_x, max_x = Min(min_x, pt.x), Max(max_x, pt.x)
        min_y, max_y = Min(min_y, pt.y), Max(max_y, pt.y)
        min_z, max_z = Min(min_z, pt.z), Max(max_z, pt.z)
      end
    end
  end
  
  local size_x, size_y, size_z = max_x - min_x, max_y - min_y, max_z - min_z
  local cam_pos = descr.camera_pos or {x = max_x + 1.5 * size_x, y = max_y + 2 * size_y, z = min_z - 3 * size_z}
  local cam_lookat = descr.camera_lookat or {x = (min_x + max_x) / 2, y = (min_y + max_y) / 2, z = (min_z + max_z) / 2}
  local camera = Camera:new{pos = cam_pos, lookat = cam_lookat}
  
  local div = descr.div or 10
  local frames_step = descr.frames_step or 1
  local start_x, start_y = descr.start_x or 0, descr.start_y or 0
  local width, height = descr.width or bmp.width, descr.height or bmp.height
  local axis_x_format, axis_y_format = descr.axis_x_format, descr.axis_y_format
  local int_x, int_y = descr.int_x, descr.int_y
  local axes_color = descr.axes_color or RGB_GRAY
  local spacing_text = descr.spacing_text or 3
  local text_scale = descr.text_scale or 1
  local label_format = descr.label_format or "%.2f"
  
  camera:SetScreenSize(width, height)
  if not descr.perspective_view then
    camera:SetOrtographicView(descr.ortographic_factor or 10.0)
  end

  local center_x, center_y = descr.center_x or min_x, descr.center_y or min_y
  local spacing_x, spacing_y = width // (div + 2), height // (div + 2)
  
  -- fill surface
  for _, name in ipairs(order) do
    local func_points = funcs_data.funcs[name]
    local color = func_points.color
    for row = 2, #func_points do
      local row_data = func_points[row]
      for col = 2, #row_data do
        local pt = row_data[col]
        if pt.fill_color then
          FillGridTile(bmp, row_data[col - 1], pt, func_points[row - 1][col], func_points[row - 1][col - 1], pt.fill_color, camera)
        end
      end
    end
  end

  -- draw surface
  local name_x = spacing_x + 10
  for _, name in ipairs(order) do
    local func_points = funcs_data.funcs[name]
    local color = func_points.color
    local last_row = {}
    local row_data = func_points[1]
    for col, pt in ipairs(row_data) do
      local x, y = camera:Transform2Screen(pt)
      last_row[col] = {x = x, y = y}
    end
    for row = 2, #func_points do
      local row_data = func_points[row]
      local v1_x, v1_y = camera:Transform2Screen(row_data[1])
      for col = 2, #row_data do
        local pt = row_data[col]
        local v2_x, v2_y = camera:Transform2Screen(pt)
        local v3, v4 = last_row[col], last_row[col - 1]
        DrawGridTile(bmp, v1_x, v1_y, v2_x, v2_y, v3.x, v3.y, v4.x, v4.y, color)
        last_row[col - 1].x, last_row[col - 1].y = v1_x, v1_y
        v1_x, v1_y = v2_x, v2_y
      end
      last_row[#last_row].x, last_row[#last_row].y = v1_x, v1_y
    end
    local w, h = bmp:MeasureText(name, text_scale)
    if descr.right_axis_Y then
      bmp:DrawText(width - name_x - w - 5, start_y + height - h, name, color, text_scale)
    else
      bmp:DrawText(start_x + name_x, start_y + height - h, name, color, text_scale)
    end
    name_x = name_x + w + 30
  end
  
  -- Draw box around the surface
  local func_points = funcs_data.funcs[next(funcs_data.funcs)]
  local v1 = SetCoord(func_points[1][1], "y", min_y)
  local v2 = SetCoord(func_points[1][#(func_points[1])], "y", min_y)
  local v3 = SetCoord(func_points[#func_points][#func_points], "y", min_y)
  local v4 = SetCoord(func_points[#func_points][1], "y", min_y)
  local v1_up = SetCoord(v1, "y", max_y)
  local v2_up = SetCoord(v2, "y", max_y)
  local v3_up = SetCoord(v3, "y", max_y)
  local v4_up = SetCoord(v4, "y", max_y)
  DrawLine(bmp, v1, v1_up, axes_color, camera)
  DrawLine(bmp, v2, v2_up, axes_color, camera)
  DrawLine(bmp, v3, v3_up, axes_color, camera)
  DrawLine(bmp, v4, v4_up, axes_color, camera)
  DrawLine(bmp, v1, v2, axes_color, camera)
  DrawLine(bmp, v2, v3, axes_color, camera)
  DrawLine(bmp, v3, v4, axes_color, camera)
  DrawLine(bmp, v1, v4, axes_color, camera)
  DrawLine(bmp, v1_up, v2_up, axes_color, camera)
  DrawLine(bmp, v2_up, v3_up, axes_color, camera)
  DrawLine(bmp, v3_up, v4_up, axes_color, camera)
  DrawLine(bmp, v4_up, v1_up, axes_color, camera)
  
  -- draw texts
  local v1_x, v1_y = camera:Transform2Screen(v1)
  local v2_x, v2_y = camera:Transform2Screen(v2)
  local v3_x, v3_y = camera:Transform2Screen(v3)
  local v1_up_x, v1_up_y = camera:Transform2Screen(v1_up)
  local dx_x, dx_y = v2_x - v1_x, v2_y - v1_y
  local dz_x, dz_y = v3_x - v2_x, v3_y - v2_y
  local dy_x, dy_y = v1_up_x - v1_x, v1_up_y - v1_y
  local angle_x = CalcOrientation(dx_x, dx_y)
  local angle_z = CalcOrientation(dz_x, dz_y)
  local angle_y = -CalcOrientation(dy_x, dy_y)
  
  DrawLabel(bmp, v1_x, v1_y, v2_x, v2_y, angle_x, funcs_data.name_x, string.format(label_format, func_points[1][1].x), string.format(label_format, func_points[1][#func_points[1]].x), axes_color, text_scale, spacing_text)
  DrawLabel(bmp, v2_x, v2_y, v3_x, v3_y, angle_z, funcs_data.name_z, string.format(label_format, func_points[1][1].z), string.format(label_format, func_points[#func_points[1]][1].z), axes_color, text_scale, spacing_text)
  DrawLabel(bmp, v1_x, v1_y, v1_up_x, v1_up_y, angle_y, funcs_data.name_y, string.format(label_format, descr.min_y), string.format(label_format, descr.max_y), axes_color, text_scale, spacing_text)
end
