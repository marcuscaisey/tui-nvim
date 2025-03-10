local M = {}

local defaults = {
  temp = "/tmp/tui-nvim",
  method = "edit",
  mappings = {},
  on_open = {},
  on_exit = {},
  border = "rounded",
  borderhl = "Normal",
  winhl = "Normal",
  winblend = 0,
  height = 0.8,
  width = 0.8,
  y = 0.5,
  x = 0.5,
}

local function dimensions(opts)
  local status_height = 0
	if
		(vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
		or vim.o.laststatus == 2
		or vim.o.laststatus == 3
	then
		status_height = 1
	end
  local tabline_height = 0
  if
    (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
    or vim.o.showtabline == 2
  then
    tabline_height = 1
  end

  local cl = vim.o.columns
  local ln = vim.o.lines - vim.o.cmdheight - status_height - tabline_height

  local width = math.ceil(cl * opts.width)
  local height = math.ceil(ln * opts.height)

  local col = math.ceil((cl - width) * opts.x)
  local row = tabline_height + math.ceil((ln - height) * opts.y)

  return {
    width = width,
    height = height,
    col = col,
    row = row,
  }
end

function M.setup(user_opts)
  defaults = vim.tbl_deep_extend("force", defaults, user_opts)
end

local function resize(opts)
  local dim = dimensions(opts)
  vim.api.nvim_win_set_config(M.win, {
    style = "minimal",
    relative = "editor",
    border = opts.border,
    height = dim.height,
    width = dim.width,
    col = dim.col,
    row = dim.row,
  })
end

function M:new(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts)
  local dim = dimensions(opts)

  function M.VimResized()
    resize(opts)
  end

  local function on_exit()
    vim.api.nvim_win_close(M.win, true)
    vim.api.nvim_buf_delete(M.buf, { force = true })
    vim.cmd([[augroup TuiNvim
      autocmd! VimResized
    augroup END]])

    for _, func in ipairs(opts.on_exit) do
      func()
    end

    if not io.open(opts.temp, "r") then
      return
    end

    for line in io.lines(opts.temp) do
      vim.cmd(opts.method .. " " .. vim.fn.fnameescape(line))
    end

    os.remove(opts.temp)
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    style = "minimal",
    relative = "editor",
    border = opts.border,
    height = dim.height,
    width = dim.width,
    col = dim.col,
    row = dim.row,
  })

  vim.api.nvim_win_set_option(M.win, "winhl", ("Normal:%s,FloatBorder:%s"):format(opts.winhl, opts.borderhl))
  vim.api.nvim_win_set_option(M.win, "winblend", opts.winblend)

  vim.api.nvim_buf_set_option(M.buf, "filetype", "TUI")

  for _, keymap in ipairs(opts.mappings) do
    vim.api.nvim_buf_set_keymap(M.buf, "t", keymap[1], keymap[2], { silent = true })
  end

  for _, func in ipairs(opts.on_open) do
    func()
  end

  vim.fn.termopen(opts.cmd, { on_exit = on_exit })

  vim.cmd("startinsert")
  vim.cmd([[augroup TuiNvim
    autocmd! VimResized * lua require('tui-nvim').VimResized()
  augroup END]])
end

return M
