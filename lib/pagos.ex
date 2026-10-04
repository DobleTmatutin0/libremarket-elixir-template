defmodule Libremarket.Pagos do

  def autorizar_pagos() do
    prob = :rand.uniform(100)

    if prob <= 70 do
      :pago_aprobado
    else
      :pago_rechazado
    end

  end

end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Pagos
  """

  use GenServer

  ########################################################
  # Constantes con los nombres de las colas de mensajes
  ########################################################

  @pagos_queue "pagos"
  @compras_queue "compras"

  ########################################################
  # API del cliente
  ########################################################

  @doc """
  Crea un nuevo servidor de Pagos
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def autorizar_pagos(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:autorizar_pagos, id_compra})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    Libremarket.Message.create_consumer(@pagos_queue)

    {:ok, state}
  end

  @doc """
  Callback para un call :autorizar_pagos
  """
  @impl true
  def handle_call({:autorizar_pagos, id_compra}, _from, state) do
    result = Libremarket.Pagos.autorizar_pagos()
    newState = Map.put(state, id_compra, result)
    {:reply, result, newState}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case :erlang.binary_to_term(payload) do
      {:autorizar_pagos, id_compra, request_id} ->
        result = Libremarket.Pagos.autorizar_pagos()
        new_state = Map.put(state, id_compra, result)

        Libremarket.Message.send_message(
          @compras_queue,
          {:pago_resultado, id_compra, request_id, result}
        )

        {:noreply, new_state}

      _mensaje ->
        {:noreply, state}
    end
  end

end
