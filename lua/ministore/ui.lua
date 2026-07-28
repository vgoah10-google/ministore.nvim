local M = {}
local api = require("ministore.api")

local all_plugins = {} -- 保存完整插件列表


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
  vim.api.nvim_buf_set_lines(ui.header_buf, 0, -1, false, { header, string.rep("-", 100) })
  vim.api.nvim_buf_set_option(ui.header_buf, "modifiable", false)
  vim.api.nvim_buf_add_highlight(ui.header_buf, -1, "Title", 0, 0, -1)
end

local function render_content()
  if not ui.list_buf or not vim.api.nvim_buf_is_valid(ui.list_buf) then return end
  local lines = {}
  for _, p in ipairs(filtered_plugins) do
    table.insert(lines, format_row(
      installed_plugins[p.name] ~= nil,
      tonumber(p.stars) or 0,
      p.name or "???",
      p.desc or ""
    ))
  end
  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(ui.list_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", false)
end

-- 纯函数：根据查询字符串过滤插件列表（可独立测试）
-- query: 用户输入的查询字符串
-- plugins: 待过滤的插件列表 (table of tables)
-- 返回值: 过滤后的新列表（浅拷贝元素）
function M.filter_plugins(query, plugins)
  if type(plugins) ~= "table" then plugins = {} end
  local result = {}
  
  if type(query) ~= "string" or query == "" then
    for i, p in ipairs(plugins) do result[i] = p end
    return result
  end
  
  -- 多关键词匹配：查询按空格拆分，必须全部命中 (AND逻辑)
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

-- 包装函数：从缓冲区读取查询并过滤，更新全局 filtered_plugins
local function filter_plugins()
  -- 确保 all_plugins 不为空，如果是 nil 则设为空表
  if not all_plugins then all_plugins = {} end
  
  local query = ""
  -- 2. 检查缓冲区
  if type(ui.input_buf) == "number" and vim.api.nvim_buf_is_valid(ui.input_buf) then
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, ui.input_buf, 0, 1, false)
    if ok and lines and #lines > 0 then
      query = vim.trim(lines[1] or "")
    end
  end

  -- 3. 调用纯函数过滤插件
  filtered_plugins = M.filter_plugins(query, all_plugins)

  -- 4. 执行排序
  M.actions.sort(0)
end

-- 如果报错依然存在，请确认下面这一行的行号是否对应 79 行
M.actions = {
  toggle_sort_order = function()
    -- 确保 sort_asc 被初始化且能正确切换
    if sort_asc == nil then sort_asc = false end
    sort_asc = not sort_asc
    M.actions.sort(0)
  end,
  sort = function(delta)
    -- 强制保证 filtered_plugins 是 table，防止被 userdata 污染
    if type(filtered_plugins) ~= "table" then filtered_plugins = {} end
    
    -- 边界防御
    if delta ~= 0 then 
      local new_mode = sort_mode + delta
      sort_mode = math.max(0, math.min(2, new_mode))
    end
    
    -- 核心：确保 filtered_plugins 存在
    if not filtered_plugins or #filtered_plugins == 0 then 
        render_header()
        render_content()
        return 
    end
    
    table.sort(filtered_plugins, function(a, b)
      local a_name = to_str(a and a.name):lower()
      local b_name = to_str(b and b.name):lower()
      local a_stars = tonumber(a and a.stars) or 0
      local b_stars = tonumber(b and b.stars) or 0
      local a_inst = (installed_plugins[a and a.name] ~= nil) and 1 or 0
      local b_inst = (installed_plugins[b and b.name] ~= nil) and 1 or 0

      if sort_mode == 0 then -- State: 0 (uninstalled) vs 1 (installed)
        if a_inst ~= b_inst then
          if not sort_asc then
            return a_inst < b_inst -- 未安装(0) 在前
          else
            return a_inst > b_inst -- 已安装(1) 在前
          end
        end
        if a_name ~= b_name then
          if not sort_asc then
            return a_name < b_name -- A-Z
          else
            return a_name > b_name -- Z-A
          end
        end
        return false

      elseif sort_mode == 1 then -- Stars
        if a_stars ~= b_stars then
          if not sort_asc then
            return a_stars > b_stars -- 星数从高到低
          else
            return a_stars < b_stars -- 星数从低到高
          end
        end
        if a_name ~= b_name then
          return a_name < b_name -- 同星数按字母 A-Z
        end
        return false

      else -- Name (sort_mode == 2)
        if a_name ~= b_name then
          if not sort_asc then
            return a_name < b_name -- 字母 A-Z
          else
            return a_name > b_name -- 字母 Z-A
          end
        end
        if a_stars ~= b_stars then
          return a_stars > b_stars -- 同名按星数高到低
        end
        return false
      end
    end)
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
  end
}

function M.open()
  local prev_mode = vim.api.nvim_get_mode().mode
  api.fetch_plugins(function(plugins)
    installed_plugins = api.get_installed_plugins()
    all_plugins = type(plugins) == "table" and plugins or {}
    -- 浅拷贝，防止直接引用
    filtered_plugins = {}
    for i, p in ipairs(all_plugins) do filtered_plugins[i] = p end
    
    local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.7)
    local r, c = math.floor((vim.o.lines - h) / 2), math.floor((vim.o.columns - w) / 2)

    ui.header_buf = vim.api.nvim_create_buf(false, true)
    ui.header_win = vim.api.nvim_open_win(ui.header_buf, false, { relative="editor", width=w, height=2, row=r+2, col=c, style="minimal", border={ "╭", "─", "╮", "│", " ", " ", "│", "│" } })
    ui.list_buf = vim.api.nvim_create_buf(false, true)
    ui.list_win = vim.api.nvim_open_win(ui.list_buf, false, { relative="editor", width=w, height=h-6, row=r+4, col=c, style="minimal", border={ "│", " ", " ", "│", "╰", "─", "╯", "│" } })
    ui.input_buf = vim.api.nvim_create_buf(false, true)
    ui.input_win = vim.api.nvim_open_win(ui.input_buf, true, { relative="editor", width=w, height=1, row=r, col=c, style="minimal", border="rounded", title=" 🔍 搜索 ", title_pos="center" })

    render_header()
    render_content()
    
    -- 只有当之前是插入模式时才保持插入
    if prev_mode == 'i' or prev_mode == 'ic' then
        vim.cmd("startinsert")
    end

    vim.api.nvim_buf_attach(ui.input_buf, false, {
      on_lines = function()
        vim.schedule(filter_plugins)
      end
    })

    -- 定义一个通用的绑定函数
    local setup_keymaps = function(buf)
        local opts = { buffer = buf, silent = true }
        
        -- 排序切换
        local sort_mode_map = { ["<C-1>"] = 0, ["<M-1>"] = 0, ["<C-2>"] = 1, ["<M-2>"] = 1, ["<C-3>"] = 2, ["<M-3>"] = 2 }
        for key, mode in pairs(sort_mode_map) do
            vim.keymap.set({ "i", "n" }, key, function()
                if sort_mode == mode then M.actions.toggle_sort_order() else sort_mode = mode; M.actions.sort(0) end
            end, opts)
        end
        
        -- 列表导航
        vim.keymap.set({ "i", "n" }, "<Up>", function() M.actions.move_cursor(-1) end, opts)
        vim.keymap.set({ "i", "n" }, "<Down>", function() M.actions.move_cursor(1) end, opts)
        
        -- 其他动作
        vim.keymap.set({ "i", "n" }, "<C-r>", function()
          print("MiniStore: 刷新完成！")
          all_plugins = api.refresh_cache() or all_plugins
          filter_plugins()
        end, opts)
        
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
