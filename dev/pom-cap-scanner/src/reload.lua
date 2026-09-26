---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- Pom cap scanner: for every god boon and rarity, finds the level at which Pom of Power stops
-- offering it. Mirrors the vanilla check in GetAllUpgradeableGodTraits (TraitLogic.lua): a boon is
-- only offered if its ExtractData (the values shown in its tooltip) changes at the next level.
-- Boons are processed from TraitData, so installed mods (e.g. Limitless Poms) are reflected.

-- Hell2Modding exposes ImGui under `rom`, not as a global visible from an ENVY plugin environment
ImGui = rom.ImGui
ImGuiTableFlags = rom.ImGuiTableFlags

RARITIES = { 'Common', 'Rare', 'Epic', 'Heroic' }
COLUMNS = { 'God', 'Boon', 'Trait', 'Common', 'Rare', 'Epic', 'Heroic', 'Verdict' }

scan_state = scan_state or { status = 'Not scanned yet. Load a save, then scan.', rows = nil, show = false, only_capped = false }

local function load_display_names()
	local names = {}
	local path = rom.path.combine(rom.paths.Content(), 'Game/Text/en/TraitText.en.sjson')
	local ok, data = pcall(sjson.decode_file, path)
	if ok and data and data.Texts then
		for _, entry in ipairs(data.Texts) do
			if entry.Id and entry.DisplayName then names[entry.Id] = entry.DisplayName end
		end
	end
	return names
end

local function processed_trait(traitName, rarity, stackNum)
	local data = game.DeepCopyTable(game.TraitData[traitName])
	local rarityData = rarity and data.RarityLevels and data.RarityLevels[rarity]
	if rarityData then
		-- fixed multiplier instead of a random roll, so scanning does not consume the run's RNG
		data.RarityMultiplier = rarityData.Multiplier or rarityData.MinMultiplier
		data.Rarity = rarity
	end
	local hero = game.CurrentRun.Hero
	local trait = game.GetProcessedTraitData({ Unit = hero, TraitName = traitName, TraitData = data, StackNum = stackNum, ForceMin = true })
	game.ExtractValues(hero, trait, trait)
	return trait
end

local function values_change(current, nextLevel)
	local a, b = current.ExtractData, nextLevel.ExtractData
	if a == nil or b == nil then return false end
	for key, value in pairs(b) do
		if a[key] ~= value then return true end
	end
	return false
end

-- Level at which Pom of Power stops offering the boon, or nil if it still scales at maxLevel
local function find_cap(traitName, rarity, maxLevel)
	local current = processed_trait(traitName, rarity, 1)
	for level = 1, maxLevel do
		local nextLevel = processed_trait(traitName, rarity, level + 1)
		if not values_change(current, nextLevel) then return level end
		current = nextLevel
	end
	return nil
end

local function find_clamp(node, visited)
	if visited[node] then return nil end
	visited[node] = true
	if node.MinimumSourceValue ~= nil then return 'min clamp' end
	if node.MaximumValue ~= nil then return 'max clamp' end
	for _, value in pairs(node) do
		if type(value) == 'table' then
			local found = find_clamp(value, visited)
			if found then return found end
		end
	end
	return nil
end

local function god_boons()
	local list, seen = {}, {}
	for _, source in ipairs({ game.LootData, game.FieldLootData }) do
		for lootName, loot in pairs(source) do
			if loot.GodLoot and not loot.DebugOnly and loot.TraitIndex then
				for traitName in pairs(loot.TraitIndex) do
					if not seen[traitName] and game.TraitData[traitName] then
						seen[traitName] = true
						table.insert(list, { god = lootName, trait = traitName })
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.god ~= b.god then return a.god < b.god end
		return a.trait < b.trait
	end)
	return list
end

local function scan_boon(entry, names, maxLevel)
	local data = game.TraitData[entry.trait]
	local row = { god = entry.god, trait = entry.trait, name = names[entry.trait] or '', caps = {} }
	if data.BlockStacking then
		row.verdict = 'never (BlockStacking)'
		row.capped = true
		return row
	end

	local rarities = RARITIES
	if data.RarityLevels == nil then rarities = { 'Common' } end
	local anyCap, scales = false, false
	for _, rarity in ipairs(rarities) do
		if data.RarityLevels == nil or data.RarityLevels[rarity] then
			local ok, cap = pcall(find_cap, entry.trait, data.RarityLevels and rarity or nil, maxLevel)
			if not ok then
				row.caps[rarity] = 'error'
				row.error = tostring(cap)
			elseif cap == nil then
				row.caps[rarity] = '-'
				scales = true
			else
				row.caps[rarity] = tostring(cap)
				anyCap = true
				if cap > 1 then scales = true end
			end
		end
	end

	if row.error then
		row.verdict = 'error: ' .. row.error
	elseif not anyCap then
		row.verdict = 'unlimited'
	elseif not scales then
		row.verdict = 'never (nothing scales)'
	else
		row.verdict = 'capped (' .. (find_clamp(data, {}) or 'values stop changing') .. ')'
	end
	row.capped = row.verdict ~= 'unlimited'
	return row
end

local function scan_all(names)
	local rows = {}
	for _, entry in ipairs(god_boons()) do
		table.insert(rows, scan_boon(entry, names, config.max_level))
	end
	return rows
