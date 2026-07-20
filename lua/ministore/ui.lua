local M = {}
local api = require("ministore.api")

local filtered_plugins = {}
local ui = { list_buf = nil, list_win = nil, input_buf = nil, input_win = nil }
local installed_plugins = {}
local selected_plugin = nil -- 用于存储当前选中的插件
local marked_for_removal = nil -- 新增：用于存储标记为删除的插件

-- 1. 渲染列表文本
local function render_list()
  if not ui.list_buf or not vim.api.nvim_buf_is_valid(ui.list_buf) then
    return
  end

  local lines = {}
  for _, p in ipairs(filtered_plugins) do
    local installed_tag = ""
    local name_display = p.name
    local line_prefix = " 📦 "
    
    -- 检查是否已安装
    if installed_plugins[p.name] then
      installed_tag = " [installed]"
      name_display = p.name .. installed_tag
      line_prefix = " ✅ "
    end
    
    local line = string.format("%s%-28s ⭐ %-5d | %s", line_prefix, name_display, p.stars, p.desc)
    table.insert(lines, line)
  end

  if #lines == 0 then
    table.insert(lines, "  ❌ 没有找到匹配的插件...")
  end

  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(ui.list_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(ui.list_buf, "modifiable", false)
  
  -- 清除之前的高亮
  vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, 0, -1)
  
  -- 高亮已安装的插件行
  for i, p in ipairs(filtered_plugins) do
    if installed_plugins[p.name] then
      vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", i - 1, 0, -1)
    end
  end
  
  -- 高亮第一行（默认选中）
  if #lines > 0 then
    vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", 0, 0, -1)
  end
end

-- 2. 实时过滤核心算法
local function filter_store(keyword)
  if keyword == "" then
    filtered_plugins = vim.deepcopy(api.cached_plugins)
  else
    filtered_plugins = {}
    local pattern = keyword:lower()
    for _, p in ipairs(api.cached_plugins) do
      if
        p.name:lower():find(pattern, 1, true)
        or p.repo:lower():find(pattern, 1, true)
        or (p.desc and p.desc:lower():find(pattern, 1, true))
      then
        table.insert(filtered_plugins, p)
      end
    end
  end
  render_list()
end

