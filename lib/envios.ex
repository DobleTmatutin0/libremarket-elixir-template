defmodule Libremarket.Envios do

  def calcular_costo() do
    {:costo_calculado, 120}
  end

  def agendar_envio() do
    Date.add(Date.utc_today(), 5)
  end

end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Envios
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Envios
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def calcular_costo(pid \\ __MODULE__) do
    GenServer.call(pid, :calcular_costo)
  end

  def agendar_envio(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:agendar_envio, id_compra})
  end

  def listar_envios(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_envios)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    {:ok, %{envios: %{}}}
  end

  @doc """
  Callback para un call :calcular_costo
  """
  @impl true
  def handle_call(:calcular_costo, _from, state) do
    result = Libremarket.Envios.calcular_costo()
    {:reply, result, state}
  end

  @impl true
  def handle_call({:agendar_envio, id_compra}, _from, state) do
    result = Libremarket.Envios.agendar_envio()
    envios_nuevos = Map.put(state.envios, id_compra, result)
    nuevo_estado = %{state | envios: envios_nuevos}
    {:reply, result, nuevo_estado}
  end

  @impl true
  def handle_call(:listar_envios, _from, state) do
    {:reply, state.envios, state}
  end

end
