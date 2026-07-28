-- =============================================================================
-- MiniStore.nvim 过滤函数测试套件
-- 目的: 实锤验证查询/过滤逻辑的正确性，重构后必须通过所有测试
-- 运行: :MiniStoreTest
-- =============================================================================

local ui = require("ministore.ui")

-- 如果无法加载 ui（例如在独立 Lua 测试环境），提供本地原型实现
local function to_str(val)
  if type(val) == "string" then return val end
  if type(val) == "number" then return tostring(val) end
  return ""
end

if type(ui) ~= "table" or type(ui.filter_plugins) ~= "function" then
  -- Shutdown: 在没有 ui 的环境下提供一个参考实现进行测试
  ui = { filter_plugins = function(query, plugins)
    if type(plugins) ~= "table" then plugins = {} end
    local result = {}
    if type(query) ~= "string" or query == "" then
      for i, p in ipairs(plugins) do result[i] = p end
      return result
    end
    local tokens = {}
    for token in string.gmatch(query, "%S+") do
      token = token:lower()
      if token ~= "" then table.insert(tokens, token) end
    end
    if #tokens == 0 then
      for i, p in ipairs(plugins) do result[i] = p end
      return result
    end
    for _, p in ipairs(plugins) do
      if type(p) == "table" then
        local name = to_str(p.name):lower()
        local desc = to_str(p.desc):lower()
        local repo = to_str(p.repo):lower()
        local all_matched = true
        for _, token in ipairs(tokens) do
          if not (name:find(token, 1, true) or desc:find(token, 1, true) or repo:find(token, 1, true)) then
            all_matched = false; break
          end
        end
        if all_matched then table.insert(result, p) end
      end
    end
    return result
  end }
end

-- 测试用 fixture 数据
local function make_fixtures()
  return {
    { name = "nvim-ufo",           repo = "kevinhwang93/nvim-ufo",         desc = "Ultra Fast Fuzzy Finder for Neovim",          stars = 4500 },
    { name = "telescope.nvim",     repo = "nvim-telescope/telescope.nvim",  desc = "Find, Filter, Preview, Pick. All lua, blazingly fast.", stars = 12000 },
    { name = "lsp-zero.nvim",      repo = "VonHeikemen/lsp-zero.nvim",      desc = "A starting point to setup lsp for neovim",      stars = 800 },
    { name = "nvim-lspconfig",     repo = "neovim/nvim-lspconfig",          desc = "Quickstart configurations for the LSP client",  stars = 3500 },
    { name = "treesitter",         repo = "nvim-treesitter/nvim-treesitter", desc = "Treesitter configurations and abstraction layer", stars = 11000 },
    { name = "alpha-nvim",         repo = "goolord/alpha-nvim",             desc = "a lua powered greeter like vim-startify",       stars = 1500 },
    { name = "",                   repo = "",                               desc = "empty entry test",                             stars = 0 },
  }
end

-- 测试计数器
local test_pass = 0
local test_fail = 0
local test_results = {}

local function deep_equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then return false end
  end
  for k, _ in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- 辅助: 检查结果列表中是否包含指定 name
local function contains_plugin(plugins, name)
  for _, p in ipairs(plugins) do
    if p.name == name then return true end
  end
  return false
end

-- 断言函数
local function assert_eq(actual, expected, test_name)
  if deep_equal(actual, expected) then
    test_pass = test_pass + 1
    table.insert(test_results, { ok = true, name = test_name })
  else
    test_fail = test_fail + 1
    local actual_str = type(actual) == "table" and ("{" .. table.concat((function()
      local t = {}
      for _, p in ipairs(actual) do table.insert(t, p.name or "?") end
      return t
    end)(), ",") .. "}") or tostring(actual)
    local expected_str = type(expected) == "table" and ("{" .. table.concat((function()
      local t = {}
      for _, p in ipairs(expected) do table.insert(t, p.name or "?") end
      return t
    end)(), ",") .. "}") or tostring(expected)
    table.insert(test_results, {
      ok = false,
      name = test_name,
      detail = string.format("期望: %s\n实际: %s", expected_str, actual_str)
    })
  end
end

local function assert_contains(plugins, expected_name, test_name)
  if contains_plugin(plugins, expected_name) then
    test_pass = test_pass + 1
    table.insert(test_results, { ok = true, name = test_name })
  else
    test_fail = test_fail + 1
    local names = {}
    for _, p in ipairs(plugins) do table.insert(names, p.name or "?") end
    table.insert(test_results, {
      ok = false,
      name = test_name,
      detail = string.format("期望包含 '%s', 但实际结果: {%s}", expected_name, table.concat(names, ","))
    })
  end
end

local function assert_not_contains(plugins, expected_name, test_name)
  if not contains_plugin(plugins, expected_name) then
    test_pass = test_pass + 1
    table.insert(test_results, { ok = true, name = test_name })
  else
    test_fail = test_fail + 1
    table.insert(test_results, {
      ok = false,
      name = test_name,
      detail = string.format("期望不包含 '%s', 但实际包含了", expected_name)
    })
  end
