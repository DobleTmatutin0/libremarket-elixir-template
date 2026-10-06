defmodule Libremarket.Message do

  use AMQP

  @servers [:compras, :ventas, :infracciones, :pagos, :envios]

  def initial_clock do
    Map.new(@servers, &{&1, 0})
  end

  def create_consumer(queue_name) do
    # Obtiene el canal AMQP (definico en el archivo de configuracion)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    # Configura el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    {:ok, channel}
  end

  def send_message(queue_name, message, sender, clock) do
    # Obtener el canal AMQP (definido en la configuración)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    new_clock = tick(clock, sender)
    mensaje_serializado = :erlang.term_to_binary({:libremarket_message, message, new_clock})
    # Publicar el mensaje
    Basic.publish(channel, "", queue_name, mensaje_serializado)

    IO.puts("Mensaje enviado: #{inspect(message)}")
    new_clock
  end

  def receive_message(payload, receiver, local_clock) do
    case :erlang.binary_to_term(payload) do
      {:libremarket_message, message, received_clock} when is_map(received_clock) ->
        merged_clock =
          @servers
          |> Enum.map(fn server ->
            {server, max(Map.get(local_clock, server, 0), Map.get(received_clock, server, 0))}
          end)
          |> Map.new()

        {:ok, message, tick(merged_clock, receiver)}

      _message ->
        {:error, :invalid_message}
    end
  end

  defp tick(clock, server) do
    Map.update(clock, server, 1, &(&1 + 1))
  end

end
