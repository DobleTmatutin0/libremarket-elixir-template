defmodule Libremarket.Ventas do

  def reservar_productos(productos) when is_list(productos) do
    Enum.reduce_while(productos, {:ok, []}, fn id_producto, {:ok, acc} ->
      case Libremarket.Ventas.Server.reservar_productos(id_producto) do
        {:ok, :productos_reservados} -> {:cont, {:ok, acc ++ [id_producto]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  def reservar_productos(productos) do
    if productos.stock > 0 do
      :productos_reservados
    else
      :out_of_stock
    end
  end

  def procesar_reserva(productos, state) when is_list(productos) do
    resultado =
      Enum.reduce_while(productos, {:ok, state}, fn id_producto, {:ok, estado_acumulado} ->
        case Map.get(estado_acumulado.productos, id_producto) do
          %{stock: stock} = producto when stock > 0 ->
            producto_actualizado = Map.put(producto, :stock, stock - 1)
            productos_actualizados = Map.put(estado_acumulado.productos, id_producto, producto_actualizado)
            {:cont, {:ok, %{estado_acumulado | productos: productos_actualizados}}}

          nil ->
            {:halt, {{:error, :el_producto_no_existe}, state}}

          _producto ->
            {:halt, {{:error, :out_of_stock}, state}}
        end
      end)

    case resultado do
      {:ok, nuevo_estado} -> {{:ok, :productos_reservados}, nuevo_estado}
      {{:error, _motivo} = error, _estado_parcial} -> {error, state}
    end
  end

  def liberar_productos(productos) when is_list(productos) do
    Enum.each(productos, fn id_producto ->
      Libremarket.Ventas.Server.liberar_productos(id_producto)
    end)

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

  ########################################################
  # Constantes con los nombres de las colas de mensajes
  ########################################################

  @ventas_queue "ventas"

  ########################################################
  # Constantes con los nombres de las colas de mensajes
  ########################################################

  @ventas_queue "ventas"

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

  @doc """
    Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    Libremarket.Message.create_consumer(@ventas_queue)

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

    {:ok, %{productos: productos, reloj: Libremarket.Message.initial_clock()}}
  end

  @doc """
    Callback para un call :listar_productos
  """
  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

  @impl true
  def handle_call({:reservar_productos, productos}, _from, state) when is_list(productos) do
    {resultado, nuevo_estado} = Libremarket.Ventas.procesar_reserva(productos, state)

    {:reply, resultado, nuevo_estado}
  end

  @impl true
  def handle_call({:liberar_productos, productos}, _from, state) when is_list(productos) do
    nuevo_estado = incrementar_stock(productos, state)
    {:reply, {:ok, :productos_liberados}, nuevo_estado}
  end

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

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case Libremarket.Message.receive_message(payload, :ventas, state.reloj) do
      {:ok, {:reservar_productos, id_compra, productos}, reloj} ->
        state = %{state | reloj: reloj}
        {resultado, nuevo_estado} = Libremarket.Ventas.procesar_reserva(productos, state)
        reloj = Libremarket.Message.send_message(
          "compras",
          {:reserva_resultado, id_compra, resultado},
          :ventas,
          nuevo_estado.reloj
        )
        nuevo_estado = %{nuevo_estado | reloj: reloj}
        {:noreply, nuevo_estado}

      {:ok, {:liberar_productos, productos}, reloj} ->
        state = %{state | reloj: reloj}
        {:noreply, incrementar_stock(productos, state)}

      {:ok, _mensaje, reloj} ->
        {:noreply, %{state | reloj: reloj}}

      {:error, :invalid_message} ->
        {:noreply, state}
    end
  end

  defp incrementar_stock(productos, state) do
    Enum.reduce(List.wrap(productos), state, fn id_producto, acc_state ->
      case Map.get(acc_state.productos, id_producto) do
        nil ->
          acc_state

        producto ->
          producto_actualizado = Map.update!(producto, :stock, &(&1 + 1))
          productos_actualizados = Map.put(acc_state.productos, id_producto, producto_actualizado)
          %{acc_state | productos: productos_actualizados}
      end
    end)
  end

end
