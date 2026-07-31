local M = {}
local api = require("ministore.api")

local all_plugins = {} -- 保存完整插件列表
local filtered_plugins = {} -- 当前过滤后的插件列表


local ui = { list_buf = nil, list_win = nil, header_buf = nil, header_win = nil, input_buf = nil, input_win = nil }
local installed_plugins = {}

local sort_mode = 0
local sort_asc = false

-- 等宽 ASCII 状态标识符
local STATE_INSTALLED = "[ ● ]" -- 6字符
local STATE_MISSING   = "[ ○ ]" -- 6字符

local function to_str(val)
  if type(val) == "string" then return val end
  if type(val) == "number" then return tostring(val) end
  return ""
end

local function truncate(str, len)
  local s = to_str(str)
  if #s <= len then return s end
  return s:sub(1, len - 3) .. "..."
end

local function format_row(is_installed, stars, name, desc)
  local state_str = is_installed and STATE_INSTALLED or STATE_MISSING
  local name_str = truncate(to_str(name), 25)
  local desc_str = truncate(to_str(desc), 50)
  return string.format(" %-8s | %-10d | %-25s | %s", state_str, stars, name_str, desc_str)
end

local function render_header()
  if not ui.header_buf or not vim.api.nvim_buf_is_valid(ui.header_buf) then return end
  local arrow = sort_asc and " ↑" or " ↓"
  local h_state = (sort_mode == 0) and ("State" .. arrow) or "State"
  local h_stars = (sort_mode == 1) and ("Stars" .. arrow) or "Stars"
  local h_name  = (sort_mode == 2) and ("Name"  .. arrow) or "Name"
  local header = string.format(" %-8s | %-10s | %-25s | %s", h_state, h_stars, h_name, "Description")
  vim.api.nvim_buf_set_option(ui.header_buf, "modifiable", true)
  -- 增加一行空行，让表头底部更宽敞
  vim.api.nvim_buf_set_lines(ui.header_buf, 0, -1, false, { header, string.rep("-", 100), " " })
  vim.api.nvim_buf_set_option(ui.header_buf, "modifiable", false)
  vim.api.nvim_buf_add_highlight(ui.header_buf, -1, "Title", 0, 0, -1)
end

