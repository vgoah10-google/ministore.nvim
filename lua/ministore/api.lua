local M = {}
local config = require("ministore.config")
local CACHE_PATH = vim.fn.stdpath("cache") .. "/ministore_db.json"
print("MiniStore Debug: Cache path is: " .. CACHE_PATH)

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
      return plugins_array
    end
  end
  return nil
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
