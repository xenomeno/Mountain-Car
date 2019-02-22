dofile("Bitmap.lua")
dofile("Geometry.lua")
dofile("Graphics.lua")
dofile("Graphics3D.lua")
dofile("RL_TileCoding.lua")

local ALPHA                           = 0.3
local GAMMA                           = 1.0
local EPSILON                         = 0.0
local TILE_DISPLACEMENT               = {x = 3, y = 1}

local POSITION_MIN                    = -1.2
local POSITION_MAX                    = 0.5
local VELOCITY_MIN                    = -0.7
local VELOCITY_MAX                    = 0.7
local POSITION_START_MIN              = -0.6
local POSITION_START_MAX              = -0.4
local VELOCITY_START                  = 0.0

local REWARD                          = -1.0
local THROTLE_FORWARD                 = 1
local THROTLE_REVERSE                 = -1
local THROTLE_ZERO                    = 0
local ACTIONS                         = { THROTLE_FORWARD, THROTLE_REVERSE, THROTLE_ZERO}
local POSITION_SIZE                   = POSITION_MAX - POSITION_MIN
local VELOCITY_SIZE                   = VELOCITY_MAX - VELOCITY_MIN
local TILINGS                         = 8
local TILE_DIVISION                   = 8         -- on how many tiles each dimension is divided
local TILE_WIDTH                      = POSITION_SIZE / TILE_DIVISION
local TILE_HEIGHT                     = VELOCITY_SIZE / TILE_DIVISION
local MAX_EPISODES                    = 9000
local MAX_STEPS                       = 1000000
local ACTION_VALUE_EPSILON            = 0.0001

local Y_SCALE                         = 1.0

local MOMENTS_EPISODE_STEPS           = {[1] = 428, [12] = true, [104] = true, [1000] = true, [MAX_EPISODES] = true}

local ALPHAS                          = {0.1, 0.2, 0.5}
local ALPHAS_NSTEP_SARSA              = {[1] = 0.5, [8] = 0.3}    -- the key is n-step, the value is the alpha
local ALPHAS_EPSILON                  = 0.1
local RUNS                            = 100
local RUN_EPISODES                    = 500

local ALPHA_VS_N                      =
{
  {n = 1, alphas = {0.4, 0.5, 0.75, 1.0, 1.5, 1.75}}, 
  {n = 2, alphas = {0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.5, 1.75}}, 
  {n = 4, alphas = {0.20, 0.25, 0.3, 0.35, 0.40, 0.45, 0.5, 0.55, 0.60, 0.7, 1.0, 1.2, 1.4, 1.5}},
  {n = 8, alphas = {0.13, 0.16, 0.18, 0.2, 0.3, 0.4, 0.45, 0.5, 0.55, 0.6, 0.7, 0.9, 1.0}},
  {n = 16, alphas = {0.2, 0.25, 0.30, 0.35, 0.40, 0.5, 0.55, 0.6, 0.7, 0.8}},
}
local ALPHA_N_EPISODES                = 50
local ALPHA_N_RUNS                    = 100

local IMAGE_WIDTH                     = 1000
local IMAGE_HEIGHT                    = 1000
local GRID_SIZE                       = 40
local IMAGE_EPISODE1_FILENAME         = "MountainCar/Fig10_1_MountainCar_Episode1_%05d.bmp"
local IMAGE_FILENAME                  = "MountainCar/Fig10_1_MountainCar_%05d.bmp"
local IMAGE_COMPARE_FILENAME          = "MountainCar/Fig10_2_MountainCar_Compare.bmp"
local IMAGE_COMPARE_NSTEP_FILENAME    = "MountainCar/Fig10_3_MountainCar_Compare_NStep.bmp"
local IMAGE_ALPHA_VS_N_FILENAME       = "MountainCar/Fig10_4_MountainCar_N_VS_Alpha.bmp"
local IMAGE_CAR                       = "e:/Fig10_1_MountainCar_Movement_Episode%05d_%05d.bmp"

local function Min(a, b)
  return (a < b) and a or b
