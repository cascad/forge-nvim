local function alpha()
  local function nested()
    return 42
  end
  return nested()
end

local function omega()
  return 'last symbol'
end

return { alpha = alpha, omega = omega }
