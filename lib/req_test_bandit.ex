defmodule ReqTestBandit do
  @moduledoc """
  `Req.Test` plugin to use Bandit to serve HTTP test server, optionally using
  `X509` for HTTPS test server. This plugin augments Req.Test, it does not
  replace it. To use this plugin following the example provided in `Req.Test`'s
  moduledoc, `attach/1` needs to be called and `config/test.exs` needs to change:

      # config/test.exs
      config :myapp, weather_req_options: [
        bandit: true,
        plug: {Req.Test, MyApp.Weather},
        x509: true # optional, if you want to use HTTPS
      ]
  """

  require Logger

  @doc """
  Runs the plugin.

  ## Usage

      req =
        Req.new(bandit: true, plug: plug)
        |> ReqTestBandit.attach()
      Req.get!(req, url: "https://api.example.com/path")
      #=> %Req.Response{}
  """
  def attach(req) do
    req
    |> Req.Request.register_options([:bandit, :x509])
    |> Req.Request.prepend_request_steps(put_bandit: &put_bandit/1)
  end

  @doc false
  def listener(_event, _measurements, _metadata, callers) do
    Process.put(:"$callers", callers)
  end

  defp put_bandit(request) do
    if request.options[:bandit] and not is_nil(request.options[:plug]) do
      ref = make_ref()
      callers = Process.get(:"$callers", [])
      :telemetry.attach(ref, [:bandit, :request, :start], &__MODULE__.listener/4, callers)

      %{request | adapter: &run_bandit/1}
      |> Req.Request.delete_option(:plug)
      |> Req.Request.put_private(:bandit_plug, request.options[:plug])
      |> Req.Request.put_private(:telemetry_ref, ref)
    else
      request
    end
  end

  defp run_bandit(request)

  if Code.ensure_loaded?(Bandit) do
    defp run_bandit(request) do
      if Req.Request.get_option(request, :x509, false) do
        run_https(request)
      else
        run_http(request)
      end
    end
  else
    defp run_bandit(_request) do
      Logger.error("""
      Could not find bandit dependency.

      Please add :bandit to your dependencies:

          {:bandit, "~> 1.7"}
      """)

      raise "missing bandit dependency"
    end
  end

  defp run_http(request) do
    handler = Req.Request.get_private(request, :bandit_plug)
    {:ok, pid} = Bandit.start_link(plug: handler, port: 0, scheme: :http, startup_log: false)
    {:ok, {_, port}} = ThousandIsland.listener_info(pid)

    update_in(request.url, &%{&1 | host: "localhost", port: port, scheme: "http"})
    |> Req.Finch.run()
  end

  if Code.ensure_loaded?(X509) do
    defp run_https(request) do
      suite = X509.Test.Suite.new()
      handler = Req.Request.get_private(request, :bandit_plug)

      {:ok, pid} =
        Bandit.start_link(
          plug: handler,
          port: 0,
          scheme: :https,
          startup_log: false,
          thousand_island_options: [
            transport_options: [
              cacerts: suite.chain ++ suite.cacerts,
              cert: X509.Certificate.to_der(suite.valid),
              key: {:PrivateKeyInfo, X509.PrivateKey.to_der(suite.server_key, wrap: true)}
            ]
          ]
        )

      {:ok, {_, port}} = ThousandIsland.listener_info(pid)

      request = update_in(request.url, &%{&1 | host: "localhost", port: port, scheme: "https"})

      connect_options =
        request
        |> Req.Request.get_option(:connect_options, transport_opts: [])
        |> Keyword.update(
          :transport_opts,
          [cacerts: suite.cacerts],
          &Keyword.put(&1, :cacerts, suite.cacerts)
        )

      request = Req.Request.put_option(request, :connect_options, connect_options)

      Req.Finch.run(request)
    end
  else
    defp run_https(_request) do
      Logger.error("""
      Could not find bandit dependency.

      Please add :x509 to your dependencies:

          {:x509, "~> 0.9.2"}
      """)

      raise "missing bandit dependency"
    end
  end
end
