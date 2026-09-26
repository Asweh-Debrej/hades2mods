---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- Menu entry in the Hell2Modding overlay (INSERT key) + results window.
-- Both call functions from reload.lua, so they are hot-reloadable.
rom.gui.add_to_menu_bar(function() draw_menu() end)
rom.gui.add_imgui(function() draw_results() end)
