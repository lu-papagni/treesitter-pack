local M = {}

M.install_dir = vim.fs.joinpath(vim.fn.stdpath("data") .. "/site/parser")
vim.fn.mkdir(M.install_dir, "p")

local function log(msg, level)
  vim.schedule(function()
    vim.notify("[tree-sitter] " .. msg, vim.log.levels[level])
  end)
end

local function new_temp_dir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  return path
end

local function make_parser_abspath(parser_name)
  return vim.fs.joinpath(M.install_dir .. ("/%s.so"):format(parser_name))
end

--- Compile using tree-sitter
local function build(source_dir, parser_name)
  assert(parser_name, "Specify a language for all installed parsers.")

  local parser_path = make_parser_abspath(parser_name)
  local on_exit = function(status)
    if status.code ~= 0 then
      log("Error during build: " .. status.stderr, "WARN")
    else
      log("Parser " .. parser_name .. " installed.", "INFO")
    end
  end
  vim.system({ "tree-sitter", "build", "--output", parser_path }, { cwd = vim.fs.normalize(source_dir) }, on_exit)
end

local function get_installed_binaries(source)
  local source_path = source or M.install_path

  return vim.fs.find(function(name, path)
    return name:match(".*%.so$")
  end, {
    path = source_path,
    type = "file",
    limit = math.huge,
  })
end

--- Download and compile a parser
local function install(src, targets)
  assert(type(src) == "string", "Use a valid repository address.")
  assert(type(targets) == "table" and #targets > 0, "Specify the languages defined by this parser.")

  local dest = new_temp_dir()
  local on_exit = function(status)
    local repo_name = src:match("^.*%/(.+)$")

    if status.code ~= 0 then
      log("Failed to download " .. repo_name, "WARN")
      return
    end

    log("Checked out " .. repo_name, "INFO")

    if #targets == 1 then
      local dialect_path = vim.fs.joinpath(dest .. "/" .. targets[1])
      if not vim.uv.fs_stat(dialect_path) then
        build(dest, targets[1])
        return
      end
    end
    -- More than one target language means that there are multiple parsers
    -- to compile for a single repo
    for _, lang in ipairs(targets) do
      local path = vim.fs.joinpath(dest .. "/" .. lang)
      build(path, lang)
    end
  end

  return vim.system({ "git", "clone", "--depth", "1", src, dest }, {}, on_exit)
end

local function get_parser_name(path)
  return (vim.fs.basename(path):gsub("%.so$", ""))
end

function M.add(spec, opts)
  assert(type(spec) == "table", "Must specify a table as spec.")
  assert(not opts or type(opts) == "table", "Must specify a table as opts.")

  local opts = opts or {}
  local parsers = {}
  vim.list_extend(parsers, spec)

  for _, parser in ipairs(parsers) do
    local targets = vim
      .iter({ parser.lang })
      :flatten()
      :filter(function(l)
        local path = make_parser_abspath(l)
        return opts.force or not vim.uv.fs_stat(path)
      end)
      :totable()

    if #targets > 0 then
      install(parser.src, targets)
    end
  end
end

function M.get()
  local parsers = get_installed_binaries(M.install_dir)
  return vim.iter(parsers):map(get_parser_name):totable()
end

function M.del(names)
  for _, name in ipairs(names) do
    local path = make_parser_abspath(name)
    if vim.uv.fs_stat(path) then
      vim.fs.rm(path)
      log("Removed " .. name, "INFO")
    end
  end
end

return M
