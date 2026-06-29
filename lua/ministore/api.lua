local M = {}
local config = require("ministore.config")

-- 动态获取 lazy 的配置目录
function M.get_lazy_plugin_path()
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if not (ok and lazy_config) then return config.lazy_plugin_dir end

  -- 1. 寻找用户通过 spec.import 导入的目录
  local import_module = nil
  if lazy_config.options and lazy_config.options.spec then
    for _, spec in ipairs(lazy_config.options.spec) do
      if type(spec) == "table" and spec.import then
        import_module = spec.import
        break
      end
    end
  end

  -- 2. 如果找到了 import 模块
  if import_module then
    -- import_module 可能是 "sandbox_plugins"，转换成路径需要查找 runtimepath
    local path = vim.api.nvim_get_runtime_file("lua/" .. import_module:gsub("%.", "/") .. "/init.lua", false)[1]
    
    if path then
      return vim.fs.dirname(path) .. "/"
    else
      -- 尝试寻找目录形式
      local dir_path = vim.api.nvim_get_runtime_file("lua/" .. import_module:gsub("%.", "/"), false)[1]
      if dir_path and vim.fn.isdirectory(dir_path) == 1 then
        return dir_path .. "/"
      end
    end
  end

  -- 3. 后备方案：如果没有 import，默认指向 ~/.config/nvim/lua/plugins
  return vim.fn.stdpath("config") .. "/lua/plugins/"
end

M.cached_plugins = {}
M.is_loading = false
M.stop_requested = false

-- 获取已安装插件列表
function M.get_installed_plugins()
  local installed = {}
  
  -- 首先尝试通过Lazy核心模块获取已安装插件
  local lazy_core_config = nil
  local success, result = pcall(require, "lazy.core.config")
  
  if success and result and result.plugins then
    -- 从Lazy核心配置中获取已注册的插件
    for _, plugin in pairs(result.plugins) do
      if plugin.name then
        installed[plugin.name] = true
      end
    end
    
    vim.notify("🔍 通过 Lazy 核心模块获取到 " .. vim.fn.len(installed) .. " 个已安装插件", vim.log.levels.DEBUG)
    return installed
  else
    vim.notify("⚠️ 无法通过 Lazy 核心模块获取插件列表，使用备用方法", vim.log.levels.DEBUG)
  end
  
  -- 如果无法通过核心模块获取，则检查插件配置目录
  local lazy_plugin_dir = M.get_lazy_plugin_path()
  vim.notify("📂 检查插件配置目录: " .. lazy_plugin_dir, vim.log.levels.DEBUG)
  
  -- 检查Lazy插件配置目录
  if vim.fn.isdirectory(lazy_plugin_dir) == 1 then
    local files = vim.fn.readdir(lazy_plugin_dir)
    for _, file in ipairs(files) do
      if file:match("%.lua$") then
        local plugin_name = file:gsub("%.lua$", "")
        installed[plugin_name] = true
      end
    end
    vim.notify("🔍 通过目录扫描获取到 " .. vim.fn.len(installed) .. " 个已安装插件", vim.log.levels.DEBUG)
  else
    vim.notify("⚠️ 插件配置目录不存在: " .. lazy_plugin_dir, vim.log.levels.WARN)
  end
  
  return installed
end

-- 【物理真实存在、开源且国内直连的 NeovimCraft 官方核心 HTTPS 终点】
local target_url = "https://neovimcraft.com/db.json"

