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

local function truncate(str, len)
  if #str <= len then return str end
  return str:sub(1, len - 3) .. "..."
end

local function format_row(is_installed, stars, name, desc)
  local state_str = is_installed and STATE_INSTALLED or STATE_MISSING
  local name_str = truncate(tostring(name or "???"), 25)
  local desc_str = truncate(tostring(desc or ""), 50)
  return string.format(" %-8s | %-10d | %-25s | %s", state_str, stars, name_str, desc_str)
end

local function render_header()
  if not ui.header_buf or not vim.api.nvim_buf_is_valid(ui.header_buf) then return end
  local arrow = sort_asc and " ↑" or " ↓"
  local h_stars = (sort_mode == 0) and ("Stars" .. arrow) or "Stars"
  local h_name = (sort_mode == 1) and ("Name" .. arrow) or "Name"
  local header = string.format(" %-8s | %-10s | %-25s | %s", "State", h_stars, h_name, "Description")
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

local function filter_plugins()
  local query = vim.trim(vim.api.nvim_buf_get_lines(ui.input_buf, 0, 1, false)[1] or "")
  if query == "" then
    filtered_plugins = all_plugins
  else
    filtered_plugins = {}
    for _, p in ipairs(all_plugins) do
      if (p.name or ""):lower():find(query:lower(), 1, true) then
        table.insert(filtered_plugins, p)
      end
    end
  end
  M.actions.sort(0)
end

M.actions = {
  toggle_sort_order = function()
    sort_asc = not sort_asc
    M.actions.sort(0)
  end,
  sort = function(delta)
    if delta ~= 0 then 
      sort_mode = (sort_mode + delta) % 2
      -- ensure non‑negative
      sort_mode = (sort_mode + 2) % 2
      sort_asc = (sort_mode == 1)
    end
    
    if not filtered_plugins or #filtered_plugins == 0 then return end
    
    table.sort(filtered_plugins, function(a, b)
      local a_val, b_val
      if sort_mode == 0 then
        a_val = tonumber(a.stars) or 0
        b_val = tonumber(b.stars) or 0
      else
        a_val = a.name or ""
        b_val = b.name or ""
      end
      if a_val == b_val then return false end
      if sort_asc then
        return a_val < b_val
      else
        return a_val > b_val
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
  api.fetch_plugins(function(plugins)
    installed_plugins = api.get_installed_plugins()
    all_plugins = plugins or {}
    filtered_plugins = all_plugins


    
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
    vim.cmd("startinsert")

    vim.api.nvim_buf_attach(ui.input_buf, false, {
      on_lines = function()
        vim.schedule(filter_plugins)
      end
    })






    local opts = { buffer = ui.input_buf, silent = true }
    vim.keymap.set({ "i", "n" }, "<Right>", function() M.actions.sort(1) end, opts)
    vim.keymap.set({ "i", "n" }, "<Left>", function() M.actions.sort(-1) end, opts)
    vim.keymap.set({ "i", "n" }, "<C-->", M.actions.toggle_sort_order, opts)
    vim.keymap.set({ "i", "n" }, "<Down>", function() M.actions.move_cursor(1) end, opts)
    vim.keymap.set({ "i", "n" }, "<Up>", function() M.actions.move_cursor(-1) end, opts)
    vim.keymap.set({ "i", "n" }, "<Esc>", function()
      pcall(vim.api.nvim_win_close, ui.input_win, true)
      pcall(vim.api.nvim_win_close, ui.header_win, true)
      pcall(vim.api.nvim_win_close, ui.list_win, true)
    end, opts)
  end)
end

return M
