local neotest = require "neotest"

neotest.setup {
  adapters = {
    require("neotest-golang")(),
    require("neotest-python") {
      dap = { justMyCode = false },
      runner = "pytest",
    },
    require("neotest-rust")({}),
  },
}
