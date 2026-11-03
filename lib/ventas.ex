defmodule Libremarket.Ventas do

  # Verifica si un producto tiene stock disponible.
  def reservar_productos(%{stock: stock}) when stock > 0 do
    :productos_reservados
  end

  def reservar_productos(%{stock: _stock}) do
    :out_of_stock
  end

  # Reserva una lista de productos.
  def reservar_productos(productos) when is_list(productos) do
    Libremarket.Ventas.Server.reservar_productos(productos)
  end

  # Libera una lista de productos.
  def liberar_productos(productos) when is_list(productos) do
    Libremarket.Ventas.Server.liberar_productos(productos)
    :productos_liberados
  end

  def liberar_productos(_productos) do
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

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  def reservar_productos(pid \\ __MODULE__, productos)

  def reservar_productos(pid, productos) when is_list(productos) do
    GenServer.call(pid, {:reservar_productos, productos})
  end

  def reservar_productos(pid, id_producto) do
    GenServer.call(pid, {:reservar_productos, [id_producto]})
  end

  def liberar_productos(pid \\ __MODULE__, productos)

  def liberar_productos(pid, productos) when is_list(productos) do
    GenServer.call(pid, {:liberar_productos, productos})
  end

  def liberar_productos(pid, id_producto) do
    GenServer.call(pid, {:liberar_productos, [id_producto]})
  end


  ##########################
  # CALLBACKS
  ##########################

  @impl true
  def init(_state) do
    productos = %{
      1 => %{nombre: "Notebook", stock: :rand.uniform(10)},
      2 => %{nombre: "Mouse", stock: :rand.uniform(10)},
      3 => %{nombre: "Keyboard", stock: :rand.uniform(10)},
      4 => %{nombre: "Monitor", stock: :rand.uniform(10)},
      5 => %{nombre: "Auriculares", stock: :rand.uniform(10)},
      6 => %{nombre: "Webcam", stock: :rand.uniform(10)},
      7 => %{nombre: "Parlante", stock: :rand.uniform(10)},
      8 => %{nombre: "Microfono", stock: :rand.uniform(10)},
      9 => %{nombre: "Tablet", stock: :rand.uniform(10)},
      10 => %{nombre: "Impresora", stock: :rand.uniform(10)}
    }

    {:ok, %{productos: productos}}
  end


  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end


  # Reserva todos los productos o no reserva ninguno.
  @impl true
  def handle_call({:reservar_productos, productos}, _from, state) do

    resultado =
      Enum.reduce_while(productos, {:ok, state.productos}, fn id_producto, {:ok, productos_actuales} ->

        case Map.get(productos_actuales, id_producto) do

          nil ->
            {:halt, {:error, :el_producto_no_existe}}

          producto ->
            case Libremarket.Ventas.reservar_productos(producto) do

              :productos_reservados ->
                producto_actualizado =
                  Map.update!(producto, :stock, fn stock -> stock - 1 end)

                nuevos_productos =
                  Map.put(productos_actuales, id_producto, producto_actualizado)

                {:cont, {:ok, nuevos_productos}}

              :out_of_stock ->
                {:halt, {:error, :out_of_stock}}

            end
        end
      end)

    case resultado do

      {:ok, productos_actualizados} ->
        nuevo_estado = %{state | productos: productos_actualizados}

        {:reply, {:ok, :productos_reservados}, nuevo_estado}

      {:error, reason} ->
        {:reply, {:error, reason}, state}

    end
  end


  # Libera el stock de todos los productos indicados.
  @impl true
  def handle_call({:liberar_productos, productos}, _from, state) do

    productos_actualizados =
      Enum.reduce(productos, state.productos, fn id_producto, acc_productos ->

        case Map.get(acc_productos, id_producto) do

          nil ->
            acc_productos

          producto ->
            producto_actualizado =
              Map.update!(producto, :stock, fn stock -> stock + 1 end)

            Map.put(acc_productos, id_producto, producto_actualizado)

        end
      end)

    nuevo_estado = %{state | productos: productos_actualizados}

    {:reply, {:ok, :productos_liberados}, nuevo_estado}
  end

end
