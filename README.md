# ReqTestBandit

`Req.Test` plugin to use Bandit to serve HTTP test server, optionally using
`X509` for HTTPS test server. This plugin augments Req.Test, it does not
replace it. To use this plugin following the example provided in `Req.Test`'s
moduledoc, `attach/1` needs to be called and `config/test.exs` needs to change:

```elixir
# config/test.exs
config :myapp, weather_req_options: [
  bandit: true,
  plug: {Req.Test, MyApp.Weather},
  x509: true # optional, if you want to use HTTPS
]
```
