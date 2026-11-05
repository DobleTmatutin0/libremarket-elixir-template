
defmodule Libremarket.Router do
  use Plug.Router

  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  # GET /productos
  get "/productos" do
    try do
      productos =
        Libremarket.Ventas.Server.listar_productos()
        |> Enum.sort_by(fn {id, _producto} -> id end)
        |> Enum.map(fn {id, producto} ->
          %{
            id: id,
            nombre: producto.nombre,
            stock: producto.stock
          }
        end)

      responder(conn, 200, %{productos: productos})
    catch
      :exit, _motivo ->
        responder(conn, 503, %{error: "No se pudo consultar el catálogo"})
    end
  end

  # POST /comprar
  post "/comprar" do
    parametros = conn.body_params

    with {:ok, productos} <- validar_productos(parametros["productos"]),
         {:ok, forma_entrega} <- validar_entrega(parametros["forma_de_entrega"]),
         {:ok, medio_pago} <- validar_pago(parametros["medio_de_pago"]) do

      try do
        resultado =
          Libremarket.Compras.Server.comprar(
            productos,
            forma_entrega,
            medio_pago
          )

        responder(conn, 200, serializar(resultado))
      catch
        :exit, _motivo ->
          responder(conn, 503, %{
            error: "No se pudo procesar la compra en este nodo. La base de datos puede estar en modo solo lectura."
          })
      end
    else
      {:error, mensaje} ->
        responder(conn, 400, %{error: mensaje})
    end
  end

  # Rutas inexistentes
  match _ do
    responder(conn, 404, %{error: "Ruta no encontrada"})
  end

  # Validaciones de los datos recibidos

  defp validar_productos(productos) when is_list(productos) do
    if productos != [] and
         Enum.all?(productos, fn id ->
           is_integer(id) and id > 0
         end) do
      {:ok, productos}
    else
      {:error, "Los productos deben ser una lista de IDs positivos"}
    end
  end

  defp validar_productos(_),
    do: {:error, "Debe indicar los productos"}

  defp validar_entrega("correo"), do: {:ok, :correo}
  defp validar_entrega("retira"), do: {:ok, :retira}
  defp validar_entrega(_), do: {:error, "Forma de entrega inválida"}

  defp validar_pago("efectivo"), do: {:ok, :efectivo}
  defp validar_pago("transferencia"), do: {:ok, :transferencia}
  defp validar_pago("tarjeta"), do: {:ok, :tarjeta}
  defp validar_pago(_), do: {:error, "Medio de pago inválido"}

  # Conversión de estructuras Elixir a valores compatibles con JSON

  defp serializar(valor) when is_atom(valor),
    do: Atom.to_string(valor)

  defp serializar(valor) when is_tuple(valor) do
    valor
    |> Tuple.to_list()
    |> Enum.map(&serializar/1)
  end

  defp serializar(valor) when is_map(valor) do
    Map.new(valor, fn {clave, contenido} ->
      {to_string(clave), serializar(contenido)}
    end)
  end

  defp serializar(valor) when is_list(valor),
    do: Enum.map(valor, &serializar/1)

  defp serializar(valor),
    do: valor

  # Respuesta HTTP en formato JSON

  defp responder(conn, estado, contenido) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(estado, Jason.encode!(contenido))
  end
end
