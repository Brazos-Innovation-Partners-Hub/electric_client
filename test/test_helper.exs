ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
# The stand-in Electric server the HTTP fetcher is proven against (ours, not upstream's).
Electric.Client.Test.FakeElectric.start!()
ExUnit.start()
