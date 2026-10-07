import Config

if Mix.env() == :test do
  config :junit_formatter,
    report_file: "test-junit-report.xml",
    automatic_create_dir?: true,
    report_dir: "./junit"

  config :plug, :statuses, %{
    530 => "CF unable to resolve origin hostname",
    599 => "Some random error"
  }
end

config :electric,
  start_in_library_mode: true

# The design and the worked examples are formatted as the DSLs they are written in.
config :spark, :formatter,
  remove_parens?: true,
  "VStack.Library": [type: VStack.Library.Declare, extensions: [VStack.Effects]],
  "VStack.Examples": [type: VStack.Examples.Declare]