-- 3. 打开应用商店高级 UI 界面
function M.open()
  vim.notify("📡 正在准备拉取在线商店数据...", vim.log.levels.INFO)

  api.fetch_plugins(function(plugins)
    -- 获取已安装插件列表
    installed_plugins = api.get_installed_plugins()
    filtered_plugins = vim.deepcopy(plugins)

    -- 动态计算屏幕中央的浮动窗口尺寸
    local screen_w, screen_h = vim.o.columns, vim.o.lines
    local width = math.floor(screen_w * 0.8)
    local height = math.floor(screen_h * 0.7)
    local row = math.floor((screen_h - height) / 2)
    local col = math.floor((screen_w - width) / 2)

    -- A. 创建下方列表展示窗口
    ui.list_buf = vim.api.nvim_create_buf(false, true)
    ui.list_win = vim.api.nvim_open_win(ui.list_buf, false, {
      relative = "editor",
      width = width,
      height = height - 4,
      row = row + 4,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " 🏪 插件列表 (Ctrl-j/k 上下移动, 回车一键配置) ",
      title_pos = "center",
    })

    -- B. 创建上方输入搜索窗口
    ui.input_buf = vim.api.nvim_create_buf(false, true)
    ui.input_win = vim.api.nvim_open_win(ui.input_buf, true, {
      relative = "editor",
      width = width,
      height = 1,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " 🔍 输入关键字实时秒级检索全球插件 ",
      title_pos = "center",
    })

    render_list()
    vim.cmd("startinsert")

    -- C. 监听输入缓冲区实现动态过滤
    vim.api.nvim_buf_attach(ui.input_buf, false, {
      on_lines = function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ui.input_buf) then
            local lines = vim.api.nvim_buf_get_lines(ui.input_buf, 0, 1, false)
            local text = lines[1] or ""
            filter_store(text)
          end
        end)
      end,
    })

    -- D. 绑定交互快捷键
    local opts = { buffer = ui.input_buf, silent = true }

    -- 强制刷新
    vim.keymap.set({ "i", "n" }, "<C-r>", function()
      vim.notify("MiniStore: 正在强制刷新数据库...", vim.log.levels.INFO)
      if api.download_db_sync() then
        local new_db = api.load_db()
        filtered_plugins = vim.deepcopy(new_db)
        render_list()
        vim.notify("MiniStore: 刷新完成！", vim.log.levels.INFO)
      end
    end, opts)

    -- 添加高亮命名空间
    local highlight_ns = vim.api.nvim_create_namespace("ministore_highlight")

    vim.keymap.set({ "i", "n" }, "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
      local target = filtered_plugins[cursor[1]]

      if target then
        -- 如果之前已选择了一个插件，先清除其高亮
        if selected_plugin then
          local prev_index = 0
          for i, p in ipairs(filtered_plugins) do
            if p.name == selected_plugin.name then
              prev_index = i
              break
            end
          end
          -- 重新应用已安装插件的高亮
          if installed_plugins[selected_plugin.name] then
            vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", prev_index - 1, 0, -1)
          else
            -- 清除普通插件的高亮
            vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, prev_index - 1, prev_index)
          end
        end
        
        selected_plugin = target -- 标记为选中，而不是立即安装
        vim.notify("📦 已选中插件: " .. target.name .. "。按 Esc 确认安装。", vim.log.levels.INFO)
        -- 高亮选中行
        vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, cursor[1] - 1, cursor[1])
        vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", cursor[1] - 1, 0, -1)
        -- 重新高亮已安装的插件行
        for i, p in ipairs(filtered_plugins) do
          if installed_plugins[p.name] and p.name ~= target.name then
            vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", i - 1, 0, -1)
          end
        end
      end
    end, opts)

    vim.keymap.set({ "i", "n" }, "d", function()
      local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
      local target = filtered_plugins[cursor[1]]
      if target and installed_plugins[target.name] then
         -- 如果之前已标记了一个插件待删除，先清除其高亮
         if marked_for_removal then
           local prev_index = 0
           for i, p in ipairs(filtered_plugins) do
             if p.name == marked_for_removal.name then
               prev_index = i
               break
             end
           end
           -- 重新应用已安装插件的高亮
           vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", prev_index - 1, 0, -1)
         end
         
         -- 如果这个插件也是选中待安装的，清除选中状态
         if selected_plugin and selected_plugin.name == target.name then
           selected_plugin = nil
         end
         
         marked_for_removal = target -- 标记为预删除，而不是立即删除
         vim.notify("🗑️ 已标记插件 '" .. target.name .. "' 为待删除。按 Esc 确认操作。", vim.log.levels.INFO)
         -- 高亮标记删除的行
         vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, cursor[1] - 1, cursor[1])
         vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "WarningMsg", cursor[1] - 1, 0, -1)
         -- 重新高亮其他已安装的插件行
         for i, p in ipairs(filtered_plugins) do
           if installed_plugins[p.name] and p.name ~= target.name then
             vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", i - 1, 0, -1)
           end
         end
      end
    end, opts)

    vim.keymap.set("i", "<C-j>", function()
      local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
      if cursor[1] < #filtered_plugins then
        vim.api.nvim_win_set_cursor(ui.list_win, { cursor[1] + 1, 0 })
        -- 高亮选中行
        vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", cursor[1], 0, -1)
        
        -- 重新高亮已安装的插件行
        for i, p in ipairs(filtered_plugins) do
          if installed_plugins[p.name] then
            vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", i - 1, 0, -1)
          end
        end
      end
    end, opts)

    vim.keymap.set("i", "<C-k>", function()
      local cursor = vim.api.nvim_win_get_cursor(ui.list_win)
      if cursor[1] > 1 then
        vim.api.nvim_win_set_cursor(ui.list_win, { cursor[1] - 1, 0 })
        -- 高亮选中行
        vim.api.nvim_buf_clear_namespace(ui.list_buf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Visual", cursor[1] - 2, 0, -1)
        
        -- 重新高亮已安装的插件行
        for i, p in ipairs(filtered_plugins) do
          if installed_plugins[p.name] then
            vim.api.nvim_buf_add_highlight(ui.list_buf, -1, "Special", i - 1, 0, -1)
          end
        end
      end
    end, opts)

    local close_all = function()
      vim.cmd("stopinsert")
      
      -- 处理删除操作
      if marked_for_removal then
        vim.ui.select({"是", "否"}, {
          prompt = "是否删除插件 '" .. marked_for_removal.name .. "'?"
        }, function(choice)
          if choice == "是" then
            vim.notify("📤 正在删除插件: " .. marked_for_removal.name, vim.log.levels.INFO)
            local success = api.remove_plugin(marked_for_removal.name)
            if success then
              vim.notify("✅ 插件 '" .. marked_for_removal.name .. "' 删除成功", vim.log.levels.INFO)
              -- 删除成功后，刷新已安装插件列表
              local plugin_name = marked_for_removal.name
              installed_plugins[plugin_name] = nil
              -- 调用 Lazy 的清理命令
              vim.schedule(function()
                local clean_success, clean_err = pcall(require("lazy").clean, { plugin_name })
                if clean_success then
                  vim.notify("✨ Lazy 清理完成，正在后台同步...", vim.log.levels.DEBUG)
                  -- 触发静默检查更新以移除残留状态
                  pcall(require("lazy").check, { show = false })
                else
                  vim.notify("⚠️ Lazy 清理失败: " .. tostring(clean_err), vim.log.levels.WARN)
                end
              end)
            else
              vim.notify("❌ 插件 '" .. marked_for_removal.name .. "' 删除失败", vim.log.levels.ERROR)
            end
          else
            vim.notify("↩️ 取消删除插件: " .. marked_for_removal.name, vim.log.levels.INFO)
          end
          
          -- 关闭窗口
          pcall(vim.api.nvim_win_close, ui.input_win, true)
          pcall(vim.api.nvim_win_close, ui.list_win, true)
          -- 重置标记
          marked_for_removal = nil
        end)
      -- 处理安装操作
      elseif selected_plugin then
        vim.ui.select({"是", "否"}, {
          prompt = "是否安装插件 '" .. selected_plugin.name .. "'?"
        }, function(choice)
          if choice == "是" then
            vim.notify("📥 正在安装插件: " .. selected_plugin.name, vim.log.levels.INFO)
            local success = api.install_plugin(selected_plugin.repo, selected_plugin.name)
            if success then
              vim.notify("✅ 插件 '" .. selected_plugin.name .. "' 配置创建成功", vim.log.levels.INFO)
              -- 安装成功后，调用 Lazy 的安装命令
              local plugin_name = selected_plugin.name
              vim.schedule(function()
                vim.notify("🚀 正在通知 Lazy 安装插件: " .. plugin_name, vim.log.levels.DEBUG)
                local install_success, install_err = pcall(require("lazy").install, { plugin_name })
                if install_success then
                  vim.notify("✨ Lazy 安装完成，正在后台索引...", vim.log.levels.DEBUG)
                  -- 触发静默检查更新以刷新状态
                  pcall(require("lazy").check, { show = false })
                else
                  vim.notify("⚠️ Lazy 安装失败: " .. tostring(install_err), vim.log.levels.WARN)
                end
              end)
            else
              vim.notify("❌ 插件 '" .. selected_plugin.name .. "' 安装失败", vim.log.levels.ERROR)
            end
          else
            vim.notify("↩️ 取消安装插件: " .. selected_plugin.name, vim.log.levels.INFO)
          end
          
          -- 关闭窗口
          pcall(vim.api.nvim_win_close, ui.input_win, true)
          pcall(vim.api.nvim_win_close, ui.list_win, true)
          -- 重置标记
          selected_plugin = nil
        end)
      else
        -- 没有选中插件，直接关闭
        vim.notify("🚪 关闭插件商店", vim.log.levels.INFO)
        pcall(vim.api.nvim_win_close, ui.input_win, true)
        pcall(vim.api.nvim_win_close, ui.list_win, true)
      end
    end
    vim.keymap.set({ "i", "n" }, "<Esc>", close_all, opts)
    vim.keymap.set({ "i", "n" }, "<C-c>", close_all, opts)
  end)
end

return M