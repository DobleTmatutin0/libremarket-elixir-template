
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
  Gestiona el catálogo y el stock de productos mediante PostgreSQL.
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
    inicializar_catalogo()

    {:ok, %{}}
  end


  @impl true
  def handle_call(:listar_productos, _from, state) do

    resultado =
      Libremarket.Repo.query!(
        "SELECT id, nombre, stock FROM ventas ORDER BY id"
      )

    productos =
      Map.new(resultado.rows, fn [id, nombre, stock] ->
        {id, %{nombre: nombre, stock: stock}}
      end)

    {:reply, productos, state}
  end


  @impl true
  def handle_call({:reservar_productos, productos}, _from, state) do

    resultado =
      Libremarket.Repo.transaction(fn ->

        Enum.each(productos, fn id_producto ->

          actualizacion =
            Libremarket.Repo.query!(
              """
              UPDATE ventas
              SET stock = stock - 1
              WHERE id = $1 AND stock > 0
              """,
              [id_producto]
            )

          if actualizacion.num_rows == 0 do

            existe =
              Libremarket.Repo.query!(
                "SELECT EXISTS (SELECT 1 FROM ventas WHERE id = $1)",
                [id_producto]
              )

            case existe.rows do
              [[true]] ->
                Libremarket.Repo.rollback(:out_of_stock)

              [[false]] ->
                Libremarket.Repo.rollback(:el_producto_no_existe)
            end

          end

        end)

        :productos_reservados

      end)

    respuesta =
      case resultado do
        {:ok, _} ->
          {:ok, :productos_reservados}

        {:error, motivo} ->
          {:error, motivo}
      end

    {:reply, respuesta, state}
  end


  @impl true
  def handle_call({:liberar_productos, productos}, _from, state) do

    Libremarket.Repo.transaction(fn ->

      Enum.each(productos, fn id_producto ->

        Libremarket.Repo.query!(
          """
          UPDATE ventas
          SET stock = stock + 1
          WHERE id = $1
          """,
          [id_producto]
        )

      end)

    end)

    {:reply, {:ok, :productos_liberados}, state}
  end


  ##########################
  # FUNCIONES INTERNAS
  ##########################

  defp inicializar_catalogo do

    catalogo_vacio =
      Libremarket.Repo.query!(
        "SELECT NOT EXISTS (SELECT 1 FROM ventas)"
      )

    case catalogo_vacio.rows do

      [[true]] ->

        productos = [
          "Notebook",
          "Mouse",
          "Keyboard",
          "Monitor",
          "Auriculares",
          "Webcam",
          "Parlante",
          "Microfono",
          "Tablet",
          "Impresora"
        ]

        {:ok, _resultado} =
          Libremarket.Repo.transaction(fn ->

            Enum.each(productos, fn nombre ->

              Libremarket.Repo.query!(
                """
                INSERT INTO ventas (nombre, stock)
                VALUES ($1, $2)
                """,
                [nombre, :rand.uniform(10)]
              )

            end)

          end)

      [[false]] ->
        :ok

    end

  end

end
