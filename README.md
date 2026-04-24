# treesitter-pack

Simple `tree-sitter` parser manager for Neovim, inspired from the native package manager `vim.pack`.

## Features

- Declarative
- Non-blocking parser installation
- Very lightweight

I developed this plugin with a minimalist approach: it does not aim to maintain queries
or a parser registry, but to be a thin abstraction over manually building a parser.

## Installation

With `lazy.nvim`:

```lua
return { "lu-papagni/treesitter-pack" }
```

With `vim.pack`:

```lua
vim.pack.add({ "https://github.com/lu-papagni/treesitter-pack" })
```

Then you can simply require it in your `init.lua`.

> [!IMPORTANT]
> You also need these dependencies in your `PATH`:
> - git
> - tree-sitter-cli

## Usage

> `:h treesitter-pack.api`

Like `vim.pack` you can:

- Install a parser with `add`
- Uninstall with `del`
- Get a list of installed parsers with `get`

## How it works

At startup the plugin reads the spec provided to the `add` function and
scans `runtimepath` for installed parsers.

Each missing parser repo is cloned in a separate temporary directory.

Then, it compiles one parser for each provided language via `tree-sitter-cli`
and places the resulting binaries into the `parser` directory in `runtimepath`.

## Examples

**Installing multiple parsers at once**

```lua
require("treesitter-pack").add({
    {
        src = "https://github.com/tree-sitter/tree-sitter-rust",
        lang = "rust"
    },
    {
        src = "https://github.com/tree-sitter/tree-sitter-c",
        -- You can omit the 'lang' attribute
        -- Its value will be inferred using the last word from the repo name
        -- lang = "c"
    },
})
```

**Updating a parser**

```lua
require("treesitter-pack").add({
    src = "https://github.com/tree-sitter/tree-sitter-rust",
    lang = "rust"
}, { force = true })
```

**Handling repos with more than one parser**

Some parser repositories like [tree-sitter-typescript](https://github.com/tree-sitter/tree-sitter-typescript)
define multiple parsers, in this case `typescript` and `tsx`.

> [!WARNING]
> In cases like this you **can't** omit `lang`.
> If you do, then the plugin will assume that the repository root is a valid
> build target.

You can install all of them (or a subset) by passing many `lang` values.

```lua
require("treesitter-pack").add({
    src = "https://github.com/tree-sitter/tree-sitter-typescript",
    lang = { "typescript", "tsx" }
})
```

