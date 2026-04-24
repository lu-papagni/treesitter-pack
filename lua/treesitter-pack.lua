---@mod treesitter-pack.spec Spec definition

---@class TSPackSpec
---@field src string Repository address
---@field lang string|string[] Names of the parsers to install

---@class TSPackOpts
---@field force boolean Whether to perform a forced installation

local M = {}

local PARSER_DIR = vim.fs.joinpath(vim.fn.stdpath("data") .. "/site/parser")

---Prints a log message without breaking fast events
---@param msg string
---@param level keyof vim.log.levels
---@return void
local function log(msg, level)
  vim.schedule(function()
    vim.notify("[tree-sitter] " .. msg, vim.log.levels[level])
  end)
end

---Creates a temporary directory
---@return string
local function new_temp_dir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  return path
end

---Returns the absolute path that `parser_name` would have once installed
---@param parser_name string
---@return string
local function make_parser_abspath(parser_name)
  return vim.fs.joinpath(PARSER_DIR .. ("/%s.so"):format(parser_name))
end

---Compiles a parser from `source_dir`, placing the output
---in the `parser` runtimepath directory
---@param source_dir string Repository path
---@param parser_name string Name of the compiled parser
---@return void
local function build(source_dir, parser_name)
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

---Returns all raw parser names
---@param source string Where to look for parsers
---@return string[]
local function get_installed_binaries(source)
  local source_path = source or M.install_path

  return vim.fs.find(function(name, _)
    return name:match(".*%.so$")
  end, {
    path = source_path,
    type = "file",
    limit = math.huge,
  })
end

---Download a project and compile its parsers
---@param src string Repository address
---@param targets string[] Names of the languages to install
---@return vim.SystemObj
local function install(src, targets)
  assert(type(src) == "string", "Use a valid repository address.")
  assert(type(targets) == "table" and #targets > 0, "Specify the languages defined by this parser.")

  local dest = new_temp_dir()

  --- @param status vim.SystemCompleted
  --- @return vim.SystemObj?
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

  vim.fn.mkdir(PARSER_DIR, "p") -- Create parser directory if doesn't exist
  return vim.system({ "git", "clone", "--depth", "1", src, dest }, {}, on_exit)
end

---Returns parser name from its path
---@param path string Parser path
---@return string
local function get_parser_name(path)
  return (vim.fs.basename(path):gsub("%.so$", ""))
end

---@mod treesitter-pack.api API Overview

---Add parsers to Neovim
---@param spec TSPackSpec List of parsers marked for installation:
---* {src} The address is passed as-is to 'git'.
---  This allows to use a shorter source, like
---  in |vim.pack-examples|.
---
---* {lang} When more than one parser name
---  is given, the repo is expected to contain
---  one sub-directory for each name.
---  These will be considered the new build targets
---  instead of the repo root.
---@param opts? TSPackOpts Other installation settings
---@return void
---@see TSPackSpec
---@see TSPackOpts
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

---Retrieve installed parser names
---@return string[]
function M.get()
  local parsers = get_installed_binaries(PARSER_DIR)
  return vim.iter(parsers):map(get_parser_name):totable()
end

---Remove parsers from Neovim, deleting their binaries from runtimepath
---@param names string[] Parsers to erase
---@return void
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
