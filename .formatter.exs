# Used by "mix format"
#
# The design and the worked examples (`Electric.Client.Design`, `Electric.Client.Examples`) are
# written in vstack_shared's DSLs without parentheses: their words come from vstack_shared's
# export, and the words of the examples' world are listed here.
example_words = [proved: 1, shape: 1]

[
  plugins: [Spark.Formatter],
  import_deps: [:vstack_shared],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: example_words
]
