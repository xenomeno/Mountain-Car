local EPSILON = 0.0001

function SetLen(dir_x, dir_y, len, int)
  local cur_len = math.sqrt(dir_x * dir_x + dir_y * dir_y)
  dir_x = len * dir_x / cur_len
  dir_y = len * dir_y / cur_len
  
  if int then
    return math.floor(dir_x), math.floor(dir_y)
  else
    return dir_x, dir_y
  end
end

function PtInBounds2D(x, y, x1, y1, x2, y2)
	if x1 > x2 then
		x1, x2 = x2, x1
	end
	if y1 > y2 then
		y1, y2 = y2, y1
	end

	return x >= x1 - EPSILON and x <= x2 + EPSILON and y >= y1 - EPSILON and y <= y2 + EPSILON
end

function CalcLineEqParams2D(x1, y1, x2, y2)
		local a = y2 - y1
		local b = x1 - x2
		local c = x2 * y1 - x1 * y2
    
    return a, b, c
end

function LineInterLine2D(x1, y1, x2, y2, x3, y3, x4, y4)
	local a1, b1, c1 = CalcLineEqParams2D(x1, y1, x2, y2)
  local a2, b2, c2 = CalcLineEqParams2D(x3, y3, x4, y4)

	local D = a1 * b2 - a2 * b1
	if math.abs(D) < EPSILON then
		return
	end

	local x = (b1 * c2 - b2 * c1) / D
	local y = (a2 * c1 - a1 * c2) / D

	return x, y
end

function SegInterSeg2D(x1, y1, x2, y2, x3, y3, x4, y4)
  local x, y = LineInterLine2D(x1, y1, x2, y2, x3, y3, x4, y4)
  if x and y then
		if PtInBounds2D(x, y, x1, y1, x2, y2) and PtInBounds2D(x, y, x3, y3, x4, y4) then
      return x, y
    end
	end
end

function RotatePoint(x, y, angle, int)
  local sin = math.sin(angle)
  local cos = math.cos(angle)
  
	local rx = x * cos - y * sin
	local ry = x * sin + y * cos
  
  if int then
    return math.floor(rx), math.floor(ry)
  else
    return rx, ry
  end
end

function CalcOrientation(x1, y1, x2, y2)
  if not (x2 and y2) then
    x2, y2 = x1, y1
    x1, y1 = 0, 0
  end
  
	local x = x2 - x1
	local y = y2 - y1
  if x == 0 then
    return (y < 0) and -math.pi / 2 or math.pi / 2
  end
  
	local ret = math.atan2(y / x)
	ret = (ret < 0) and (ret + 2 * math.pi) or ret
	
  return ret
end

function CalcSignedAngleBetween(x1, y1, x2, y2)
	local a1 = math.atan(y1 / x1)
	local a2 = math.atan(y2 / x2)

	local res1 = a2 - a1
	local res2 = (a1 > a2) and (a2 - a1 + math.pi) or (a2 - a1 - math.pi)

	local ares1 = math.abs(res1)
	local ares2 = math.abs(res2)

	return (ares1 == ares2) and Max(res1, res2) or ((ares1 < ares2) and res1 or res2)
end

function TriangleArea2D(x1, y1, x2, y2, x3, y3)
	return math.abs((x1 * y2 - x2 * y1) + (x2 * y3 - x3 * y2) + (x3 * y1 - x1 * y3)) / 2.0
end

function PointInsideTriangle(x, y, x1, y1, x2, y2, x3, y3)
	local area = TriangleArea2D(x1, y1, x2, y2, x3, y3)
	local q1 = TriangleArea2D(x, y, x1, y1, x2, y2)
	local q2 = TriangleArea2D(x, y, x2, y2, x3, y3)
	local q3 = TriangleArea2D(x, y, x3, y3, x1, y1)

	return math.abs(q1 + q2 + q3 - area) < EPSILON
end

-- NOTE: assumes poly[n + 1] == poly[1]
function PolyArea2D(poly)
  local n = #poly - 1
  if #poly < 3 then return 0 end
  
  local area = 0
  local i, j, k = 2, 3, 1
  while i <= n do
    area = area + poly[i].x * (poly[j].y - poly[k].y)
    i, j, k = i + 1, j + 1, k + 1
  end
  area = area + poly[n + 1].x * (poly[2].y - poly[n].y)
  
  return area / 2.0
end

-- NOTE: assumes poly[n + 1] == poly[1]
function PtInConvexPoly2D(x, y, poly)
  local area = PolyArea2D(poly)
  local tri_area = 0
  for i = 1, #poly - 1 do
    tri_area = tri_area + TriangleArea2D(x, y, poly[i].x, poly[i].y, poly[i + 1].x, poly[i + 1].y)
  end
  
  return math.abs(area - tri_area) < EPSILON
end


function Normalize(vector)
  local x, y, z = vector.x, vector.y, vector.z
  local inv_len = 1.0 / math.sqrt(x * x + y * y + z * z)
  vector.x, vector.y, vector.z = x * inv_len, y * inv_len, z * inv_len
end

function Dot(a, b)
  return a.x * b.x + a.y * b.y + a.z * b.z
end

function Length(v)
  return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function Cross(p1, p2)
  return {x = p1.y * p2.z - p1.z * p2.y, y = p1.z * p2.x - p1.x * p2.z, z = p1.x * p2.y - p1.y * p2.x}
end

function AngleBetween(v1, v2)
	return math.acos(Clamp(Dot(v1, v2) / (Length(v1) * Length(v2)), -1.0, 1.0))
end

function SignedAngleBetween(v1, v2, vn)
	local angle = AngleBetween(v1, v2)
	
	return (Dot(Cross(v1, v2), vn) < 0.0) and -angle or angle
end

function RotateAxis(v, axis, angle)
	local s, c = math.sin(angle), math.cos(angle)

	if math.abs(axis.x) < EPSILON and math.abs(axis.y) < EPSILON then
    -- 2D rotation
		sina = (axis.z < 0) and -s or s
		local rx = v.x * c - v.y * s
		local ry = v.x * s + v.y * c
    
		return {x = rx, y = ry, z = v.z}
	end

	-- 3D rotation
  local x, y, z = axis.x, axis.y, axis.z
	local inv_len = 1.0 / math.sqrt(x * x + y * y + z * z)
	x, y, z = x * inv_len, y * inv_len, z * inv_len
  
	local u = 1 - c
	local rx = v.x * (x * x * u + 1 * c) + v.y * (y * x * u - z * s) + v.z * (z * x * u + y * s)
	local ry = v.x * (x * y * u + z * s) + v.y * (y * y * u + 1 * c) + v.z * (z * y * u - x * s)
	local rz = v.x * (x * z * u - y * s) + v.y * (y * z * u + x * s) + v.z * (z * z * u + 1 * c)

	return {x = rx, y = ry, z = rz}
end
