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

end
