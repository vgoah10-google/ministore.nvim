local M = {}

local data_path = vim.fn.stdpath("data")
local config_path = vim.fn.stdpath("config")

-- 获取Lazy配置目录
function M.get_lazy_plugin_dir()
  -- 首先尝试通过Lazy核心模块获取配置
  local lazy_core_config = nil
  local success, result = pcall(require, "lazy.core.config")
  
  if success and result and result.options then
    lazy_core_config = result
    
    -- 从Lazy核心配置中获取插件目录
    local root_dir = lazy_core_config.options.root
    if root_dir then
      -- 处理相对路径和环境变量
      if root_dir:sub(1, 1) == "~" then
        root_dir = vim.fn.expand(root_dir)
      elseif not (root_dir:sub(1, 1) == "/" or root_dir:match("^%a:")) then
        -- 相对路径，相对于数据目录
        root_dir = data_path .. "/" .. root_dir
      end
      
      -- 插件配置目录通常是root下的plugins子目录
      local plugin_dir = root_dir .. "/plugins/"
      
      -- 确保目录存在
      if vim.fn.isdirectory(root_dir) == 0 then
        vim.fn.mkdir(root_dir, "p")
      end
      
      if vim.fn.isdirectory(plugin_dir) == 0 then
        vim.fn.mkdir(plugin_dir, "p")
      end
      
      return plugin_dir
    end
  end
  
  -- 如果无法通过核心模块获取配置，则尝试从配置文件中解析
  local lazy_config_file = config_path .. "/plugin/lazy.lua"
  if vim.fn.filereadable(lazy_config_file) == 1 then
    -- 解析配置文件内容
    local content = vim.fn.readfile(lazy_config_file)
    for _, line in ipairs(content) do
      -- 查找Lazy配置中的root设置
      local root_dir = line:match('root%s*=%s*["\']([^"\']*)')
      if root_dir then
        -- 处理相对路径和环境变量
        if root_dir:sub(1, 1) == "~" then
          root_dir = vim.fn.expand(root_dir)
        elseif not (root_dir:sub(1, 1) == "/" or root_dir:match("^%a:")) then
          -- 相对路径，相对于数据目录
          root_dir = data_path .. "/" .. root_dir
        end
        
        -- 插件配置目录通常是root下的plugins子目录
        local plugin_dir = root_dir .. "/plugins/"
        
        -- 确保目录存在
        if vim.fn.isdirectory(root_dir) == 0 then
          vim.fn.mkdir(root_dir, "p")
        end
        
        if vim.fn.isdirectory(plugin_dir) == 0 then
          vim.fn.mkdir(plugin_dir, "p")
        end
        
        return plugin_dir
      end
    end
  end
  
  -- 默认插件配置目录
  local default_dir = config_path .. "/lua/plugins/"
  
  -- 确保目录存在
  if vim.fn.isdirectory(default_dir) == 0 then
    vim.fn.mkdir(default_dir, "p")
  end
  
  return default_dir
end

-- 获取插件配置目录
M.lazy_plugin_dir = M.get_lazy_plugin_dir()

-- nvim.store 官方原始数据源
local raw_api = "https://githubusercontent.com"

-- 【核心优化】由于国内或部分网络访问 GitHub Raw 极慢且易断，这里默认挂载了高速加速镜像
M.store_api = "https://ghproxy.com/" .. raw_api

return M