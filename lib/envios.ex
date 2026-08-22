defmodule Libremarket.Envios do

  def calcular_costo() do
    :calcular_costo
  end

  def agendar_envio() do
    :agendar_envio
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

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :calcular_costo
  """
  @impl true
  def handle_call(:calcular_costo, _from, state) do
    result = Libremarket.Envios.calcular_costo
    {:reply, result, state}
  end

  @impl true
  def handle_call(:agendar_envio, _from, state) do
    result = Libremarket.Envios.agendar_envio
    {:reply, result, state}
  end

end