end

local function Clamp(x, a, b)
  return (x < a) and a or ((x > b) and b or x)
end

local function GetNextPos(pos, speed)
  return Clamp(pos + speed, POSITION_MIN, POSITION_MAX)
end

local function GetNextSpeed(pos, speed, action)
  return Clamp(speed + 0.001 * action - 0.0025 * math.cos(3 * pos), VELOCITY_MIN, VELOCITY_MAX)
end

local function GetNextState(pos, speed, action)
  speed = GetNextSpeed(pos, speed, action)
  pos = GetNextPos(pos, speed)
  speed = (pos == POSITION_MIN) and VELOCITY_START or speed
  
  return pos, speed, REWARD
end

local function DrawCostToGo(VF, name, filename, step)
  local func_data = {color = RGB_GREEN}
  local min_y, max_y
  for s = 0, GRID_SIZE - 1 do
    func_data[s + 1] = {}
    local speed = VELOCITY_MIN + VELOCITY_SIZE * s / (GRID_SIZE - 1)
    for p = 0, GRID_SIZE - 1 do
      local pos = POSITION_MIN + (POSITION_SIZE + 0.1) * p / (GRID_SIZE - 1) -- give it a little bit extra vis
      local cost = VF:CostToGo(pos, speed)
      cost = (cost < 0) and 0 or cost
      min_y = (not min_y or cost < min_y) and cost or min_y
      max_y = (not max_y or cost > max_y) and cost or max_y
      func_data[s + 1][p + 1] = {x = pos, z = speed, y = cost, fill_color = (pos >= POSITION_MAX) and RGB_RED}
    end
  end
  -- scale Y to be max Y_SCALE
  if math.abs(min_y - max_y) < 0.001 then
    max_y = min_y + 0.0001
  end
  local scale = Y_SCALE / (max_y - min_y)
  for _, row in ipairs(func_data) do
    for _, pt in ipairs(row) do
      pt.y = (pt.y - min_y) * scale
    end
  end
  local graphs = {funcs = {}, name_x = "Position", name_z = "Velocity", name_y = "Cost-To-Go"}
  graphs.funcs[name] = func_data
  
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  local pos = {x = POSITION_MAX + POSITION_SIZE / 2, y = 3 * Y_SCALE, z = VELOCITY_MIN - VELOCITY_SIZE}
  local lookat = {x = (POSITION_MIN + POSITION_MAX) / 2, y = Y_SCALE / 2, z = (VELOCITY_MIN + VELOCITY_MAX) / 2}
  local dir = {x = pos.x - lookat.x, y = pos.y - lookat.y, z = pos.z - lookat.z}
  local full_spin = 7200
  local new_dir = RotateAxis(dir, {x = 0, y = 1, z = 0}, -2 * math.pi * (step % full_spin) / full_spin)
  local new_pos = {x = lookat.x + new_dir.x, y = lookat.y + new_dir.y, z = lookat.z + new_dir.z}
  DrawSurface(bmp, graphs, {camera_pos = new_pos, camera_lookat = lookat, ortographic_factor = 1.5 * POSITION_SIZE, text_scale = 2, min_y = min_y, max_y = max_y})
  bmp:WriteBMP(filename)
end

function TileCoding:CostToGo(x, y)
  local actions = self.actions
  local max_value
  for _, a in ipairs(actions) do
    local value = self:GetValue(x, y, a)
    max_value = (not max_value or value > max_value) and value or max_value
  end
  
  return -max_value
end

local function GetStartState()
  return POSITION_START_MIN + math.random() * (POSITION_START_MAX - POSITION_START_MIN), 0.0
end

