# gitlink.nvim

A modern, minimal Neovim plugin to generate shareable git permalinks with line ranges.

## Features

- Generate permalinks for files with line ranges
- Support for GitHub, GitLab, Gitea, Codeberg, BitBucket, and cgit
- Zero dependencies
- Easy to extend with custom hosts

## Requirements

- Neovim 0.11+
- Git

## Installation

### lazy.nvim

```lua
{
  "amaanq/gitlink.nvim",
  event = "VeryLazy",
  opts = {},
}
```

## Configuration

```lua
require("gitlink").setup({
  -- Force a specific remote (default is nil, which auto-detects)
  remote = nil,

  -- Add current line in normal mode (default is true)
  add_line_on_normal = true,

  -- Action to perform with URL (default copies to clipboard)
  action = function(url)
    vim.fn.setreg("+", url)
  end,

  hosts = {
    ["github%.com"] = require("gitlink.hosts").github,
    ["gitlab%.com"] = require("gitlink.hosts").gitlab,
    -- Add custom hosts here
  },
})
```

### Custom Keymaps

```lua
-- Copy git link
vim.keymap.set({ "n", "v" }, "<leader>gy", function()
  require("gitlink").get_buf_range_url("n")
end, { desc = "Copy Git Link" })

-- Open git link
vim.keymap.set("n", "<leader>gB", function()
  require("gitlink").get_buf_range_url("n", { action = vim.ui.open })
end, { desc = "Open Git Link" })

-- or with lazy.nvim
{
  "amaanq/gitlink.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>gy",
      function()
        require("gitlink").get_buf_range_url("n")
      end,
      desc = "Copy Git Link",
    },
    {
      "<leader>gY",
      function()
        require("gitlink").get_buf_range_url("n", { action = vim.ui.open })
      end,
      desc = "Open Git Link",
    },
  },
  opts = {},
},
```

### Custom Hosts

```lua
require("gitlink").setup({
  hosts = {
    -- Enterprise GitHub
    ["github%.company%.com"] = require("gitlink.hosts").github,

    -- Custom host with custom URL format
    ["git%.mycompany%.com"] = function(data)
      return string.format(
        "https://%s/projects/%s/blob/%s/%s#L%d",
        data.host,
        data.repo,
        data.rev,
        data.file,
        data.lstart or 1
      )
    end,
  },
})
```

## API

### `get_buf_range_url(mode, opts?)`

Generate URL for current buffer with optional line range.

- `mode`: `'n'` (normal) or `'v'` (visual)
- `opts`: Optional config override (same as `setup` options)

### `get_repo_url(opts?)`

Generate repository URL.

- `opts`: Optional config override (same as `setup` options)

## Supported Hosts

- GitHub (github.com)
- GitLab (gitlab.com)
- Gitea/Forgejo (codeberg.org)
- BitBucket (bitbucket.org)
- cgit (git.kernel.org, git.savannah.gnu.org)

## License

MPL
