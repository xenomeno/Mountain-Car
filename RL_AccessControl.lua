dofile("Bitmap.lua")
dofile("Graphics.lua")
dofile("RL_TileCoding.lua")

local SERVERS                         = 10
local PRIORITIES                      = {1, 2, 3, 4}
local REWARDS                         = {}
for priority in ipairs(PRIORITIES) do
  REWARDS[priority] = math.pow(2, priority - 1)
end

local ACTION_ACCEPT                   = 1
local ACTION_REJECT                   = 2
local ACTIONS                         = {ACTION_ACCEPT, ACTION_REJECT}
local PROBABILITY_FREE                = 0.06

local ALPHA                           = 0.01
local BETA                            = 0.01
local EPSILON                         = 0.1
local MAX_STEPS                       = 3000000
local ACTION_VALUE_EPSILON            = 0.0001

local TILINGS                         = 8
local TILE_DIVISION                   = 8
local TILE_WIDTH                      = (SERVERS - 0) / TILE_DIVISION
local TILE_HEIGHT                     = (#PRIORITIES - 0) / TILE_DIVISION
local TILE_DISPLACEMENT               = {x = 3, y = 1}

local IMAGE_WIDTH                     = 1000
local IMAGE_HEIGHT                    = 1000
local IMAGE_FILENAME_POLICY           = "AccessControl/Fig10_5_AccessControl_Policy.bmp"
local IMAGE_FILENAME_VF               = "AccessControl/Fig10_5_AccessControl_VF.bmp"

local function Clamp(x, a, b)
  return (x < a) and a or ((x > b) and b or x)
end

local function Max(a, b)
  return (a > b) and a or b
end

local function GetNextPriority()
  return PRIORITIES[math.random(1, #PRIORITIES)]
end

local function TakeEpsilonGreedyAction(free_servers, priority, epsilon, VF)
  if free_servers == 0 then
    return ACTION_REJECT
  end
  
  if math.random() < epsilon then
    return ACTIONS[math.random(1, #ACTIONS)]
  end
  
  local max_actions, max_action_value
  for _, action in ipairs(ACTIONS) do
    local action_value = VF:GetValue(free_servers, priority, action)
    if (not max_actions) or (action_value > max_action_value) then
      max_actions, max_action_value = {action}, action_value
    elseif math.abs(action_value - max_action_value) < ACTION_VALUE_EPSILON then
      table.insert(max_actions, action)
    end
  end
  
  return (#max_actions == 1) and max_actions[1] or max_actions[math.random(1, #max_actions)]
end

local function ExecuteAction(free_servers, priority, action)
  for server = free_servers + 1, SERVERS do
    if math.random() < PROBABILITY_FREE then
      free_servers = free_servers + 1
    end
  end
  if action == ACTION_ACCEPT then
    return free_servers - 1, REWARDS[priority]
  else
    return free_servers, 0
  end
end

local function DifferentialSemiGradientSarsa(alpha, beta, epsilon, max_steps)
  alpha = alpha / TILINGS
  
  local VF = TileCoding:new{tilings = TILINGS, min_x = 0, max_x = SERVERS, min_y = 0, max_y = #PRIORITIES, displace_x = TILE_DISPLACEMENT.x, displace_y = TILE_DISPLACEMENT.y, tile_width = TILE_WIDTH, tile_height = TILE_HEIGHT, actions = ACTIONS}
  local avg_reward = 0.0
  
  local free_servers = SERVERS
  local priority = GetNextPriority()
  local action = TakeEpsilonGreedyAction(free_servers, priority, epsilon, VF)
  local step = 1
  while step <= max_steps do
    local new_free_servers, reward = ExecuteAction(free_servers, priority, action)
    local new_priority = GetNextPriority()
    local new_action = TakeEpsilonGreedyAction(new_free_servers, new_priority, epsilon, VF)
    local new_Q_SA = VF:GetValue(new_free_servers, new_priority, new_action)
    local Q_SA = VF:GetValue(free_servers, priority, action)
    local delta = reward - avg_reward + new_Q_SA - Q_SA
    avg_reward = avg_reward + beta * delta
    VF:Update(free_servers, priority, action, alpha * delta)
    free_servers, priority, action = new_free_servers, new_priority, new_action
    step = step + 1
  end
  
  return VF, avg_reward
end

local function DifferentialSemiGradientNStepSarsa(n, alpha, beta, epsilon, max_steps)
  alpha = alpha / TILINGS
  
  local VF = TileCoding:new{tilings = TILINGS, min_x = 0, max_x = SERVERS, min_y = 0, max_y = #PRIORITIES, displace_x = TILE_DISPLACEMENT.x, displace_y = TILE_DISPLACEMENT.y, tile_width = TILE_WIDTH, tile_height = TILE_HEIGHT, actions = ACTIONS}
  local avg_reward = 0.0
  local store = {}
  for i = 1, n + 1 do
    store[i] = {}
  end
  
  local free_servers = SERVERS
  local priority = GetNextPriority()
  local action = TakeEpsilonGreedyAction(free_servers, priority, epsilon, VF)
  store[1].free_servers, store[1].priority, store[1].action = free_servers, priority, action
  local store_idx = 2
  local step = 1
  while step <= max_steps do
    local new_free_servers, reward = ExecuteAction(free_servers, priority, action)
    local new_priority = GetNextPriority()
    local new_action = TakeEpsilonGreedyAction(new_free_servers, new_priority, epsilon, VF)
    entry = store[store_idx]
    entry.free_servers, entry.priority, entry.action, entry.reward = new_free_servers, new_priority, new_action, reward
    store_idx = (store_idx < n + 1) and (store_idx + 1) or 1
    local time_update = step - n + 1
    if time_update >= 1 then
      local new_Q_SA = VF:GetValue(new_free_servers, new_priority, new_action)
      local entry_update = store[store_idx]
      local Q_SA = VF:GetValue(entry_update.free_servers, entry_update.priority, entry_update.action)
      local delta = new_Q_SA - Q_SA
      for k = 1, n + 1 do
        if k ~= store_idx then
          delta = delta + store[k].reward - avg_reward
        end
      end
      avg_reward = avg_reward + beta * delta
      VF:Update(entry_update.free_servers, entry_update.priority, entry_update.action, alpha * delta)
    end
    free_servers, priority, action = new_free_servers, new_priority, new_action
    step = step + 1
  end
  
  return VF, avg_reward
end

local function Fig10_5()
  local VF, avg_reward = DifferentialSemiGradientSarsa(ALPHA, BETA, EPSILON, MAX_STEPS)
  print(string.format("Learned value for average R: %.2f", avg_reward))
  
  local func_policy = {color = RGB_GREEN, {x = 0, y = 0}}
  local colors = {RGB_RED, RGB_GREEN, RGB_CYAN, RGB_WHITE}
  local funcs_priorty = {}
  for free_servers = 1, SERVERS do
    local min_accept_priority, best_action_value
    for _, priority in ipairs(PRIORITIES) do
      local name = string.format("Priority %d", REWARDS[priority])
      funcs_priorty[name] = funcs_priorty[name] or {color = colors[priority]}
      local value_accept = VF:GetValue(free_servers, priority, ACTION_ACCEPT)
      local value_reject = VF:GetValue(free_servers, priority, ACTION_REJECT)
      if value_accept > value_reject then
        if not min_accept_priority or priority < min_accept_priority then
          min_accept_priority = priority
        end
      end
      funcs_priorty[name][free_servers] = {x = free_servers, y = Max(value_accept, value_reject)}
    end
    -- NOTE: we substract 1 since we want to show that this whole row Y is policy accept
    table.insert(func_policy, {x = free_servers - 1, y = min_accept_priority - 1})
    table.insert(func_policy, {x = free_servers, y = min_accept_priority - 1})
  end
  
  local graphs = {funcs = {["Policy"] = func_policy}, name_x = "Number of free servers", name_y = "Priority"}
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {div_y = 4, skip_KP = true, int_x = true, int_y = true, text_x_inside_interval = true, text_y_inside_interval = true, y_line = 4})
  bmp:WriteBMP(IMAGE_FILENAME_POLICY)

  local graphs = {funcs = funcs_priorty, name_x = "Number of free servers", name_y = string.format("Differential value of best action, Value learned for average R: %.2f", avg_reward)}
  local bmp = Bitmap.new(IMAGE_WIDTH, IMAGE_HEIGHT, RGB_BLACK)
  DrawGraphs(bmp, graphs, {skip_KP = true, int_x = true, y_line = 0.0})
  bmp:WriteBMP(IMAGE_FILENAME_VF)
end

Fig10_5()
