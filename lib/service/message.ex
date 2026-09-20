defmodule Libremarket.Message do

  use AMQP

  def create_consumer(queue_name) do
    # Obtiene el canal AMQP (definico en el archivo de configuracion)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    # Configura el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    {:ok, channel}
  end

  def send_message(queue_name, message) do
    # Obtener el canal AMQP (definido en la configuración)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    mensaje_serializado = :erlang.term_to_binary(message)
    # Publicar el mensaje
    Basic.publish(channel, "", queue_name, mensaje_serializado)

    IO.puts("Mensaje enviado: #{inspect(message)}")
  end

  def rpc(queue_name, payload) do
    {:ok, channel} = AMQP.Application.get_channel(:channel)
    corr = :erlang.unique_integer() |> to_string()
    {:ok, %{queue: reply_q}} = Queue.declare(channel, "", exclusive: true)
    Basic.consume(channel, reply_q, nil, no_ack: true)
    Queue.declare(channel, queue_name, durable: true)
    Basic.publish(channel, "", queue_name, :erlang.term_to_binary({payload, corr}),
      reply_to: reply_q, correlation_id: corr, persistent: true)
    receive do
      {:basic_deliver, resp, %{correlation_id: ^corr}} -> :erlang.binary_to_term(resp)
    after 5000 -> {:error, :timeout}
    end
  end


end
