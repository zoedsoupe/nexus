local_without_parens = [
  defcommand: 2,
  subcommand: 2,
  value: 2,
  flag: 2,
  short: 1,
  description: 1
]

[
  import_deps: [:nimble_parsec],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [locals_without_parens: local_without_parens],
  locals_without_parens: local_without_parens,
  plugins: [Styler]
]
