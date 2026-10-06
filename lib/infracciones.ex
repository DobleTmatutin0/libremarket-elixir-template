defmodule Libremarket.Infracciones do

  def detectar_infraccion() do
    prob = :rand.uniform(100)

    if prob <=30 do
      :infraccion_detectada
    else
      :no_infraccion
    end
  end

end

defmodule Libremarket.Infracciones.Server do
  @moduledoc """
    Infracciones
  """

  use GenServer

  ########################################################
  # Constantes con los nombres de las colas de mensajes
  ########################################################

  @infracciones_queue "infracciones"
  @compras_queue "compras"
  @ventas_queue "ventas"

  ########################################################
  # API del cliente
  ########################################################

  @doc """
  Crea un nuevo servidor de Infracciones
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def detectar_infraccion(id_compra, productos, pid \\ __MODULE__) do
    GenServer.call(pid, {:detectar_infraccion, id_compra, productos})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_infracciones)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    Libremarket.Message.create_consumer(@infracciones_queue)

    {:ok, Map.put(state, :reloj, Libremarket.Message.initial_clock())}
  end

  @doc """
  Callback para un call :detectar_infraccion
  """
  @impl true
  def handle_call({:detectar_infraccion, id_compra, productos}, _from, state) do
    result = Libremarket.Infracciones.detectar_infraccion()

    state = if result == :infraccion_detectada and productos != [] do
      publicar(state, @ventas_queue, {:liberar_productos, productos})
    else
      state
    end

    new_state = Map.put(state, id_compra, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:listar_infracciones, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case Libremarket.Message.receive_message(payload, :infracciones, state.reloj) do
      {:ok, {:detectar_infraccion, id_compra, productos}, reloj} ->
        state = %{state | reloj: reloj}
        result = Libremarket.Infracciones.detectar_infraccion()

        state = if result == :infraccion_detectada and productos != [] do
          publicar(state, @ventas_queue, {:liberar_productos, productos})
        else
          state
        end

        new_state = Map.put(state, id_compra, result)
        new_state = publicar(new_state, @compras_queue, {:infraccion_resultado, id_compra, result})
        {:noreply, new_state}

      {:ok, _mensaje, reloj} ->
        {:noreply, %{state | reloj: reloj}}

      {:error, :invalid_message} ->
        {:noreply, state}
    end
  end

  defp publicar(state, queue, message) do
    reloj = Libremarket.Message.send_message(queue, message, :infracciones, state.reloj)
    %{state | reloj: reloj}
  end


end
