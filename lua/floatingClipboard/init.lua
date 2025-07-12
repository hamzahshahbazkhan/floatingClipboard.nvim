local M = {}

local function expand_path(path)
	if path:sub(1, 1) == "~" then
		return os.getenv("HOME") .. path:sub(2)
	end
	return path
end

local function windows_config()
	local width = math.min(math.floor(vim.o.columns * 0.8), 64)
	local height = math.floor(vim.o.lines * 0.8)
	return {
		height = height,
		width = width,
		relative = "editor",
		col = 64,
		row = (vim.o.lines - height) / 2,
		border = "rounded",
		title = " Clipboard ",
		title_pos = "center",
	}
end

local function prevent_changes(buf)
	vim.api.nvim_create_autocmd("InsertEnter", {
		buffer = buf,
		callback = function()
			vim.api.nvim_input("<Esc>")
			vim.notify("Insert mode disabled", vim.log.levels.INFO)
		end,
	})

	for _, key in ipairs({ "i", "a", "o", "O", "s", "S", "d", "D", "y", "Y", "P" }) do
		vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
			callback = function()
				vim.notify("Editing disabled", vim.log.levels.WARN)
			end,
			noremap = true,
			silent = true,
		})
	end
end

local function copy_and_paste()
	local flo_buf = vim.api.nvim_get_current_buf()
	local flo_win = vim.api.nvim_get_current_win()
	local flo_cursor = vim.api.nvim_win_get_cursor(0)[1]
	local all_lines = vim.api.nvim_buf_get_lines(flo_buf, 0, -1, false)
	local top_idx, bottom_idx = 1, #all_lines

	for i = flo_cursor, 1, -1 do
		if all_lines[i]:match("^%_+$") then
			top_idx = i
			break
		end
	end

	for i = flo_cursor, #all_lines do
		if all_lines[i]:match("^%_+$") then
			bottom_idx = i
			break
		end
	end

	local pasted_lines = {}

	if top_idx and bottom_idx and top_idx < bottom_idx then
		if top_idx > 1 then
			top_idx = top_idx + 1
		end
		if all_lines[bottom_idx]:match("^%_+$") then
			bottom_idx = bottom_idx - 1
		end
		for i = top_idx, bottom_idx do
			table.insert(pasted_lines, all_lines[i])
		end
	else
		vim.notify("Could not find the clipboard data", vim.log.levels.WARN)
		return
	end

	vim.api.nvim_win_close(flo_win, false)
	vim.api.nvim_buf_delete(flo_buf, { force = true })

	local main_buf = vim.api.nvim_get_current_buf()
	local main_cursor = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(main_buf, main_cursor, main_cursor, false, pasted_lines)
end

local function open_floating_window(target_file)
	local expanded_path = expand_path(target_file)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, windows_config())

	local file = io.open(expanded_path, "r")
	if file then
		local content = {}
		for line in file:lines() do
			table.insert(content, line)
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
		file:close()
	end

	prevent_changes(buf)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"

	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		callback = function()
			copy_and_paste()
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "p", "", {
		callback = function()
			copy_and_paste()
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", {})
end

local function save_yank_in_file(target_file, lines)
	local expanded_path = expand_path(target_file)
	-- local fd, err = vim.loop.fs_open(expanded_path, "a", 438)
	-- if not fd then
	-- 	vim.notify("Failed to open clipboard file: " .. err, vim.log.levels.ERROR)
	-- 	return
	-- end
	-- local content = table.concat(lines, "\n") .. "\n"
	-- vim.loop.fs_write(fd, content)
	-- vim.loop.fs_close(fd)
	local f_read = io.open(expanded_path, "r")
	local existing_lines = {}
	if f_read then
		for line in f_read:lines() do
			table.insert(existing_lines, line)
		end
		f_read:close()
	end

	local f_write = io.open(expanded_path, "w")
	if not f_write then
		vim.notify("Failed to open the clipboard file while writing", vim.log.levels.ERROR)
		return
	end
	for _, line in ipairs(lines) do
		f_write:write(line .. "\n")
	end
	for _, line in ipairs(existing_lines) do
		f_write:write(line .. "\n")
	end
	f_write:close()
end

local function trim_clipboard_file(path, max_lines)
	local f = io.open(path, "r")
	if not f then
		return
	end
	local lines = {}
	for line in f:lines() do
		table.insert(lines, line)
	end
	f:close()
	if #lines > max_lines then
		local f_out = io.open(path, "w")
		for i = #lines - max_lines + 1, #lines do
			f_out:write(lines[i] .. "\n")
		end
		f_out:close()
	end
end

local function listen_for_yank(target_file, hist_size)
	vim.api.nvim_create_autocmd("TextYankPost", {
		callback = function()
			local yanked_text = vim.fn.getreg('"')
			local lines = vim.split(yanked_text, "\n")
			table.insert(lines, "________________________________________________________________")
			table.insert(lines, "                                                                ")
			save_yank_in_file(target_file, lines)
			trim_clipboard_file(target_file, hist_size)
		end,
	})
end

local function setup_user_commands(opts)
	local target_file = opts.target_file or "clipboard.txt"
	local hist_size = opts.hist_size or 2000
	listen_for_yank(target_file, hist_size)
	vim.api.nvim_create_user_command("Cl", function()
		open_floating_window(target_file)
	end, {})
end

M.setup = function(opts)
	setup_user_commands(opts)
end

return M
