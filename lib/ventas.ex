defmodule Libremarket.Ventas do

  def reservar_productos(productos) do
    if productos.stock > 0 do
      :productos_reservados
    else
      :out_of_stock
    end
  end

  def liberar_productos(productos) do
    :productos_liberados
  end

end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
    Ventas
  """

  use GenServer

  ##########################
  # API del cliente
  ##########################

  @doc """
    Crea un nuevo servidor de Ventas
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  def reservar_productos(pid \\ __MODULE__, id_producto) do
    GenServer.call(pid, {:reservar_productos, id_producto})
  end

  def liberar_productos(pid \\ __MODULE__, id_producto) do
    GenServer.call(pid, {:liberar_productos, id_producto})
  end

  ##########################
  # CALLBACKS
  ##########################

  @doc """
    Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {
      :ok,
      %{
        productos: %{
          1 => %{nombre: "Notebook", stock: 10},
          2 => %{nombre: "Mouse", stock: 20},
          3 => %{nombre: "Keyboard", stock: 15}
        }
      }
    }
  end

  @doc """
    Callback para un call :listar_productos
  """
  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

  @doc """
    Callback para un call :reservar_productos
  """
  @impl true
  def handle_call({:reservar_productos, id_producto}, _from, state) do
    producto = Map.get(state.productos, id_producto)

    if producto do
      result = Libremarket.Ventas.reservar_productos(producto)

      if result == :productos_reservados do
        producto_actualizado =
          Map.update(producto, :stock, 0, fn stock -> stock - 1 end)

        productos_actualizados =
          Map.put(state.productos, id_producto, producto_actualizado)

        new_state = %{state | productos: productos_actualizados}

        {:reply, {:ok, result}, new_state}
      else
        {:reply, {:error, result}, state}
      end
    else
      {:reply, {:error, :el_producto_no_existe}, state}
    end
  end

  @doc """
    Callback para un call :liberar_producto
  """
  @impl true
  def handle_call({:liberar_productos, id_producto}, _from, state) do
    producto = Map.get(state.productos, id_producto)

    if producto do
      producto_actualizado = Map.update(producto, :stock, 0, fn stock -> stock + 1 end)
      productos_actualizados = Map.put(state.productos, id_producto, producto_actualizado)
      new_state = %{state | productos: productos_actualizados}

      {:reply, {:ok, :productos_liberados}, new_state}
    else
      {:reply, {:error, :el_producto_no_existe}, state}
    end
  end

end
