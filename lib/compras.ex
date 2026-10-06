defmodule Libremarket.Compras do

  def confirmar_compra(id_compra) do
    Libremarket.Compras.Server.confirmar_compra(id_compra)
  end

  def selec_producto(id_producto) do
    GenServer.cast(Libremarket.Compras.Server, {:publicar, "ventas", {:reservar_productos, nil, [id_producto]}})
  end

  def detectar_infraccion(id_compra, productos \\ []) do
    GenServer.cast(
      Libremarket.Compras.Server,
      {:publicar, "infracciones", {:detectar_infraccion, id_compra, productos}}
    )
  end

  def selec_forma_entrega(forma_de_envio) do
    if forma_de_envio == :correo do
      Libremarket.Envios.calcular_costo()
    else
      :retiro_en_tienda
    end
  end


end

defmodule Libremarket.Compras.Server do
  @moduledoc """
    Compras
  """

  use GenServer

  ########################################################
  # Constantes con los nombres de las colas de mensajes
  ########################################################

  @compras_queue "compras"
  @infracciones_queue "infracciones"
  @ventas_queue "ventas"
  @envios_queue "envios"
  @pagos_queue "pagos"

  ##########################
  # API del cliente
  ##########################

  @doc """
    Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
    representa todo el proceso de la compra, seleccionar el producto, tipo de envio, etc
  """
  def comprar(pid \\ __MODULE__, productos, forma_de_envio, medio_de_pago) do
    GenServer.call(pid, {:comprar, productos, forma_de_envio, medio_de_pago}, :infinity)
  end

  @doc """
    boton de confirmacion para autorizar el pago
  """
  def confirmar_compra(pid \\ __MODULE__, id_compra) do
    GenServer.call(pid, {:confirmar_compra, id_compra}, :infinity)
  end

  ##########################
  # Callbacks
  ##########################

  @doc """
    Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    Libremarket.Message.create_consumer(@compras_queue);

    {
      :ok,
      %{proximo_id_compra: 0, compras: %{}, pendientes: %{}, confirmaciones: %{}, reloj: Libremarket.Message.initial_clock()}
    }
  end

  @doc """
  Solicita la autorización de pago mediante la cola de Pagos.
  """
  @impl true
  def handle_call({:confirmar_compra, id_compra}, from, state) do
    request_id = :erlang.unique_integer([:positive, :monotonic])
    reloj = Libremarket.Message.send_message(
      @pagos_queue,
      {:autorizar_pagos, id_compra, {:confirmacion, request_id}},
      :compras,
      state.reloj
    )
    confirmaciones = Map.put(state.confirmaciones, request_id, from)
    {:noreply, %{state | confirmaciones: confirmaciones, reloj: reloj}}
  end

  @impl true
  def handle_call({:comprar, productos, forma_entrega, medio_de_pago}, from, state) do
    id_compra = state.proximo_id_compra + 1
    forma = Libremarket.Compras.selec_forma_entrega(forma_entrega)
    pendiente = %{
      from: from,
      productos: productos,
      forma_entrega: forma,
      forma_original: forma_entrega,
      medio_de_pago: medio_de_pago
    }

    reloj = Libremarket.Message.send_message(
      @ventas_queue,
      {:reservar_productos, id_compra, productos},
      :compras,
      state.reloj
    )

    nuevo_estado = %{state |
      proximo_id_compra: id_compra,
      pendientes: Map.put(state.pendientes, id_compra, pendiente),
      reloj: reloj
    }

    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_cast({:publicar, queue, message}, state) do
    {:noreply, publicar(state, queue, message)}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case Libremarket.Message.receive_message(payload, :compras, state.reloj) do
      {:ok, mensaje, reloj} ->
        state = %{state | reloj: reloj}

        case mensaje do
          {:reserva_resultado, id_compra, resultado} ->
            procesar_resultado_reserva(id_compra, resultado, state)

          {:infraccion_resultado, id_compra, resultado} ->
            procesar_resultado_infraccion(id_compra, resultado, state)

          {:pago_resultado, id_compra, request_id, resultado} ->
            procesar_resultado_pago(id_compra, request_id, resultado, state)

          _mensaje ->
            {:noreply, state}
        end

      {:error, :invalid_message} ->
        {:noreply, state}
    end
  end

  defp procesar_resultado_reserva(id_compra, {:ok, :productos_reservados}, state) do
    case Map.fetch(state.pendientes, id_compra) do
      {:ok, pendiente} ->
        state = publicar(
          state,
          @infracciones_queue,
          {:detectar_infraccion, id_compra, pendiente.productos}
        )

        pendiente = Map.put(pendiente, :estado_del_producto, {:ok, :productos_reservados})
        pendientes = Map.put(state.pendientes, id_compra, pendiente)
        {:noreply, %{state | pendientes: pendientes}}

      :error ->
        {:noreply, state}
    end
  end

  defp procesar_resultado_reserva(id_compra, _resultado, state) do
    case Map.pop(state.pendientes, id_compra) do
      {nil, _pendientes} ->
        {:noreply, state}

      {pendiente, pendientes} ->
        GenServer.reply(pendiente.from, :out_of_stock)
        {:noreply, %{state | pendientes: pendientes}}
    end
  end

  defp procesar_resultado_infraccion(id_compra, resultado, state) do
    case Map.fetch(state.pendientes, id_compra) do
      {:ok, pendiente} when resultado == :infraccion_detectada ->
        GenServer.reply(pendiente.from, :infraccion_detectada)
        {:noreply, %{state | pendientes: Map.delete(state.pendientes, id_compra)}}

      {:ok, pendiente} ->
        compra = %{
          id_compra: id_compra,
          productos: pendiente.productos,
          estado_del_producto: pendiente.estado_del_producto,
          forma_de_entrega: pendiente.forma_entrega,
          medio_de_pago: pendiente.medio_de_pago,
          infraccion: resultado
        }

        pendiente = Map.put(pendiente, :compra, compra)
        pendientes = Map.put(state.pendientes, id_compra, pendiente)

        state = publicar(
          state,
          @pagos_queue,
          {:autorizar_pagos, id_compra, {:compra, id_compra}}
        )

        {:noreply, %{state | pendientes: pendientes}}

      :error ->
        {:noreply, state}
    end
  end

  defp procesar_resultado_pago(id_compra, {:compra, id_compra}, resultado, state) do
    case Map.pop(state.pendientes, id_compra) do
      {nil, _pendientes} ->
        {:noreply, state}

      {pendiente, pendientes} ->
        compra = pendiente.compra
        compras = Map.put(state.compras, id_compra, compra)

        state = if resultado == :pago_aprobado do
          state = if pendiente.forma_original == :correo do
            publicar(state, @envios_queue, {:agendar_envio, id_compra})
          else
            state
          end

          GenServer.reply(pendiente.from, compra)
          state
        else
          state = publicar(state, @ventas_queue, {:liberar_productos, pendiente.productos})
          GenServer.reply(pendiente.from, :compra_rechazada)
          state
        end

        {:noreply, %{state | compras: compras, pendientes: pendientes}}
    end
  end

  defp procesar_resultado_pago(_id_compra, {:confirmacion, request_id}, resultado, state) do
    case Map.pop(state.confirmaciones, request_id) do
      {nil, _confirmaciones} ->
        {:noreply, state}

      {from, confirmaciones} ->
        GenServer.reply(from, resultado)
        {:noreply, %{state | confirmaciones: confirmaciones}}
    end
  end

  defp procesar_resultado_pago(_id_compra, _request_id, _resultado, state) do
    {:noreply, state}
  end

  defp publicar(state, queue, message) do
    reloj = Libremarket.Message.send_message(queue, message, :compras, state.reloj)
    %{state | reloj: reloj}
  end

end
