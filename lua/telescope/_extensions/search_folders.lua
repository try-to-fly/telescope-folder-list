local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local scandir = require("plenary.scandir")
local Path = require("plenary.path")

local function is_gitignored(path)
	local gitignore_check = vim.fn.systemlist("git check-ignore " .. path)
	return #gitignore_check > 0
end

local function get_all_folders(root, current_path, folders, exclude)
	scandir.scan_dir(current_path, {
		hidden = false,
		add_dirs = true,
		depth = 1,
		on_insert = function(entry, typ)
			local relative_path = entry:sub(#root + 2)
			if typ == "directory" and not entry:match(exclude) and not is_gitignored(entry) then
				if relative_path ~= "" then
					table.insert(folders, "./" .. relative_path)
					get_all_folders(root, entry, folders, exclude)
				end
			end
		end,
	})
end

local function oil_command(dir)
	vim.cmd("Oil " .. dir)
end

local function preview_folder()
	return function(entry)
		local path = Path:new(entry.value)
		if path:exists() and path:is_dir() then
			local result = {}
			for _, item in ipairs(path:readdir()) do
				table.insert(result, item)
			end
			if #result == 0 then
				return "empty"
			else
				return table.concat(result, "\n")
			end
		else
			return "Path does not exist or is not a directory"
		end
	end
end

local function modified_entry_maker(entry)
	return {
		value = entry,
		display = entry,
		ordinal = entry,
		preview_command = preview_folder(),
	}
end

local function search_folders(opts)
	opts = opts or {}
	local cwd = vim.fn.getcwd()
	local folders = { "./" }

	get_all_folders(cwd, cwd, folders, "node_modules")

	pickers
		.new(opts, {
			prompt_title = "Search Folders",
			finder = finders.new_table({
				results = folders,
				entry_maker = modified_entry_maker,
			}),
			previewer = conf.file_previewer(opts),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					oil_command(selection.value)
				end)
				return true
			end,
		})
		:find()
end

return require("telescope").register_extension({
	exports = {
		search_folders = search_folders,
	},
})
