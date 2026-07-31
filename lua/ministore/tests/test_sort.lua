local ui = require("ministore.ui")

local function test_sort()
  vim.notify("Running Sorting Stability Tests...", vim.log.levels.INFO)

  local plugins = {
    { name = "A", stars = 100, repo = "repoA", _id = 1 },
    { name = "B", stars = 50,  repo = "repoB", _id = 2 },
    { name = "A", stars = 200, repo = "repoA2", _id = 3 },
    { name = "C", stars = 50,  repo = "repoC", _id = 4 },
    { name = "B", stars = 50,  repo = "repoB2", _id = 5 },
  }

  local installed = { ["A"] = true }

  local cases = {
    { mode = 0, asc = false },
    { mode = 0, asc = true },
    { mode = 1, asc = false },
    { mode = 1, asc = true },
    { mode = 2, asc = false },
    { mode = 2, asc = true },
  }

  for _, case in ipairs(cases) do
    local test_list = {}
    for i, p in ipairs(plugins) do test_list[i] = p end
    
    local ok, err = pcall(function()
      table.sort(test_list, function(a, b)
        return ui.compare_plugins(a, b, case.mode, case.asc, installed)
      end)
    end)

    if not ok then
      vim.notify(string.format("[✗] Crash in mode %d, asc %s: %s", case.mode, tostring(case.asc), err), vim.log.levels.ERROR)
    else
      vim.notify(string.format("[✓] Mode %d, Asc %s: First=%s, Last=%s", case.mode, tostring(case.asc), test_list[1].name, test_list[#test_list].name), vim.log.levels.INFO)
    end
  end

  vim.notify("Running Stress Test (1000 items, all modes)...", vim.log.levels.INFO)
  local stress_list = {}
  for i = 1, 1000 do
    table.insert(stress_list, { name = "P" .. (i % 10), stars = i % 100, _id = i })
  end

  local stress_ok = true
  for m = 0, 2 do
    for i = 1, 20 do
      local asc = (i % 2 == 0)
      local ok, err = pcall(function()
        table.sort(stress_list, function(a, b)
          return ui.compare_plugins(a, b, m, asc, {})
        end)
      end)
      if not ok then
        vim.notify(string.format("[✗] Stress Test failed at mode %d, iteration %d: %s", m, i, err), vim.log.levels.ERROR)
        stress_ok = false
        break
      end
    end
    if not stress_ok then break end
  end
  if stress_ok then vim.notify("[✓] Stress Test Passed for all modes", vim.log.levels.INFO) end
end

return { test_sort = test_sort }
