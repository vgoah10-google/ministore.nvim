local M = {}

-- 明确在顶部 require 所有模块
local api_module = require("ministore.api")

-- 简单的断言辅助函数
local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("断言失败: %s (预期: %s, 实际: %s)", message, tostring(expected), tostring(actual)))
  end
end

local function run_step(name, fn)
  vim.notify("▶️ 开始测试步骤: " .. name, vim.log.levels.INFO)
  local status, err = pcall(fn)
  if not status then
    vim.notify("❌ 步骤失败 [" .. name .. "]: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  vim.notify("✅ 步骤成功 [" .. name .. "]", vim.log.levels.INFO)
  return true
end

function M.run_test()
  local TEST_REPO = "rebelot/kanagawa.nvim"
  local TEST_NAME = "kanagawa"
  local old_colorscheme = vim.g.colors_name

  vim.notify("🧪 MiniStore 集成测试套件启动", vim.log.levels.INFO)

  -- 步骤 1: 测试安装
  run_step("插件安装", function()
    local success = api_module.install_plugin(TEST_REPO, TEST_NAME)
    assert_eq(success, true, "安装插件函数应返回 true")
    
    -- 强制触发一次检查确保 Lazy 感知到文件
    pcall(require("lazy").check, { show = false })
    
    -- 验证文件存在
    local lazy_plugin_dir = api_module.get_lazy_plugin_path()
    local config_file = lazy_plugin_dir .. TEST_NAME .. ".lua"
    assert_eq(vim.fn.filereadable(config_file), 1, "配置文件应该物理存在")
  end)

  -- 步骤 2: 等待 Lazy 同步（模拟）
  vim.defer_fn(function()
    
    -- 步骤 3: 验证安装结果 (移除对 colorscheme 的依赖)
    run_step("插件安装状态验证", function()
      local lazy_plugin_dir = api_module.get_lazy_plugin_path()
      local config_file = lazy_plugin_dir .. TEST_NAME .. ".lua"
      
      -- 如果文件确实不存在，说明安装逻辑有瑕疵
      assert_eq(vim.fn.filereadable(config_file), 1, "测试后插件配置物理文件应存在")
    end)

    -- 步骤 4: 测试删除
    run_step("插件卸载", function()
      -- 显式调用删除，传入插件名称
      local success = api_module.remove_plugin(TEST_NAME)
      assert_eq(success, true, "删除插件函数应返回 true")
      
      -- 验证文件是否已消失
      -- 此时调用 find_plugin_origin 确认
      local config_file = api_module.find_plugin_origin(TEST_NAME)
      assert_eq(config_file == nil, true, "配置文件应该已被物理删除")
    end)

    vim.notify("🎉 MiniStore 测试套件执行完毕！", vim.log.levels.INFO)
  end, 3000)
end

function M.run_unit_tests()
  vim.notify("🛠️ 启动 MiniStore 单元测试...", vim.log.levels.INFO)
  
  -- 1. 过滤逻辑测试
  local filter_test = require("ministore.tests.test_filter")
  if filter_test.run_all_tests then 
    local ok, err = pcall(filter_test.run_all_tests)
    if not ok then vim.notify("❌ 过滤测试失败: " .. tostring(err), vim.log.levels.ERROR) end
  end

  -- 2. 排序稳定性测试 (针对 E5108 Bug)
  local sort_test = require("ministore.tests.test_sort")
  if sort_test.test_sort then
    local ok, err = pcall(sort_test.test_sort)
    if not ok then vim.notify("❌ 排序测试失败: " .. tostring(err), vim.log.levels.ERROR) end
  end
  
  vim.notify("🏁 所有单元测试执行完毕", vim.log.levels.INFO)
end

return M