local function TakeEpsilonGreedyAction(pos, speed, epsilon, VF)
  if math.random() < epsilon then
    return ACTIONS[math.random(1, #ACTIONS)]
  end
  
  local max_actions, max_action_value
  for _, action in ipairs(ACTIONS) do
    local action_value = VF:GetValue(pos, speed, action)
    if (not max_actions) or (action_value > max_action_value) then
      max_actions, max_action_value = {action}, action_value
    elseif math.abs(action_value - max_action_value) < ACTION_VALUE_EPSILON then
      table.insert(max_actions, action)
    end
  end
  
  return (#max_actions == 1) and max_actions[1] or max_actions[math.random(1, #max_actions)]
end

local function DrawCar(pos, speed, action, filename)
  local car_width, car_height = 50, 20
  
  local function get_pt(s)
    return {x = s, y = math.sin(3 * s)}
  end
  
  local func = {color = RGB_GREEN}
  local points = 1000
  local len = {}
  for p = 1, points do
    local s = (p - 1) /  (points - 1)
    func[p] = get_pt(POSITION_MIN + s * POSITION_SIZE)
    len[p] = (p == 1) and 0.0 or math.sqrt(math.pow(func[p].x - last_pt.x, 2) + math.pow(func[p].y - last_pt.y, 2))
    last_pt = func[p]
  end
  
  local throtle = {[THROTLE_FORWARD] = "Full Forward", [THROTLE_REVERSE] = "Full Reverse", [THROTLE_ZERO] = "None"}
  local graphs = {funcs = {["Mountain"] = func}, name_x = string.format("Position: %.2f, Speed: %.2f", pos, speed), name_y = string.format("Throttle: %s", throtle[action])}
  print(string.format("Writing '%s' ...", filename))
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  local transform = DrawGraphs(bmp, graphs, {scale_uniformly = true})
  
  local pt = transform(get_pt(pos))
  local pt1, pt2 = transform(get_pt(pos - 0.01)), transform(get_pt(pos + 0.01))
  local norm_x, norm_y = SetLen(pt2.x - pt1.x, pt2.y - pt1.y, car_height + 3 * car_height // 20)
  norm_x, norm_y = RotatePoint(norm_x, norm_y, -math.pi / 2, "int")
  local angle = CalcSignedAngleBetween(0, car_height, norm_x, norm_y)

  local car_pt = {x = pt.x + norm_x, y = pt.y + norm_y}
  local dir_x, dir_y = RotatePoint(-car_width * math.sqrt(2) / 2, -car_height * math.sqrt(2) / 2, angle, "int")
  local vert_angle1 = 2 * math.atan2(car_width / car_height)
  local vert_angle2 = math.pi - vert_angle1
  local vert_angles = {vert_angle1, vert_angle2, vert_angle1, vert_angle2}
  local base = car_height // 2
  local vertices =
  {
    {x = -car_width // 2, y = base}, {x = car_width // 2, y = base},
    {x = car_width // 2, y = -car_height // 15}, {x = car_width // 2 - car_width // 4, y = -car_height // 15},
    {x = car_width // 2 - car_width // 3, y = -car_height // 2}, {x = -car_width // 2 + car_width // 3, y = -car_height // 2},
    { x= -car_width // 2 + car_width // 4, y = -car_height // 15}, {x = -car_width // 2, y = -car_height // 15},
  }
  for _, vert in ipairs(vertices) do
    vert.x, vert.y = RotatePoint(vert.x, vert.y, angle, "int")
  end
  local wheels = {{x = -car_width // 4, y = base + 1 * car_height // 20}, {x = car_width // 4, y = base + 1 * car_height // 20}}
  for _, wheel in ipairs(wheels) do
    wheel.x, wheel.y = RotatePoint(wheel.x, wheel.y, angle, "int")
  end

  local last_pt = vertices[#vertices]
  for _, vert in ipairs(vertices) do
    bmp:DrawLine(car_pt.x + last_pt.x, car_pt.y + last_pt.y, car_pt.x + vert.x, car_pt.y + vert.y, RGB_CYAN)
    last_pt = vert
  end
  for _, wheel in ipairs(wheels) do
    bmp:DrawCircle(car_pt.x + wheel.x, car_pt.y + wheel.y, 3 * car_height // 10, RGB_CYAN)
  end
  bmp:WriteBMP(filename)
end

local function SemiGradientSarsa(alpha, gamma, epsilon, max_episodes, descr)
  alpha = alpha / TILINGS
  max_episodes = max_episodes or MAX_EPISODES
  descr = descr or {}
  local moments = descr.moments or {}
  local car_episodes = {}
  if descr.car_episodes then
    for _, episode in ipairs(descr.car_episodes) do
      car_episodes[episode] = true
    end
  end
  
  local VF = TileCoding:new{tilings = TILINGS, min_x = POSITION_MIN, max_x = POSITION_MAX, min_y = VELOCITY_MIN, max_y = VELOCITY_MAX, displace_x = TILE_DISPLACEMENT.x, displace_y = TILE_DISPLACEMENT.y, tile_width = TILE_WIDTH, tile_height = TILE_HEIGHT, actions = ACTIONS}
  
  local total_len = 0
  for episode = 1, max_episodes do
    local pos, speed = GetStartState()
    local action = TakeEpsilonGreedyAction(pos, speed, epsilon, VF)
    local len = 0
    while len < MAX_STEPS do
      local next_pos, next_speed, reward = GetNextState(pos, speed, action)
      local Q_SA = VF:GetValue(pos, speed, action)
      if next_pos >= POSITION_MAX then
        -- terminal state
        local delta = alpha * (reward - Q_SA)
        VF:Update(pos, speed, action, delta)
        break
      end
      local next_action = TakeEpsilonGreedyAction(next_pos, next_speed, epsilon, VF)
      local Q_SA_next = VF:GetValue(next_pos, next_speed, next_action)
      local delta = alpha * (reward + gamma * Q_SA_next - Q_SA)
      VF:Update(pos, speed, action, delta)
      pos, speed, action = next_pos, next_speed, next_action
      len = len + 1
      if (descr.draw_first_episode and episode == 1) or (moments[episode] == len) then
        print(string.format("Episode: 1, Step: %d", len))
        DrawCostToGo(VF, string.format("Episode 1, Step %d", len), string.format(IMAGE_EPISODE1_FILENAME, len), len)
      end
      if car_episodes[episode] then
        DrawCar(pos, speed, action, string.format(IMAGE_CAR, episode, len))
      end
    end
    if len >= MAX_STEPS then
      print(string.format("Episode: %d, Limit of %d steps reached", episode, MAX_STEPS))
    end
    if descr.steps then
      total_len = total_len + len
      descr.steps[episode] = (descr.steps[episode] or 0) + total_len / episode
    end
    if (descr.draw_episodes and (episode == 1 or episode % descr.draw_episodes == 0)) or moments[episode] then
      local index = (not descr.draw_episodes) and episode or (episode // descr.draw_episodes)
      print(string.format("Episode: %d, Len: %d", episode, len))
      DrawCostToGo(VF, string.format("Episode %d", episode), string.format(IMAGE_FILENAME, index), descr.draw_episodes and index or 0)
    end
  end
  
  return value_function
end

local function SemiGradientNStepSarsa(n, alpha, gamma, epsilon, max_episodes, descr)
  alpha = alpha / TILINGS
  max_episodes = max_episodes or MAX_EPISODES
  descr = descr or {}
  local moments = descr.moments or {}
  
  local VF = TileCoding:new{tilings = TILINGS, min_x = POSITION_MIN, max_x = POSITION_MAX, min_y = VELOCITY_MIN, max_y = VELOCITY_MAX, displace_x = TILE_DISPLACEMENT.x, displace_y = TILE_DISPLACEMENT.y, tile_width = TILE_WIDTH, tile_height = TILE_HEIGHT, actions = ACTIONS}
  local store = {}
  for idx = 1, n + 1 do
    store[idx] = {}
  end
  
  local total_len = 0
  for episode = 1, max_episodes do
    local pos, speed = GetStartState()
    local action = TakeEpsilonGreedyAction(pos, speed, epsilon, VF)
    store[1].pos, store[1].speed, store[1].action = pos, speed, action
    local store_idx = 2
    
    local time, time_terminal = 1
    repeat
      local entry
      if not time_terminal then
        local next_pos, next_speed, reward = GetNextState(pos, speed, action)
        entry = store[store_idx]
        entry.pos, entry.speed, entry.reward = next_pos, next_speed, reward
        store_idx = (store_idx < n + 1) and (store_idx + 1) or 1
        if next_pos >= POSITION_MAX then
          time_terminal = time + 1
        else
          entry.action = TakeEpsilonGreedyAction(next_pos, next_speed, epsilon, VF)   -- next_action
        end
      end
      
      local time_update = time - n + 1
      if time_update >= 1 then
        local time_end = time_terminal and Min(time_update + n, time_terminal) or (time_update + n)
        local store_k = (store_idx < n + 1) and (store_idx + 1) or 1
        local G, gamma_pow = 0.0, 1.0
        for i = time_update + 1, time_end do
          G = G + gamma_pow * store[store_k].reward
          gamma_pow = gamma_pow * gamma
          store_k = (store_k < n + 1) and (store_k + 1) or 1
        end
        if not time_terminal then
          local Q_SA_next = VF:GetValue(entry.pos, entry.speed, entry.action)
          G = G + gamma_pow * Q_SA_next
        end
        local entry_update = store[store_idx]
        local Q_SA = VF:GetValue(entry_update.pos, entry_update.speed, entry_update.action)
        local delta = alpha * (G - Q_SA)
        VF:Update(entry_update.pos, entry_update.speed, entry_update.action, delta)
        if not time_terminal then
          pos, speed, action = entry.pos, entry.speed, entry.action
        end
      end
      if (descr.draw_first_episode and episode == 1 and time % 10 == 0) or (moments[episode] == time) then
        print(string.format("Episode: 1, Step: %d", time))
        DrawCostToGo(VF, string.format("Episode 1, Step %d", time), string.format(IMAGE_EPISODE1_FILENAME, time), time)
      end
      time = time + 1
    until time > MAX_STEPS or (time_terminal and time_update >= time_terminal - 1)
    if time >= MAX_STEPS then
      print(string.format("Episode: %d, Limit of %d steps reached", episode, MAX_STEPS))
    end
    if descr.steps then
      total_len = total_len + time
      descr.steps[episode] = (descr.steps[episode] or 0) + total_len / episode
    end
    if (descr.draw_episodes and (episode == 1 or episode % descr.draw_episodes == 0)) or moments[episode] then
      local index = (not descr.draw_episodes) and episode or (episode // descr.draw_episodes)
      print(string.format("Episode: %d, Len: %d", episode, time))
      DrawCostToGo(VF, string.format("Episode %d", episode), string.format(IMAGE_FILENAME, index), descr.draw_episodes and index or 0)
    end
  end
  
  return value_function
end

local function Fig10_1()
  local descr = {draw_episodes = false, draw_first_episode = false, moments = MOMENTS_EPISODE_STEPS, --[[car_episodes = {1, MAX_EPISODES}--]]}
  SemiGradientSarsa(ALPHA, GAMMA, EPSILON, MAX_EPISODES, descr)
end

local function Fig10_2()
  local colors = { RGB_CYAN, RGB_GREEN, RGB_RED }
  local graphs = {funcs = {}, name_x = "Episode", name_y = string.format("Steps per Episode averaged over %d runs on a log10 scale", RUNS)}
  for idx, alpha in ipairs(ALPHAS) do
    local descr = {steps = {}}
    for run = 1, RUNS do
      if RUNS < 10 or run % (RUNS // 10) == 0 then
        print(string.format("Run: #%d/%d for Alpha=%.2f", run, RUNS, alpha))
      end
      local value_function = SemiGradientSarsa(alpha, GAMMA, ALPHAS_EPSILON, RUN_EPISODES, descr)
    end
    local func_data = {color = colors[idx]}
    for k, len in ipairs(descr.steps) do
      func_data[k] = {x = k, y = len / RUNS}
    end
    graphs.funcs[string.format("Alpha=%.2f/%d", alpha, TILINGS)] = func_data
  end
  print(string.format("Writing '%s' ...", IMAGE_COMPARE_FILENAME))
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {skip_KP = true, int_x = true, center_x = 0, center_y = 100, y_scaling = math.log10})
  bmp:WriteBMP(IMAGE_COMPARE_FILENAME)
end

local function Fig10_3()
  local colors = { RGB_RED, RGB_GREEN }
  local graphs = {funcs = {}, name_x = "Episode", name_y = string.format("Steps per Episode averaged over %d runs on a log10 scale", RUNS)}
  local idx = 1
  for n, alpha in pairs(ALPHAS_NSTEP_SARSA) do
    local descr = {steps = {}}
    for run = 1, RUNS do
      if RUNS < 10 or run % (RUNS // 10) == 0 then
        print(string.format("Run: #%d/%d for Alpha=%.2f", run, RUNS, alpha))
      end
      local value_function = SemiGradientNStepSarsa(n, alpha, GAMMA, ALPHAS_EPSILON, RUN_EPISODES, descr)
    end
    local func_data = {color = colors[idx]}
    for k, len in ipairs(descr.steps) do
      func_data[k] = {x = k, y = len / RUNS}
    end
    graphs.funcs[string.format("n=%d,Alpha=%.2f/%d", n, alpha, TILINGS)] = func_data
    idx = idx + 1
  end
  print(string.format("Writing '%s' ...", IMAGE_COMPARE_NSTEP_FILENAME))
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {skip_KP = true, int_x = true, center_x = 0, center_y = 100, y_scaling = math.log10})
  bmp:WriteBMP(IMAGE_COMPARE_NSTEP_FILENAME)
end

local function Fig10_4()
  local colors = { RGB_RED, RGB_GREEN, RGB_CYAN, RGB_YELLOW, RGB_MAGENTA }
  local graphs = {funcs = {}, name_x = string.format("Alpha x Number of Tilings(%d)", TILINGS), name_y = string.format("Steps per Episode averaged over first %d episodes and %d runs", ALPHA_N_EPISODES, ALPHA_N_RUNS)}
  for idx, entry in ipairs(ALPHA_VS_N) do
    local func_data = {color = colors[idx], sort_idx = entry.n}
    for _, alpha_total in ipairs(entry.alphas) do
      local alpha = alpha_total / TILINGS
      local descr = {steps = {}}
      for run = 1, ALPHA_N_RUNS do
        if ALPHA_N_RUNS < 10 or run % (ALPHA_N_RUNS // 10) == 0 then
          print(string.format("Run: #%d/%d for Alpha=%.4f,n=%d", run, ALPHA_N_RUNS, alpha, entry.n))
        end
        SemiGradientNStepSarsa(entry.n, alpha, GAMMA, ALPHAS_EPSILON, ALPHA_N_EPISODES, descr)
      end
      table.insert(func_data, {x = alpha_total, y = descr.steps[ALPHA_N_EPISODES] / ALPHA_N_RUNS})
    end
    graphs.funcs[string.format("n=%d", entry.n)] = func_data
  end
  print(string.format("Writing '%s' ...", IMAGE_ALPHA_VS_N_FILENAME))
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {skip_KP = true, center_x = 0, center_y = 200, sort_cmp = function(a, b) return a.sort_idx < b.sort_idx end, y_scaling = math.log10})
  bmp:WriteBMP(IMAGE_ALPHA_VS_N_FILENAME)
end

--DrawCar(POSITION_MIN, 0.0, THROTLE_FORWARD, string.format(IMAGE_CAR, 0, 0))
--DrawCar(-0.52, 0.0, THROTLE_FORWARD, string.format(IMAGE_CAR, 2, 0))
--DrawCar(0.0, 0.0, THROTLE_FORWARD, string.format(IMAGE_CAR, 3, 0))
--DrawCar(POSITION_MAX, 0.0, THROTLE_FORWARD, string.format(IMAGE_CAR, 4, 0))
Fig10_1()
--Fig10_2()
--Fig10_3()
--Fig10_4()