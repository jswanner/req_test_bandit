defmodule ReqTestBandit.MixProject do
  use Mix.Project

  @source_url "https://github.com/jswanner/req_test_bandit"
  @version "0.1.0"

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false, warn_if_outdated: true},
      {:req, "~> 0.5.0"},
      {:x509, "~> 0.9.0", optional: true}
    ]
  end

  def project do
    [
      app: :req_test_bandit,
      deps: deps(),
      docs: [
        source_url: @source_url,
        source_ref: "v#{@version}",
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ],
      elixir: "~> 1.14",
      package: [
        description: "Req.Test plugin to use Bandit to serve Plug test handler",
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source_url
        }
      ],
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ],
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end
end
