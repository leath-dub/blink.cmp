local async = require('blink.cmp.sources.lib.async')
local uv = vim.uv
local fs = {}

--- Scans a directory asynchronously in a loop until
--- it finds all entries
--- @param path string
--- @return blink.cmp.Task
function fs.scan_dir_async(path)
  local max_entries = 200
  return async.task.new(function(resolve, reject)
    uv.fs_opendir(path, function(err, handle)
      if err ~= nil or handle == nil then return reject(err) end

      local all_entries = {}

      local function read_dir()
        uv.fs_readdir(handle, function(err, entries)
          if err ~= nil or entries == nil then return reject(err) end

          vim.list_extend(all_entries, entries)
          if #entries == max_entries then
            read_dir()
          else
            resolve(all_entries)
          end
        end)
      end
      read_dir()
    end, max_entries)
  end)
end

--- @param entries { name: string, type: string }[]
--- @return blink.cmp.Task
function fs.fs_stat_all(cwd, entries)
  local tasks = {}
  for _, entry in ipairs(entries) do
    table.insert(
      tasks,
      async.task.new(function(resolve, reject)
        uv.fs_stat(cwd .. '/' .. entry.name, function(err, stat)
          if err then return reject(err) end
          resolve({ name = entry.name, type = entry.type, stat = stat })
        end)
      end)
    )
  end
  return async.task.await_all(tasks):map(function(tasks_results)
    local resolved_entries = {}
    for _, entry in ipairs(tasks_results) do
      if entry.status == async.STATUS.COMPLETED then table.insert(resolved_entries, entry.result) end
    end
    return resolved_entries
  end)
end

return fs