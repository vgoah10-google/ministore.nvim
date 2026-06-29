-- lua/ministore/bootstrap.lua
local M = {}

function M.setup()
  -- 1. 动态获取 Lazy 插件安装根目录
  -- 完美解决路径动态问题，无需硬编码
  local lazy_root = vim.fn.stdpath("data") .. "/lazy"
  local ministore_path = lazy_root .. "/ministore.nvim"
  local config_path = ministore_path .. "/lua/ministore_user_config.lua"

  -- 2. 检查插件是否已由 Lazy 安装
  if vim.fn.isdirectory(ministore_path) == 0 then
    -- 如果未发现插件目录，触发告警并中断加载
    vim.api.nvim_err_writeln("MiniStore 插件未安装，请在 Lazy 中配置安装后重启。")
    return false
  end

  -- 3. 自动生成配置文件到插件目录
  -- 这里生成到插件目录，使得插件可以轻松 require 它
  if vim.fn.filereadable(config_path) == 0 then
    local content = [[
-- MiniStore 自动生成配置
return {
  api_url = "https://neovimcraft.com",
  timeout = 5000,
}
]]
    local f = io.open(config_path, "w")
    if f then
      f:write(content)
      f:close()
      vim.notify("MiniStore: 配置文件已自动生成至: " .. config_path, vim.log.levels.INFO)
    end
  end
  return true
end

return M
