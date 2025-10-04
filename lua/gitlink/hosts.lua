---@class GitlinkUrlData
---@field host string
---@field port? string
---@field repo string
---@field rev string
---@field file string
---@field lstart? number
---@field lend? number

---@class GitlinkHosts: { [string]: fun(data: GitlinkUrlData): string }
local M = {}

---@param data GitlinkUrlData
---@return string
local function base_url(data)
  if data.port then
    return string.format("https://%s:%s/", data.host, data.port)
  end
  return string.format("https://%s/", data.host)
end

---@param data GitlinkUrlData
---@return string
function M.github(data)
  local url = base_url(data) .. data.repo
  if not data.file or not data.rev then
    return url
  end
  url = url .. "/blob/" .. data.rev .. "/" .. data.file
  if data.lstart then
    url = url .. "#L" .. data.lstart
    if data.lend and data.lend ~= data.lstart then
      url = url .. "-L" .. data.lend
    end
  end
  return url
end

---@param data GitlinkUrlData
---@return string
function M.gitlab(data)
  local url = base_url(data) .. data.repo
  if not data.file or not data.rev then
    return url
  end
  url = url .. "/-/blob/" .. data.rev .. "/" .. data.file
  if data.lstart then
    url = url .. "#L" .. data.lstart
    if data.lend and data.lend ~= data.lstart then
      url = url .. "-" .. data.lend
    end
  end
  return url
end

---@param data GitlinkUrlData
---@return string
function M.gitea(data)
  local url = base_url(data) .. data.repo
  if not data.file or not data.rev then
    return url
  end
  url = url .. "/src/commit/" .. data.rev .. "/" .. data.file
  if data.lstart then
    url = url .. "#L" .. data.lstart
    if data.lend and data.lend ~= data.lstart then
      url = url .. "-L" .. data.lend
    end
  end
  return url
end

---@param data GitlinkUrlData
---@return string
function M.bitbucket(data)
  local url = base_url(data) .. data.repo
  if not data.file or not data.rev then
    return url
  end
  url = url .. "/src/" .. data.rev .. "/" .. data.file
  if data.lstart then
    url = url .. "#lines-" .. data.lstart
    if data.lend and data.lend ~= data.lstart then
      url = url .. ":" .. data.lend
    end
  end
  return url
end

---@param data GitlinkUrlData
---@return string
function M.cgit(data)
  local repo = data.repo
  if not repo:match("%.git$") then
    repo = repo .. ".git"
  end
  local url = base_url(data) .. repo .. "/"
  if not data.file or not data.rev then
    return url
  end
  url = url .. "tree/" .. data.file .. "?id=" .. data.rev
  if data.lstart then
    url = url .. "#n" .. data.lstart
  end
  return url
end

return {
  ["github%.com"] = M.github,
  ["gitlab%.com"] = M.gitlab,
  ["codeberg%.org"] = M.gitea,
  ["try%.gitea%.io"] = M.gitea,
  ["bitbucket%.org"] = M.bitbucket,
  ["git%.kernel%.org"] = M.cgit,
  ["git%.savannah%.gnu%.org"] = M.cgit,
}