end

-- Marks what Limitless Poms changed compared to vanilla. A violation is a boon (or rarity) that
-- vanilla never lets you upgrade (cap 1, nothing scales, BlockStacking) but that becomes
-- upgradeable with the mod; Limitless Poms must never cause one.
local function compare(rows, vanillaRows)
	local changed, violations = 0, 0
	for i, row in ipairs(rows) do
		local vanilla = vanillaRows[i]
		for _, rarity in ipairs(RARITIES) do
			local before, after = vanilla.caps[rarity], row.caps[rarity]
			if before ~= after then
				row.changed = true
				row.caps[rarity] = tostring(before) .. ' > ' .. tostring(after)
				if before == '1' then row.violation = true end
			end
		end
		if vanilla.verdict:find('^never') and not row.verdict:find('^never') then row.violation = true end
		if row.violation then
			row.verdict = '!! NOW UPGRADEABLE (vanilla: ' .. vanilla.verdict .. ')'
			violations = violations + 1
		end
		if row.changed then changed = changed + 1 end
	end
	return changed, violations
end

local function row_cells(row)
	local c = row.caps
	return { row.god, row.name, row.trait, c.Common or '', c.Rare or '', c.Epic or '', c.Heroic or '', row.verdict }
end

local function write_report(rows, maxLevel, summary)
	local dir = _PLUGIN.plugins_data_mod_folder_path
	rom.path.create_directory(dir)
	local path = rom.path.combine(dir, 'pom-caps.md')
	local lines = {
		'# Pom of Power caps',
		'',
		'Level at which Pom of Power stops offering each god boon. "-" = still scaling at level ' .. maxLevel .. '.',
		'"a > b" = vanilla cap a, cap b with Limitless Poms.',
		'Generated ' .. os.date('%Y-%m-%d %H:%M') .. '. ' .. summary,
		'',
		'| ' .. table.concat(COLUMNS, ' | ') .. ' |',
		'|' .. string.rep(' --- |', #COLUMNS),
	}
	for _, row in ipairs(rows) do
		local cells = row_cells(row)
		cells[3] = '`' .. cells[3] .. '`'
		table.insert(lines, '| ' .. table.concat(cells, ' | ') .. ' |')
	end
	local file = assert(io.open(path, 'w'))
	file:write(table.concat(lines, '\n'), '\n')
	file:close()
	return path
end

function run_scan()
	if game.CurrentRun == nil or game.CurrentRun.Hero == nil then
		scan_state.status = 'No hero yet: load a save (hub or run), then scan again.'
		return
	end
	local names = load_display_names()
	local rows = scan_all(names)
	local summary = 'Limitless Poms not installed: vanilla comparison skipped.'
	local core = rom.mods['AswehDebrej-Limitless_Poms']
	if core and core.run_vanilla then
		local changed, violations = compare(rows, core.run_vanilla(scan_all, names))
		summary = 'Vs vanilla: ' .. changed .. ' boons changed by Limitless Poms; ' .. violations
			.. ' non-upgradeable boons made upgradeable' .. (violations > 0 and ' -- BUG, please report!' or ' (OK).')
	end
	local path = write_report(rows, config.max_level, summary)
	local capped = 0
	for _, row in ipairs(rows) do
		if row.capped then capped = capped + 1 end
	end
	scan_state.rows = rows
	scan_state.show = true
	scan_state.status = #rows .. ' boons scanned, ' .. capped .. ' capped. ' .. summary .. ' Report: ' .. path
	rom.log.info(_PLUGIN.guid .. ': ' .. scan_state.status)
end

function draw_menu()
	if ImGui.BeginMenu('Pom Cap Scanner') then
		if ImGui.MenuItem('Scan all god boons') then run_scan() end
		if scan_state.rows and ImGui.MenuItem('Show results') then scan_state.show = true end
		ImGui.Separator()
		ImGui.Text(scan_state.status)
		ImGui.EndMenu()
	end
end

function draw_results()
	if not scan_state.show or scan_state.rows == nil then return end
	local open, shouldDraw = ImGui.Begin('Pom caps', true)
	scan_state.show = open
	if shouldDraw then
		ImGui.TextWrapped(scan_state.status)
		scan_state.only_capped = ImGui.Checkbox('Only capped boons', scan_state.only_capped)
		ImGui.SameLine()
		scan_state.only_changed = ImGui.Checkbox('Only boons changed by Limitless Poms', scan_state.only_changed)
		if ImGui.BeginTable('pom_caps', #COLUMNS, ImGuiTableFlags.Borders) then
			for _, header in ipairs(COLUMNS) do
				ImGui.TableSetupColumn(header)
			end
			ImGui.TableHeadersRow()
			for _, row in ipairs(scan_state.rows) do
				local visible = (row.capped or not scan_state.only_capped)
					and (row.changed or row.violation or not scan_state.only_changed)
				if visible then
					ImGui.TableNextRow()
					for column, text in ipairs(row_cells(row)) do
						ImGui.TableSetColumnIndex(column - 1)
						ImGui.Text(text)
					end
				end
			end
			ImGui.EndTable()
		end
	end
	ImGui.End()
end