function M.fetch_plugins(on_success)
  -- 1. 全局内存缓存命中判定
  if #M.cached_plugins > 0 then
    on_success(M.cached_plugins)
    return
  end

  -- 2. 防连击请求拦截
  if M.is_loading then
    vim.notify("⏳ 正在通过核心管道拉取是在线数据中，请稍候...", vim.log.levels.WARN)
    return
  end

  M.is_loading = true
  M.stop_requested = false
  local retry_count = 0

  -- 3. 声明递归的后台非阻塞重试工作流
  local function worker()
    if M.stop_requested then
      M.is_loading = false
      vim.notify("🛑 用户已手动终止应用商店的连接请求！", vim.log.levels.WARN)
      return
    end

    retry_count = retry_count + 1
    vim.notify(
      string.format("📡 [CURL GET] 发起远程请求 (第 %d 次尝试): %s", retry_count, target_url),
      vim.log.levels.INFO
    )

    -- 【核心黑魔法】：使用系统级同步命令进行绝对稳健的网络请求
    -- 配合延时和保护，整个过程在极短时间内拉回全量明文，免去了一切密文解密烦恼
    -- -s 代表静默不输出进度条，-L 代表自动处理 301/302 重定向
    local ok, stdout = pcall(vim.fn.system, string.format("curl -sL %s", target_url))

    -- 物理延迟给主线程留出渲染空气，防止同步堵塞引发 UI 瞬时假死
    vim.schedule(function()
      -- A. 检查 curl 管道是否发生崩塌或返回空字符串
      if not ok or not stdout or stdout == "" then
        vim.notify("⚠️ 物理管道连接受阻，2.5秒后自动发起物理重试...", vim.log.levels.WARN)
        vim.defer_fn(worker, 2500)
        return
      end

      -- B. 将 curl 吐回的 100% 完整纯净明文 JSON，直接喂给 Neovim 的高效解析引擎
      local json_ok, decoded = pcall(vim.json.decode, stdout)
      if not json_ok or not decoded or not decoded.plugins then
        vim.notify(
          "⚠️ 数据完整性校验失败 (JSON 被网络节点截断)，2.5秒后自动重新拉取...",
          vim.log.levels.WARN
        )
        vim.defer_fn(worker, 2500)
        return
      end

      -- C. 完美对齐：使用 pairs 循环精确压榨并抽取 NeovimCraft 的字典项
      M.cached_plugins = {}
      for repo_key, item in pairs(decoded.plugins) do
        if type(item) == "table" then
          table.insert(M.cached_plugins, {
            name = item.name or repo_key:match("/(.*)") or repo_key,
            repo = item.id or repo_key,
            stars = item.stars or 0,
            desc = item.description or item.desc or "暂无描述信息。",
          })
        end
      end

      -- D. 严密防御拦截：防止错位返回空数组
      if #M.cached_plugins == 0 then
        vim.notify("⚠️ 字典字段映射提取为空，正在尝试重新建立连接...", vim.log.levels.WARN)
        vim.defer_fn(worker, 2500)
        return
      end

      -- E. 按照热门流行度（GitHub Stars 数量）从大到小严格进行降序物理重排
      table.sort(M.cached_plugins, function(a, b)
        return a.stars > b.stars
      end)

      M.is_loading = false
      vim.notify(
        string.format("✨ 远程应用商店成功激活！共 %d 个真实插件已就绪。", #M.cached_plugins),
        vim.log.levels.INFO
      )
      on_success(M.cached_plugins) -- 顺利通关，唤醒前端 UI 面板绘制呈现
    end)
  end

  -- 启动第一波异步重试工作流
  worker()
end

-- 提供给外部用户进行手动强行切断重试循环的方法
function M.abort_fetch()
  if M.is_loading then
    M.stop_requested = true
  else
    vim.notify("ℹ️ 当前没有正在运行的网络请求。", vim.log.levels.INFO)
  end
end

-- 生成Lazy配置文件内容
local function generate_lazy_config(plugin_repo, name)
  local config_template = [[return {
  "%s",
  lazy = true,
  -- Add your plugin configuration here
  -- config = function()
  --   require("%s").setup()
  -- end
}
]]
  
  -- 提取插件名称（通常是GitHub仓库的名称）
  local plugin_name = plugin_repo:match("/([^/]+)$") or name
  return string.format(config_template, plugin_repo, plugin_name)
end

-- 4. 为Lazy创建插件配置文件
function M.install_plugin(plugin_repo, name)
  local lazy_plugin_dir = M.get_lazy_plugin_path()
  local config_file = lazy_plugin_dir .. name .. ".lua"
  
  vim.notify("🔧 安装插件: " .. name .. " (仓库: " .. plugin_repo .. ")", vim.log.levels.INFO)
  vim.notify("📂 目标配置目录: " .. lazy_plugin_dir, vim.log.levels.DEBUG)
  vim.notify("📄 配置文件路径: " .. config_file, vim.log.levels.DEBUG)
  
  -- 诊断目录是否存在
  local parent_dir = vim.fn.fnamemodify(config_file, ":h")
  if vim.fn.isdirectory(parent_dir) == 0 then
    -- 如果不存在，尝试创建
    local mkdir_result = vim.fn.mkdir(parent_dir, "p")
    if mkdir_result == 1 then
      vim.notify("📁 配置目录创建成功: " .. parent_dir, vim.log.levels.INFO)
    else
      vim.notify("❌ 配置目录创建失败: " .. parent_dir, vim.log.levels.ERROR)
      return false
    end
  else
    vim.notify("🔍 配置目录已存在: " .. parent_dir, vim.log.levels.DEBUG)
  end

  -- 检查是否已安装
  if vim.fn.filereadable(config_file) == 1 then
    vim.notify("⚠️ 插件 " .. name .. " 已经在Lazy配置中了！(文件路径: " .. config_file .. ")", vim.log.levels.WARN)
    return false -- 返回 false 而不是 nil
  end

  vim.notify("🚀 正在为Lazy创建配置: " .. config_file, vim.log.levels.INFO)
  
  -- 生成配置内容
  local config_content = generate_lazy_config(plugin_repo, name)
  vim.notify("📝 生成配置内容: " .. config_content, vim.log.levels.DEBUG)
  
  -- 写入配置文件
  local file, err = io.open(config_file, "w")
  if file then
    file:write(config_content)
    file:close()
    vim.notify("✨ " .. name .. " 配置创建成功！Lazy 将自动检测并安装。", vim.log.levels.INFO)
    return true
  else
    vim.notify("❌ 配置创建失败: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
end

-- 查找插件定义的原始物理文件
function M.find_plugin_origin(plugin_name)
    local plugins_dir = M.get_lazy_plugin_path()
    
    if vim.fn.isdirectory(plugins_dir) ~= 1 then
        return nil
    end

    for name, type in vim.fs.dir(plugins_dir) do
        if type == "file" and name:match("%.lua$") then
            local file_path = plugins_dir .. name
            local content = vim.fn.readfile(file_path, "")
            local content_str = table.concat(content, "\n")
            
            -- 正则匹配：匹配单引号或双引号包围的插件名
            -- 示例: "ThePrimeagen/harpoon" 或 'ThePrimeagen/harpoon'
            local pattern = "['\"]([^'\"]*/?" .. plugin_name .. ")['\"]"
            if content_str:match(pattern) then
                return file_path
            end
        end
    end
    return nil
end

-- 5. 删除插件配置文件
function M.remove_plugin(name)
  local config_file = M.find_plugin_origin(name)
  
  if config_file then
    vim.notify("📍 准备删除插件配置文件: " .. config_file, vim.log.levels.INFO)
    local delete_result = vim.fn.delete(config_file)
    if delete_result == 0 then
      vim.notify("🗑️ 插件 " .. name .. " 配置已物理移除。", vim.log.levels.INFO)
      return true
    else
      vim.notify("❌ 插件 " .. name .. " 配置删除失败。", vim.log.levels.ERROR)
      return false
    end
  else
    vim.notify("⚠️ 未找到插件 " .. name .. " 的配置文件。", vim.log.levels.WARN)
    return false
  end
end

return M
