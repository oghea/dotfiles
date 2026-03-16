return {
  {
    "ahmedkhalf/project.nvim",
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
    opts = {
      manual_mode = true,
      detection_methods = { "pattern" },
      patterns = { ".git", "package.json", "tsconfig.json", "Makefile" },
      datapath = vim.fn.stdpath("data"),
    },
    keys = {
      {
        "<leader>fp",
        function()
          require("snacks").picker.projects()
        end,
        desc = "Recent projects",
      },
      {
        "<leader>fP",
        function()
          local repo_dir = vim.fn.expand("~/Documents/repo")
          local dirs = vim.fn.systemlist("fd . " .. repo_dir .. " --type d --max-depth 1 --no-ignore --hidden --exclude .claude")
          local items = {}
          for i, dir in ipairs(dirs) do
            local name = vim.fn.fnamemodify(dir:gsub("/$", ""), ":t")
            if name ~= "" then
              table.insert(items, { idx = i, text = name, file = dir:gsub("/$", "") })
            end
          end
          require("snacks").picker({
            title = "All Projects",
            items = items,
            format = function(item)
              return { { item.text } }
            end,
            confirm = function(picker, item)
              picker:close()
              if item then
                vim.cmd("cd " .. item.file)
                require("snacks").picker.files()
              end
            end,
          })
        end,
        desc = "All projects",
      },
    },
  },
}