-- 渲染列表（核心修正：解决 Neovim 浮窗单行结果渲染失效/光标消失问题）
local function render_content()
  if not ui.list_buf or not vim.api.nvim_buf_is_valid(ui.list_buf) then
    vim.notify("MiniStore Error: List buffer invalid", vim.log.levels.ERROR)
    return
  end

  local lines = {}
  for _, p in ipairs(filtered_plugins) do
    table.insert(lines, format_row(
      installed_plugins[p.name] ~= nil,
      tonumber(p.stars) or 0,
      p.name or "???",
      p.desc or ""
    ))
  end

  local original_count = #lines
  if original_count == 0 then
    table.insert(lines, "No plugins match your query.")
    original_count = 1
  end

  -- 诊断信息：精简输出
  vim.notify(string.format("🎨 [Render] Original: %d | Final: %d", original_count, #lines), vim.log.levels.INFO)
  
  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", true)
  local ok, err = pcall(vim.api.nvim_buf_set_lines, ui.list_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", false)

  if not ok then
    vim.notify("MiniStore Error: buf_set_lines failed: " .. tostring(err), vim.log.levels.ERROR)
  end

  if ui.list_win and vim.api.nvim_win_is_valid(ui.list_win) then
    pcall(vim.api.nvim_win_set_buf, ui.list_win, ui.list_buf)
    pcall(vim.api.nvim_win_set_cursor, ui.list_win, {1, 0})

    if original_count > 0 then
      vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, 0, -1)
      vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", 0, 0, -1)
    end

    vim.schedule(function() pcall(vim.cmd, "redrawall") end)
  end
end

-- 比较函数：实现严格弱序排序 (Strict Weak Ordering)
-- 采用 "基础升序 + 方向翻转" 策略，彻底杜绝 E5108 错误
function M.compare_plugins(a, b, mode, asc, installed)
  if type(a) ~= "table" or type(b) ~= "table" then return false end

  -- 内部函数：定义一个绝对稳定的【基础升序】关系 (is_less)
  local function is_less(x, y)
    local x_name = to_str(x.name):lower()
    local y_name = to_str(y.name):lower()
    local x_stars = tonumber(x.stars) or 0
    local y_stars = tonumber(y.stars) or 0
    local x_inst = (installed and installed[x.name] ~= nil) and 1 or 0
    local y_inst = (installed and installed[y.name] ~= nil) and 1 or 0

    if mode == 0 then -- State
      if x_inst ~= y_inst then return x_inst < y_inst end
      if x_name ~= y_name then return x_name < y_name end
    elseif mode == 1 then -- Stars
      if x_stars ~= y_stars then return x_stars < y_stars end
      if x_name ~= y_name then return x_name < y_name end
    else -- Name
      if x_name ~= y_name then return x_name < y_name end
      if x_stars ~= y_stars then return x_stars < y_stars end
    end
    -- 最终兜底：唯一 ID
    return (x._id or 0) < (y._id or 0)
  end

  -- 根据 asc 参数决定返回方向
  if asc then
    return is_less(a, b)
  else
    -- 降序逻辑：只有当 b < a 时，a 才被认为 "小于" b
    -- 如果 is_less(a, b) 为 true，则 a 确实小于 b -> 返回 false
    -- 如果 is_less(b, a) 为 true，则 b 小于 a -> 返回 true (即 a 较大，排在前面)
    -- 如果两者都 false (相等)，则返回 false
    if is_less(a, b) then return false end
    if is_less(b, a) then return true end
    return false
  end
end

-- 纯函数：根据查询字符串过滤插件列表（可独立测试）
function M.filter_plugins(query, plugins)
  if type(plugins) ~= "table" then plugins = {} end
  local result = {}

  if type(query) ~= "string" or query == "" then
    for i, p in ipairs(plugins) do result[i] = p end
    return result
  end

  local tokens = {}
  for token in string.gmatch(query, "%S+") do
    token = token:lower()
    if token ~= "" then
      table.insert(tokens, token)
    end
  end

  if #tokens == 0 then
    for i, p in ipairs(plugins) do result[i] = p end
    return result
  end

  for _, p in ipairs(plugins) do
    if type(p) == "table" then
      local name = to_str(p.name):lower()
      local desc = to_str(p.desc):lower()
      local repo = to_str(p.repo):lower()
      local all_matched = true
      for _, token in ipairs(tokens) do
        if not (name:find(token, 1, true) or desc:find(token, 1, true) or repo:find(token, 1, true)) then
          all_matched = false
          break
        end
      end
      if all_matched then
        table.insert(result, p)
      end
    end
  end

  return result
end

local function filter_plugins()
  if not all_plugins then all_plugins = {} end
  local query = ""
  if type(ui.input_buf) == "number" and vim.api.nvim_buf_is_valid(ui.input_buf) then
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, ui.input_buf, 0, -1, false)
    if ok and lines and #lines > 0 then
      query = vim.trim(table.concat(lines, " "))
    end
  end
  filtered_plugins = M.filter_plugins(query, all_plugins)
  M.actions.sort(0)
end

M.actions = {
  toggle_sort_order = function()
    if sort_asc == nil then sort_asc = false end
    sort_asc = not sort_asc
    M.actions.sort(0)
  end,
  sort = function(delta)
    if type(filtered_plugins) ~= "table" then filtered_plugins = {} end
    if delta ~= 0 then
      local new_mode = sort_mode + delta
      sort_mode = math.max(0, math.min(2, new_mode))
    end
    if not filtered_plugins or #filtered_plugins == 0 then
        render_header()
        render_content()
        return
    end

    local sort_ok, sort_err = pcall(function()
      table.sort(filtered_plugins, function(a, b)
        return M.compare_plugins(a, b, sort_mode, sort_asc, installed_plugins)
      end)
    end)

    if not sort_ok then
      vim.notify("MiniStore: Sort Error - " .. tostring(sort_err), vim.log.levels.ERROR)
    end

    render_header()
    render_content()
  end,
  move_cursor = function(delta)
    local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
    local line_count = vim.api.nvim_buf_line_count(ui.list_buf)
    local new_row = math.max(1, math.min(line_count, cursor[1] + delta))
    vim.api.nvim_win_set_cursor(ui.list_win, { new_row, 0 })
    vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, 0, -1)
    vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", new_row - 1, 0, -1)
  end,
  install_selected = function()
    local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
    local index = cursor[1]
    local p = filtered_plugins[index]
    if not p then return end
    if installed_plugins[p.name] then
      vim.notify("MiniStore: 插件 " .. p.name .. " 已经安装", "info")
      return
    end
    local success = api.install_plugin(p.repo, p.name)
    if success then
      installed_plugins = api.get_installed_plugins()
      render_content()
      vim.notify("MiniStore: 插件 " .. p.name .. " 安装成功！", "info")
    else
      vim.notify("MiniStore: 安装插件 " .. p.name .. " 失败", "error")
    end
  end,
  remove_selected = function()
    local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
    local index = cursor[1]
    local p = filtered_plugins[index]
    if not p then return end
    if not installed_plugins[p.name] then
      vim.notify("MiniStore: 插件 " .. p.name .. " 尚未安装", "info")
      return
    end
    local success = api.remove_plugin(p.name)
    if success then
      installed_plugins = api.get_installed_plugins()
      render_content()
      vim.notify("MiniStore: 移除插件 " .. p.name .. " 已从配置中移除", "info")
    else
      vim.notify("MiniStore: 移除插件 " .. p.name .. " 失败", "error")
    end
  end
}

