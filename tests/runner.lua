local harness = dofile("tests/wow_stubs.lua")
local tests, passed = {}, 0
local output = print
local function loadAddon(saved)
  harness.install()
  _G.RollTheBonesSlotsDB = saved
  local ns = {}
  for line in io.lines("RollTheBonesSlots.toc") do
    local path = line:match("^%s*(.-)%s*$")
    if path ~= "" and path:sub(1, 1) ~= "#" then
      assert(path:match("%.lua$"), "runner must support every TOC entry")
      assert(loadfile((path:gsub("\\", "/"))))("RollTheBonesSlots", ns)
    end
  end
  return ns
end
local function test(name, fn)
  tests[#tests + 1] = { name, fn }
end
local ns = loadAddon()
dofile("tests/config_spec.lua")(test, ns, harness)
dofile("tests/duration_bar_spec.lua")(test, harness, loadAddon)
dofile("tests/lifecycle_spec.lua")(test, harness, loadAddon)
dofile("tests/settings_spec.lua")(test, harness, loadAddon)
dofile("tests/presentation_spec.lua")(test, harness, loadAddon)
dofile("tests/highlight_spec.lua")(test, harness, loadAddon)
dofile("tests/eqol_dialog_spec.lua")(test, harness, loadAddon)
dofile("tests/native_results_spec.lua")(test, harness, loadAddon)
dofile("tests/win_effects_spec.lua")(test, harness, loadAddon)
dofile("tests/jackpot_spec.lua")(test, harness, loadAddon)
dofile("tests/variation_spec.lua")(test, harness, loadAddon)
dofile("tests/editmode_snap_spec.lua")(test, harness, loadAddon)
dofile("tests/editmode_keyboard_spec.lua")(test, harness, loadAddon)
for _, entry in ipairs(tests) do
  local success, failure = pcall(entry[2])
  if not success then
    error(entry[1] .. ": " .. tostring(failure), 0)
  end
  passed = passed + 1
  output("PASS " .. entry[1])
end
output(string.format("%d tests passed (off-client only)", passed))
