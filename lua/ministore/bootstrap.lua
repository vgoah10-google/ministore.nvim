-- lua/ministore/bootstrap.lua
local M = {}

-- 这个函数现在只负责生成插件内部的用户配置文件
function M.setup()
  local lazy_config_avail, lazy_config = pcall(require, "lazy.core.config")
  
  -- 如果 lazy 配置不可用，延迟执行
  if not lazy_config_avail then
    vim.schedule(function()
      M.setup()
    end)
    return
  end
  
  -- 检查插件是否已安装
  local plugin_info = lazy_config.plugins["ministore.nvim"]
  if plugin_info then
    -- 生成插件内部的用户配置文件
    local config_path = plugin_info.dir .. "/lua/ministore_user_config.lua"
    if vim.fn.filereadable(config_path) == 0 then
      local content = [[
-- MiniStore 自动生成用户配置
return {
  api_url = "https://neovimcraft.com",
  timeout = 5000,
}
]]
      local f = io.open(config_path, "w")
      if f then
        f:write(content)
        f:close()
        vim.notify("MiniStore: 用户配置文件已生成至: " .. config_path, vim.log.levels.INFO)
      end
    end
  end
end

return M