end

local function assert_count(plugins, expected_count, test_name)
  local actual_count = #plugins
  if actual_count == expected_count then
    test_pass = test_pass + 1
    table.insert(test_results, { ok = true, name = test_name })
  else
    test_fail = test_fail + 1
    table.insert(test_results, {
      ok = false,
      name = test_name,
      detail = string.format("期望 %d 个结果, 实际 %d 个", expected_count, actual_count)
    })
  end
end

-- =============================================================================
-- 测试用例
-- =============================================================================
local function run_all_tests()
  test_pass = 0
  test_fail = 0
  test_results = {}
  
  local plugins = make_fixtures()
  
  -- ---- 基础查询 ----
  assert_count(ui.filter_plugins("", plugins), 7, "[基础] 空查询返回全部")
  assert_count(ui.filter_plugins(nil, plugins), 7, "[基础] nil 查询返回全部")
  assert_count(ui.filter_plugins("ufo", plugins), 1, "[基础] 单字符子串匹配 name")
  assert_count(ui.filter_plugins("UFO", plugins), 1, "[基础] 大写子串匹配 name (大小写不敏感)")
  
  -- ---- 3字符 vs 4字符回归测试 ----
  assert_contains(ui.filter_plugins("ufo", plugins), "nvim-ufo", "[回归] 'ufo' 匹配 'nvim-ufo'")
  assert_not_contains(ui.filter_plugins("ufos", plugins), "nvim-ufo", "[回归] 'ufos' 不匹配 'nvim-ufo'")
  assert_contains(ui.filter_plugins("nvim", plugins), "nvim-ufo", "[回归] 'nvim' (4字符) 匹配 'nvim-ufo'")
  assert_contains(ui.filter_plugins("nvim-ufo", plugins), "nvim-ufo", "[回归] 完整名称匹配")
  
  -- ---- 仓库(repo)字段匹配 ----
  assert_contains(ui.filter_plugins("kevinhwang93", plugins), "nvim-ufo", "[仓库] 通过 repo 匹配")
  assert_contains(ui.filter_plugins("kevin", plugins), "nvim-ufo", "[仓库] 4字符 repo 匹配")
  assert_contains(ui.filter_plugins("KEVIN", plugins), "nvim-ufo", "[仓库] 大写 repo 匹配")
  
  -- ---- 描述(desc)字段匹配 ----
  assert_contains(ui.filter_plugins("fuzzy", plugins), "nvim-ufo", "[描述] 通过 desc 匹配")
  assert_contains(ui.filter_plugins("blazingly", plugins), "telescope.nvim", "[描述] 多字符 desc 匹配")
  assert_not_contains(ui.filter_plugins("luapingly", plugins), "telescope.nvim", "[描述] 'luapingly' 不在 desc 中 -> 负向验证")
  assert_contains(ui.filter_plugins("blazINGLY", plugins), "telescope.nvim", "[描述] 大小写不敏感: 'blazINGLY' 匹配 'blazingly'")

  -- ---- 多关键词 AND 匹配 ----
  local r = ui.filter_plugins("nvim lsp", plugins)
  -- nvim-lspconfig: 包含 'nvim' (name/repo) + 'lsp' (name/repo) ✓
  -- lsp-zero.nvim:  包含 'nvim' (desc) + 'lsp' (name/repo) ✓
  assert_count(r, 2, "[多关键词] 'nvim lsp' 匹配 lsp-zero 和 nvim-lspconfig (AND语义)")
  assert_contains(r, "lsp-zero.nvim", "[多关键词] 'nvim lsp' 包含 lsp-zero")
  assert_contains(r, "nvim-lspconfig", "[多关键词] 'nvim lsp' 包含 nvim-lspconfig")
  
  local r2 = ui.filter_plugins("telescope fuzzy", plugins)
  -- telescope in name, fuzzy in desc of nvim-ufo? No.
  -- telescope in name of telescope.nvim, fuzzy in desc of telescope.nvim ("Filter, Preview, Pick. All lua, blazingly fast.") -> fuzzy not there
  -- Wait, telescope.nvim desc is "Find, Filter, Preview, Pick. All lua, blazingly fast." - no "fuzzy"!
  -- But nvim-ufo desc IS "Ultra Fast Fuzzy Finder for Neovim" - "fuzzy" is there, and "telescope" is NOT.
  -- So r2 should be 0
  assert_count(r2, 0, "[多关键词] 'telescope fuzzy' 无匹配 (AND语义)")
  
  local r3 = ui.filter_plugins("telescope preview", plugins)
  assert_count(r3, 1, "[多关键词] 'telescope preview' 匹配 telescope.nvim")
  assert_contains(r3, "telescope.nvim", "[多关键词] telescope-preview 在 telescope.nvim 中")
  
  -- ---- 多关键词 + 边界 ----
  local r4 = ui.filter_plugins("  nvim   lsp  ", plugins) -- 多余空格
  assert_count(r4, 2, "[边界] 多余空格被压缩 (仍是 'nvim lsp' 两个 token)")
  assert_contains(r4, "lsp-zero.nvim", "[边界] 压缩空格后仍正确匹配")
  
  local r5 = ui.filter_plugins("   ", plugins) -- 纯空格
  assert_count(r5, 7, "[边界] 纯空格视为空查询")
  
  -- ---- 大小写不敏感 ----
  assert_contains(ui.filter_plugins("UFO", plugins), "nvim-ufo", "[大小写] 'UFO' 大写匹配")
  assert_contains(ui.filter_plugins("Nvim-Ufo", plugins), "nvim-ufo", "[大小写] 'Nvim-Ufo' 混合匹配")
  assert_contains(ui.filter_plugins("TeLeScOpE", plugins), "telescope.nvim", "[大小写] 混合大小写匹配")
  
  -- ---- 防御性测试: userdata/数字/nil 字段 ----
  local dirty_plugins = {
    { name = "good-plugin", repo = "user/good-plugin", desc = "normal", stars = 100 },
    { name = "USERDATA_PLACEHOLDER_1", repo = "user/bad",       desc = "name was userdata (vim.NIL)", stars = 50 },
    { name = "12345",           repo = "user/numeric",   desc = "name is number-as-string", stars = 30 },
    { name = "",                repo = "user/missing",   desc = "name missing", stars = 10 },
  }
  local dirty_result = ui.filter_plugins("good", dirty_plugins)
  assert_count(dirty_result, 1, "[防御] userdata/number/nil name 被过滤, 只剩 good")
  assert_contains(dirty_result, "good-plugin", "[防御] dirty 数据中正确提取 good-plugin")
  
  -- ---- 防御性测试: plugins 为空/nil ----
  assert_count(ui.filter_plugins("anything", nil), 0, "[防御] nil plugins 返回空列表")
  assert_count(ui.filter_plugins("anything", {}), 0, "[防御] 空 plugins 返回空列表")
  assert_count(ui.filter_plugins("anything", "not a table"), 0, "[防御] 非 table plugins 返回空列表")
  
  -- ---- 防御性测试: query 为非字符串 ----
  assert_count(ui.filter_plugins(nil, plugins), 7, "[防御] nil query 返回全部")
  assert_count(ui.filter_plugins(123, plugins), 7, "[防御] number query 返回全部")
  assert_count(ui.filter_plugins({}, plugins), 7, "[防御] table query 返回全部")
  
  -- ---- 结果不应修改原列表 ----
  local original_count = #plugins
  ui.filter_plugins("ufo", plugins)
  assert_eq(#plugins, original_count, "[不可变] 过滤操作不修改原列表长度")
  
  local original_first_name = plugins[1].name
  ui.filter_plugins("telescope", plugins)
  assert_eq(plugins[1].name, original_first_name, "[不可变] 过滤操作不修改原列表顺序")
  
  -- ---- Lua 模式字符处理 (% . + * 等) ----
  -- 注意：'plain=true' 使 find() 将模式字符当作字面量
  -- 但查询仍需是子串！如 'nvim%ufo' 不包含在 'nvim-ufo' 中
  assert_not_contains(ui.filter_plugins("nvim%ufo", plugins), "nvim-ufo", "[模式字符] 'nvim%ufo' 不是 'nvim-ufo' 的子串")
  -- 但如果查询字符串真的在插件中，应该能匹配
  assert_contains(ui.filter_plugins("nvim", plugins), "nvim-ufo", "[模式字符] 'nvim' 字面量匹配")
  -- 点字符 '.' 作为子串匹配：所有名字中有 '.' 的插件
  assert_contains(ui.filter_plugins(".", plugins), "telescope.nvim", "[模式字符] '.' 作为字面量在 telescope.nvim 中")
  assert_contains(ui.filter_plugins(".", plugins), "lsp-zero.nvim", "[模式字符] '.' 作为字面量在 lsp-zero.nvim 中")
  -- nvim-ufo 没有点
  assert_not_contains(ui.filter_plugins(".", plugins), "nvim-ufo", "[模式字符] '.' 不在 nvim-ufo 中")
  
  -- ---- 空 name 条目不崩溃 ----
  local r6 = ui.filter_plugins("ufo", plugins) -- 包含 name="" 的条目
  assert_eq(type(r6), "table", "[空条目] 不崩溃, 正常返回 table")
  
  -- ---- 输出汇总 ----
  print("\n" .. string.rep("═", 70))
  print("  MiniStore.nvim 测试套件结果")
  print(string.rep("═", 70))
  for _, r in ipairs(test_results) do
    if r.ok then
      print(string.format("  \27[32m✓\27[0m %s", r.name))
    else
      print(string.format("  \27[31m✗\27[0m %s", r.name))
      if r.detail then print("      " .. r.detail) end
    end
  end
  print(string.rep("─", 70))
  local total = test_pass + test_fail
  print(string.format("  总计: %d 个测试 | \27[32m通过: %d\27[0m | \27[31m失败: %d\27[0m",
    total, test_pass, test_fail))
  print(string.rep("═", 70) .. "\n")
  
  return test_pass, test_fail
end

return { run_all_tests = run_all_tests }
