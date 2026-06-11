return {
  {
    "kndndrj/nvim-dbee",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    build = function()
      require("dbee").install()
    end,
    keys = {
      {
        "<leader>db",
        function()
          require("dbee").toggle()
        end,
        desc = "Toggle Dbee",
      },
    },
    config = function()
      require("dbee").setup()
    end,
  },
}
