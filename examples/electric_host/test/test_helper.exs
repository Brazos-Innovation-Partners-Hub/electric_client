# Electric reads the database through its own connection: the suite starts once it serves.
:ok = Electric.StatusMonitor.wait_until_active("single_stack", timeout: 120_000)
ExUnit.start()
