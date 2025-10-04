---@class GitlinkConfig
---@field remote? string Force a specific remote
---@field add_line_on_normal boolean Add current line in normal mode
---@field action fun(url: string) Action to perform with URL
---@field hosts table<string, fun(data: GitlinkUrlData): string> Host URL generators

local M = {}

---@type GitlinkConfig
local default_config = {
  remote = nil,
  add_line_on_normal = true,
  action = function(url)
    vim.fn.setreg("+", url)
    vim.notify(url, vim.log.levels.INFO)
  end,
  hosts = require("gitlink.hosts"),
}

---@type GitlinkConfig
local config = default_config

---Parse git remote URL
---@param remote_url string
---@return {host: string, port?: string, repo: string}?
local function parse_remote(remote_url)
  local host, repo, port

  -- SSH: git@github.com:user/repo.git
  ---@type string?, string?
  host, repo = remote_url:match("^git@([^:]+):(.+)$")
  if host and repo then
    repo = repo:gsub("%.git$", "")
    return { host = host, repo = repo }
  end

  -- HTTPS with port: https://github.com:3000/user/repo.git
  ---@type string?, string?, string?
  host, port, repo = remote_url:match("^https?://([^:]+):(%d+)/(.+)$")
  if host and port and repo then
    repo = repo:gsub("%.git$", "")
    return { host = host, port = port, repo = repo }
  end

  -- HTTPS: https://github.com/user/repo.git
  ---@type string?, string?
  host, repo = remote_url:match("^https?://([^/]+)/(.+)$")
  if host and repo then
    repo = repo:gsub("%.git$", "")
    return { host = host, repo = repo }
  end

  return nil
end

