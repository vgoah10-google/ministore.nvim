local M = {}
local config = require("ministore.config")
-- 在 config.lua 中，有一个 M.lazy_plugin_dir，我们可以借用它
-- 获取插件配置目录作为缓存存放位置
local config = require("ministore.config")
local CACHE_PATH = config.lazy_plugin_dir .. "/../ministore_db.json"

-- 获取已安装插件列表 (保持不变)
function M.get_installed_plugins()
  local plugins = {}
  local ok, lazy_core = pcall(require, "lazy.core.config")
  if ok and lazy_core.plugins then
    for name, _ in pairs(lazy_core.plugins) do
      plugins[name] = true
    end
  end
  return plugins
end

local cached_plugins = nil

-- 读取本地缓存
function M.load_db()
  if vim.fn.filereadable(CACHE_PATH) == 1 then
    local content = vim.fn.readfile(CACHE_PATH)
    local ok, raw_db = pcall(vim.json.decode, table.concat(content, ""))
    if ok and raw_db and raw_db.plugins then
      local plugins_array = {}
      for _, p in pairs(raw_db.plugins) do
        table.insert(plugins_array, {
          name = p.name or "unknown",
          repo = p.id or "",
          stars = p.stars or 0,
          desc = p.description or p.desc or ""
        })
      end
      cached_plugins = plugins_array -- 更新私有缓存
      return plugins_array
    end
  end
  return nil
end

function M.get_all_plugins()
  return cached_plugins or M.load_db() or {}
end

function M.refresh_cache()
    cached_plugins = M.load_db()
    return cached_plugins
end

-- 安装插件逻辑 (复用 Lazy Spec 动态发现逻辑)
function M.install_plugin(repo, name)
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if not ok then 
    print("MiniStore Error: Lazy.nvim 未加载")
    return false 
  end

  for _, mod_name in ipairs(lazy_config.spec.modules) do
    local rel_path = "lua/" .. mod_name:gsub("%.", "/")
    local paths = vim.api.nvim_get_runtime_file(rel_path, true)
    
    if #paths > 0 then
      local target_dir = paths[1]
      local plugin_file = target_dir .. "/" .. name .. ".lua"
      
      local repo_url = repo:find("/") and ("https://github.com/" .. repo) or repo
      local content = string.format('return {\n  "%s",\n  name = "%s"\n}\n', repo_url, name)
      
      local f = io.open(plugin_file, "w")
      if f then
        f:write(content)
        f:close()
        print("MiniStore: 已在 " .. mod_name .. " 动态注入插件: " .. name)
        
        -- 尝试即时加载插件
        pcall(require("lazy").load, { plugins = { name } })
        return true
      end
    end
  end
  
  print("MiniStore Error: 未发现合适的 Lazy spec 模块目录")
  return false
end

-- 删除插件逻辑
function M.remove_plugin(name)
  local config_path = vim.fn.stdpath("config") .. "/lua/ministore_user_config.lua"
  if vim.fn.filereadable(config_path) == 0 then return false end
  
  local lines = vim.fn.readfile(config_path)
  local new_lines = {}
  local found = false
  for _, line in ipairs(lines) do
    if not line:find("-- " .. name) then
      table.insert(new_lines, line)
    else
      found = true
    end
  end
  
  if found then
    vim.fn.writefile(new_lines, config_path)
    return true
  end
  return false
end

-- 同步下载（阻塞式，用于初始化和 Ctrl-R）
function M.download_db_sync()
  print("MiniStore: 正在下载数据库...")
  -- Windows 下直接调用 curl
  local cmd = string.format("curl -sL %s -o %s", config.store_api, CACHE_PATH)
  local exit_code = os.execute(cmd)
  if exit_code == 0 then
    print("MiniStore: 数据库更新成功")
    return true
  else
    print("MiniStore Error: 数据库更新失败")
    return false
  end
end

-- fetch_plugins 接口：逻辑更简单
function M.fetch_plugins(callback)
  local db = M.load_db()
  
  -- 如果没缓存，强制阻塞下载
  if not db then
    if M.download_db_sync() then
      db = M.load_db()
    end
  end
  
  if db then
    callback(db)
  else
    vim.notify("MiniStore: 无法加载数据，请检查网络", vim.log.levels.ERROR)
  end
end

return M