function M.open()
  local prev_mode = vim.api.nvim_get_mode().mode
  api.fetch_plugins(function(plugins)
    installed_plugins = api.get_installed_plugins()
    all_plugins = type(plugins) == "table" and plugins or {}
    
    -- 给每个插件分配一个唯一ID，用于保证排序的绝对稳定性 (Strict Weak Ordering)
    for i, p in ipairs(all_plugins) do
      if type(p) == "table" then
        p._id = i
      end
    end

    filtered_plugins = {}
    for i, p in ipairs(all_plugins) do filtered_plugins[i] = p end

    local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.7)
    local r, c = math.floor((vim.o.lines - h) / 2), math.floor((vim.o.columns - w) / 2)

    ui.header_buf = vim.api.nvim_create_buf(false, true)
    ui.header_win = vim.api.nvim_open_win(ui.header_buf, false, { relative="editor", width=w, height=3, row=r+2, col=c, style="minimal", border={ "╭", "─", "╮", "│", " ", " ", "│", "│" } })
    ui.list_buf = vim.api.nvim_create_buf(false, true)
    ui.list_win = vim.api.nvim_open_win(ui.list_buf, false, { relative="editor", width=w, height=h-6, row=r+6, col=c, style="minimal", border={ "│", " ", " ", "│", "╰", "─", "╯", "│" } })
    ui.input_buf = vim.api.nvim_create_buf(false, true)
    ui.input_win = vim.api.nvim_open_win(ui.input_buf, true, { relative="editor", width=w, height=1, row=r, col=c, style="minimal", border="rounded", title=" 🔍 搜索 ", title_pos="center" })

    render_header()
    render_content()

    vim.cmd("startinsert")

    vim.api.nvim_buf_attach(ui.input_buf, false, {
      on_lines = function()
        vim.schedule(filter_plugins)
      end
    })

    local setup_keymaps = function(buf)
        local opts = { buffer = buf, silent = true }

        local sort_mode_map = { ["<C-1>"] = 0, ["<M-1>"] = 0, ["<C-2>"] = 1, ["<M-2>"] = 1, ["<C-3>"] = 2, ["<M-3>"] = 2 }
        for key, mode in pairs(sort_mode_map) do
            vim.keymap.set({ "i", "n" }, key, function()
                if sort_mode == mode then M.actions.toggle_sort_order() else sort_mode = mode; M.actions.sort(0) end
            end, opts)
        end

        vim.keymap.set({ "i", "n" }, "<Up>", function() M.actions.move_cursor(-1) end, opts)
        vim.keymap.set({ "i", "n" }, "<Down>", function() M.actions.move_cursor(1) end, opts)

        vim.keymap.set({ "i", "n" }, "<C-r>", function()
          print("MiniStore: 刷新完成！")
          all_plugins = api.refresh_cache() or all_plugins
          filter_plugins()
        end, opts)

        vim.keymap.set({ "i", "n" }, "<CR>", function() M.actions.install_selected() end, opts)
        vim.keymap.set({ "i", "n" }, "<Del>", function() M.actions.remove_selected() end, opts)
        vim.keymap.set({ "i", "n" }, "x", function() M.actions.remove_selected() end, opts)

        vim.keymap.set({ "i", "n" }, "<Esc>", function()
          pcall(vim.api.nvim_win_close, ui.input_win, true)
          pcall(vim.api.nvim_win_close, ui.header_win, true)
          pcall(vim.api.nvim_win_close, ui.list_win, true)
          if prev_mode ~= 'i' and prev_mode ~= 'ic' then
             vim.cmd("stopinsert")
          end
        end, opts)
    end

    setup_keymaps(ui.input_buf)
    setup_keymaps(ui.list_buf)
  end)
end

return M
