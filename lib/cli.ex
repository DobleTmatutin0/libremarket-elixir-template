
defmodule Libremarket.CLI do

  def iniciar do
    menu()
  end

  # Menú principal
  defp menu do
    IO.puts("\n========== LIBRE MARKET ==========")
    IO.puts("1. Ver productos")
    IO.puts("2. Realizar compra")
    IO.puts("3. Salir")
    IO.write("\nSeleccione una opción: ")

    case IO.gets("") |> String.trim() do
      "1" ->
        mostrar_productos()
        menu()

      "2" ->
        realizar_compra()
        menu()

      "3" ->
        IO.puts("\n¡Hasta luego!")

      _ ->
        IO.puts("\nOpción inválida.")
        menu()
    end
  end

  # Mostrar productos disponibles
  defp mostrar_productos do
    productos = Libremarket.Ventas.Server.listar_productos()

    IO.puts("\n========== PRODUCTOS ==========")

    productos
    |> Enum.sort_by(fn {id, _producto} -> id end)
    |> Enum.each(fn {id, producto} ->
      IO.puts("#{id}. #{producto.nombre} - Stock: #{producto.stock}")
    end)
  end

  # Proceso de compra desde la interfaz
  defp realizar_compra do
    mostrar_productos()

    productos = leer_productos()
    forma_entrega = leer_forma_entrega()
    medio_pago = leer_medio_pago()

    IO.puts("\nProcesando compra...")

    compra =
      Libremarket.Compras.Server.comprar(
        productos,
        forma_entrega,
        medio_pago
      )

    IO.puts("\n========== RESULTADO DE LA COMPRA ==========")
    IO.inspect(compra, pretty: true, limit: :infinity)
  end

  # Leer uno o varios productos separados por coma
  defp leer_productos do
    IO.write("\nIngrese los ID de los productos separados por coma (ej: 1,3,5): ")

    entrada = IO.gets("") |> String.trim()

    case parsear_productos(entrada) do
      {:ok, productos} ->
        productos

      :error ->
        IO.puts("Entrada inválida. Ingrese uno o varios números positivos.")
        leer_productos()
    end
  end

  defp parsear_productos(entrada) do
    partes = String.split(entrada, ",", trim: true)

    resultado =
      Enum.reduce_while(partes, [], fn parte, acumulados ->
        case Integer.parse(String.trim(parte)) do
          {id, ""} when id > 0 ->
            {:cont, [id | acumulados]}

          _ ->
            {:halt, :error}
        end
      end)

    case resultado do
      :error -> :error
      [] -> :error
      ids -> {:ok, Enum.reverse(ids)}
    end
  end

  # Leer forma de entrega
  defp leer_forma_entrega do
    IO.puts("\nForma de entrega:")
    IO.puts("1. Correo")
    IO.puts("2. Retiro en tienda")
    IO.write("Seleccione una opción: ")

    case IO.gets("") |> String.trim() do
      "1" -> :correo
      "2" -> :retira
      _ ->
        IO.puts("Opción inválida.")
        leer_forma_entrega()
    end
  end

  # Leer medio de pago
  defp leer_medio_pago do
    IO.puts("\nMedio de pago:")
    IO.puts("1. Efectivo")
    IO.puts("2. Transferencia")
    IO.puts("3. Tarjeta")
    IO.write("Seleccione una opción: ")

    case IO.gets("") |> String.trim() do
      "1" -> :efectivo
      "2" -> :transferencia
      "3" -> :tarjeta
      _ ->
        IO.puts("Opción inválida.")
        leer_medio_pago()
    end
  end

end