---Get git root directory
---@param bufnr number
---@return string?
local function get_git_root(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  return vim.fs.root(vim.fs.dirname(file), ".git")
end

---Get relative file path from git root
---@param file string
---@param git_root string
---@return string
local function get_relative_path(file, git_root)
  return file:sub(#git_root + 2)
end

---Generate URL for buffer range
---@param mode 'n'|'v'
---@param opts? GitlinkConfig
function M.get_buf_range_url(mode, opts)
  opts = vim.tbl_deep_extend("force", config, opts or {})

  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" then
    vim.notify("Buffer has no file", vim.log.levels.ERROR)
    return
  end

  local git_root = get_git_root(bufnr)
  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Capture line numbers immediately
  ---@type number, number?
  local lstart, lend
  if mode == "v" then
    local vstart = vim.fn.getpos("v")
    local vend = vim.fn.getpos(".")
    lstart = math.min(vstart[2], vend[2])
    lend = math.max(vstart[2], vend[2])
  elseif mode == "n" and opts.add_line_on_normal then
    lstart = vim.fn.line(".")
  end

  local rel_path = get_relative_path(file, git_root)

  -- Determine remote
  vim.system({ "git", "remote" }, { cwd = git_root, text = true }, function(remotes_result)
    vim.schedule(function()
      local remote = opts.remote
      if not remote and remotes_result.code == 0 then
        local remotes = vim.split(vim.trim(remotes_result.stdout), "\n", { trimempty = true })
        if #remotes == 1 then
          remote = remotes[1]
        elseif #remotes > 1 then
          vim.system({ "git", "rev-parse", "--abbrev-ref", "@{u}" }, { cwd = git_root, text = true }, function(up_res)
            vim.schedule(function()
              remote = up_res.code == 0 and vim.trim(up_res.stdout):match("^([^/]+)/") or "origin"
              M._build_url(git_root, remote, rel_path, lstart, lend, mode, opts)
            end)
          end)
          return
        end
      end
      M._build_url(git_root, remote or "origin", rel_path, lstart, lend, mode, opts)
    end)
  end)
end

---Validate file and generate URL
---@param git_root string
---@param remote string
---@param remote_data {host: string, port: string?, repo: string}
---@param rev string
---@param rel_path string
---@param lstart? number
---@param lend? number
---@param mode string
---@param opts GitlinkConfig
local function validate_and_generate(git_root, remote, remote_data, rev, rel_path, lstart, lend, mode, opts)
  vim.system({ "git", "cat-file", "-e", rev .. ":" .. rel_path }, { cwd = git_root }, function(cat_res)
    vim.schedule(function()
      if cat_res.code ~= 0 then
        vim.notify(string.format("'%s' not in remote '%s'", rel_path, remote), vim.log.levels.ERROR)
        return
      end

      vim.system({ "git", "diff", rev, "--", rel_path }, { cwd = git_root, text = true }, function(diff_res)
        vim.schedule(function()
          if diff_res.code == 0 and diff_res.stdout ~= "" and (mode == "v" or opts.add_line_on_normal) then
            vim.notify(
              string.format("'%s' has uncommitted changes - line numbers may be wrong", rel_path),
              vim.log.levels.WARN
            )
          end

          local url_data = {
            host = remote_data.host,
            port = remote_data.port,
            repo = remote_data.repo,
            rev = rev,
            file = rel_path,
            lstart = lstart,
            lend = lend,
          }

          local callback = nil
          for pattern, cb in pairs(opts.hosts) do
            if url_data.host:match(pattern) then
              callback = cb
              break
            end
          end

          if not callback then
            vim.notify("No URL generator for host: " .. url_data.host, vim.log.levels.ERROR)
            return
          end

          opts.action(callback(url_data))
        end)
      end)
    end)
  end)
end

---Check if commit is in remote
---@param git_root string
---@param remote string
---@param remote_data {host: string, port: string?, repo: string}
---@param rev string
---@param rel_path string
---@param lstart? number
---@param lend? number
---@param mode string
---@param opts GitlinkConfig
local function check_remote_and_validate(git_root, remote, remote_data, rev, rel_path, lstart, lend, mode, opts)
  vim.system({ "git", "branch", "-r", "--contains", rev }, { cwd = git_root, text = true }, function(branch_res)
    vim.schedule(function()
      local in_remote = false
      if branch_res.code == 0 then
        for line in branch_res.stdout:gmatch("[^\r\n]+") do
          if line:match(remote) then
            in_remote = true
            break
          end
        end
      end

      if not in_remote then
        vim.notify(string.format("Commit not in remote '%s' - push changes first", remote), vim.log.levels.WARN)
      end

      validate_and_generate(git_root, remote, remote_data, rev, rel_path, lstart, lend, mode, opts)
    end)
  end)
end

---Build permalink URL
---@param git_root string
---@param remote string
---@param rel_path string
---@param lstart? number
---@param lend? number
---@param mode string
---@param opts GitlinkConfig
function M._build_url(git_root, remote, rel_path, lstart, lend, mode, opts)
  vim.system({ "git", "remote", "get-url", remote }, { cwd = git_root, text = true }, function(url_res)
    vim.schedule(function()
      if url_res.code ~= 0 then
        vim.notify("No git remote found", vim.log.levels.ERROR)
        return
      end

      local remote_data = parse_remote(vim.trim(url_res.stdout))
      if not remote_data then
        vim.notify("Failed to parse remote URL", vim.log.levels.ERROR)
        return
      end

      vim.system({ "git", "rev-parse", "HEAD" }, { cwd = git_root, text = true }, function(head_res)
        vim.schedule(function()
          if head_res.code ~= 0 then
            vim.notify("Failed to get commit hash", vim.log.levels.ERROR)
            return
          end

          local rev = vim.trim(head_res.stdout)
          check_remote_and_validate(git_root, remote, remote_data, rev, rel_path, lstart, lend, mode, opts)
        end)
      end)
    end)
  end)
end

---Generate repository URL
---@param opts? GitlinkConfig
function M.get_repo_url(opts)
  opts = vim.tbl_deep_extend("force", config, opts or {})

  local bufnr = vim.api.nvim_get_current_buf()
  local git_root = get_git_root(bufnr)

  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  vim.system({ "git", "remote", "get-url", opts.remote or "origin" }, { cwd = git_root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("No git remote found", vim.log.levels.ERROR)
        return
      end

      local remote_data = parse_remote(vim.trim(result.stdout))
      if not remote_data then
        vim.notify("Failed to parse remote URL", vim.log.levels.ERROR)
        return
      end

      local url = remote_data.port
          and string.format("https://%s:%s/%s", remote_data.host, remote_data.port, remote_data.repo)
        or string.format("https://%s/%s", remote_data.host, remote_data.repo)

      opts.action(url)
    end)
  end)
end

---Setup gitlink
---@param user_config? GitlinkConfig
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})
end

return M
