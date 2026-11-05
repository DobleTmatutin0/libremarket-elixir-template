
defmodule Libremarket.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Libremarket.Repo,
      {Libremarket.Ventas.Server, %{}},
      {Libremarket.Pagos.Server, %{}},
      {Libremarket.Compras.Server, %{}},
      {Libremarket.Envios.Server, %{}},
      {Libremarket.Infracciones.Server, %{}},
      {Bandit, plug: Libremarket.Router, port: 4000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
