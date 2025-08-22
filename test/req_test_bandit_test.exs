defmodule ReqTestBanditTest do
  use ExUnit.Case

  def listener(_, _, _, {name, ref}) do
    send(name, :started)
    :telemetry.detach(ref)
  end

  setup %{test: name} do
    Process.register(self(), name)
    ref = make_ref()
    :telemetry.attach(ref, [:bandit, :request, :start], &__MODULE__.listener/4, {name, ref})
    plug = fn conn, _opts -> Plug.Conn.send_resp(conn, :ok, to_string(conn.scheme)) end

    {:ok, plug: plug}
  end

  test "uses Bandit to serve plug handler", %{plug: plug} do
    assert %{body: "http"} = Req.get!(bandit: true, plug: plug, plugins: [ReqTestBandit])

    assert_receive :started
  end

  test "uses X509 for https", %{plug: plug} do
    assert %{body: "https"} =
             Req.get!(bandit: true, plug: plug, plugins: [ReqTestBandit], x509: true)

    assert_receive :started
  end
end
