local M = {}
local config = require("ministore.config")
local CACHE_PATH = vim.fn.stdpath("cache") .. "/ministore_db.json"

-- 补全旧接口
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

function M.load_db()
  if vim.fn.filereadable(CACHE_PATH) == 1 then
    local content = vim.fn.readfile(CACHE_PATH)
    local ok, db = pcall(vim.json.decode, table.concat(content, ""))
    if ok then return db end
  end
  return nil
end

function M.sync_database()
  vim.system({"curl", "-sI", config.store_api}, {}, function(obj)
    if obj.code ~= 0 then return end
    
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
    M.manual_update_and_load(callback)
  end
end

-- 辅助函数：手动更新并回调
function M.manual_update_and_load(callback)
    print("MiniStore Debug: 开始调用 curl 下载数据...")
    vim.system({"curl", "-sL", config.store_api}, {}, function(res)
        if res.code == 0 then
            print("MiniStore Debug: curl 下载成功，大小: " .. #res.stdout .. " bytes")
            -- 将数据直接写入文件以供 load_db 读取
            local f = io.open(CACHE_PATH, "w")
            if f then
                f:write(res.stdout)
                f:close()
            end
            
            vim.schedule(function() 
                local db = M.load_db()
                if db then
                    callback(db)
                    vim.notify("MiniStore: 数据库已初始化。", vim.log.levels.INFO)
                else
                    print("MiniStore Error: JSON 解析失败。数据样本: " .. res.stdout:sub(1, 100))
                    vim.notify("MiniStore: 数据解析失败，请查看 :messages", vim.log.levels.ERROR)
                end
            end)
        else
            print("MiniStore Error: curl 下载失败，代码: " .. res.code .. " 错误: " .. res.stderr)
            vim.schedule(function()
                vim.notify("MiniStore: 数据库下载失败，请检查网络。", vim.log.levels.ERROR)
            end)
        end
    end)
end

return M
