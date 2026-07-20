local M = {}
local config = require("ministore.config")
local CACHE_PATH = vim.fn.stdpath("cache") .. "/ministore_db.json"

function M.load_db()
  if vim.fn.filereadable(CACHE_PATH) == 1 then
    local content = vim.fn.readfile(CACHE_PATH)
    local ok, db = pcall(vim.json.decode, table.concat(content, ""))
    if ok then return db end
  end
  return nil
end

function M.sync_database()
  -- 异步检查更新
  vim.system({"curl", "-sI", config.store_api}, {}, function(obj)
    if obj.code ~= 0 then return end
    
    -- 如果本地缓存不存在，强制下载
    local force_download = vim.fn.filereadable(CACHE_PATH) == 0
    
    if force_download or config.auto_update_db then
      vim.system({"curl", "-sL", config.store_api, "-o", CACHE_PATH}, {}, function(res)
        if res.code == 0 then
          vim.schedule(function()
            vim.notify("MiniStore: 插件数据库已" .. (force_download and "初始化" or "自动更新"), vim.log.levels.INFO)
          end)
        end
      end)
    else
      vim.schedule(function()
        vim.notify("MiniStore: 有新的插件数据可用，执行 :MiniStoreUpdate 更新。", vim.log.levels.INFO)
      end)
    end
  end)
end

function M.manual_update()
  vim.system({"curl", "-sL", config.store_api, "-o", CACHE_PATH}, {}, function(res)
    if res.code == 0 then
      vim.schedule(function() vim.notify("MiniStore: 数据库已手动更新至最新。", vim.log.levels.INFO) end)
    end
  end)
end

-- 兼容旧接口
function M.fetch_plugins(callback)
  local db = M.load_db()
  if db then 
    callback(db)
  else
    -- 如果缓存为空，则强制下载
    M.manual_update_and_load(callback)
  end
end

-- 辅助函数：手动更新并回调
function M.manual_update_and_load(callback)
    vim.system({"curl", "-sL", config.store_api, "-o", CACHE_PATH}, {}, function(res)
        if res.code == 0 then
            vim.schedule(function() 
                callback(M.load_db())
                vim.notify("MiniStore: 数据库已初始化。", vim.log.levels.INFO)
            end)
        end
    end)
end

return M
