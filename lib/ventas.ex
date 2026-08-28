defmodule Libremarket.Ventas do

  def reservar_productos() do
    :productos_reservados
  end

end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
  Ventas
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Ventas
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  def reservar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :reservar_productos)
  end


  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {
      :ok,
      %{
        productos: [
          %{id: 1, nombre: "Notebook"},
          %{id: 2, nombre: "Mouse"},
          %{id: 3, nombre: "Keyboard"},
        ]
      }
    }
  end

  @doc """
  Callback para un call :reservar_productos
  """
  @impl true
  def handle_call(:reservar_productos, _from, state) do
    result = Libremarket.Ventas.reservar_productos
    {:reply, result, state}
  end

  @doc """
    Callback para un call :listar_productos
  """
  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

end
