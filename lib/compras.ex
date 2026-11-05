
defmodule Libremarket.Compras do

  def confirmar_compra(id_compra) do
    Libremarket.Pagos.Server.autorizar_pagos(id_compra)
  end

  def selec_producto(id_producto) do
    Libremarket.Ventas.Server.reservar_productos(id_producto)
  end

  def detectar_infraccion(id_compra, productos \\ []) do
    Libremarket.Infracciones.Server.detectar_infraccion(id_compra, productos)
  end

  def selec_forma_entrega(forma_de_envio) do
    if forma_de_envio == :correo do
      Libremarket.Envios.Server.calcular_costo()
    else
      :retiro_en_tienda
    end
  end

end


defmodule Libremarket.Compras.Server do
  use GenServer

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def comprar(pid \\ __MODULE__, productos, forma_de_envio, medio_de_pago) do
    GenServer.call(pid, {:comprar, productos, forma_de_envio, medio_de_pago})
  end

  def confirmar_compra(pid \\ __MODULE__, id_compra) do
    GenServer.call(pid, {:confirmar_compra, id_compra})
  end


  ##########################
  # CALLBACKS
  ##########################

  @impl true
  def init(_state) do
    {:ok, %{}}
  end


  @impl true
  def handle_call({:confirmar_compra, id_compra}, _from, state) do
    result = Libremarket.Compras.confirmar_compra(id_compra)
    {:reply, result, state}
  end


  @impl true
  def handle_call(
        {:comprar, productos, forma_entrega, medio_de_pago},
        _from,
        state
      ) do

    # Obtiene un ID directamente de la secuencia de PostgreSQL.
    [[id_compra]] =
      Libremarket.Repo.query!(
        "SELECT nextval('compras_id_compra_seq')"
      ).rows

    reserva =
      Libremarket.Ventas.Server.reservar_productos(productos)

    compra =
      case reserva do

        {:error, _motivo} ->

          %{
            id_compra: id_compra,
            productos: productos,
            estado_del_producto: reserva,
            forma_de_entrega: nil,
            medio_de_pago: medio_de_pago,
            infraccion: nil,
            estado_del_pago: nil,
            estado_final_compra: :compra_rechazada
          }

        {:ok, _} ->

          forma =
            Libremarket.Compras.selec_forma_entrega(forma_entrega)

          infraccion =
            Libremarket.Infracciones.Server.detectar_infraccion(
              id_compra,
              productos
            )

          if infraccion == :infraccion_detectada do

            %{
              id_compra: id_compra,
              productos: productos,
              estado_del_producto: reserva,
              forma_de_entrega: forma,
              medio_de_pago: medio_de_pago,
              infraccion: infraccion,
              estado_del_pago: nil,
              estado_final_compra: :compra_rechazada
            }

          else

            pago =
              Libremarket.Compras.confirmar_compra(id_compra)

            if pago == :pago_aprobado do

              if forma_entrega == :correo do
                Libremarket.Envios.Server.agendar_envio(id_compra)
              end

              %{
                id_compra: id_compra,
                productos: productos,
                estado_del_producto: reserva,
                forma_de_entrega: forma,
                medio_de_pago: medio_de_pago,
                infraccion: infraccion,
                estado_del_pago: pago,
                estado_final_compra: :compra_aprobada
              }

            else

              Libremarket.Ventas.Server.liberar_productos(productos)

              %{
                id_compra: id_compra,
                productos: productos,
                estado_del_producto: reserva,
                forma_de_entrega: forma,
                medio_de_pago: medio_de_pago,
                infraccion: infraccion,
                estado_del_pago: pago,
                estado_final_compra: :compra_rechazada
              }

            end
          end
      end

    # Guarda el intento de compra en PostgreSQL.
    guardar_compra(compra)

    {:reply, compra, state}
  end


  ##########################
  # FUNCIONES INTERNAS
  ##########################

  defp guardar_compra(compra) do

    productos =
      Enum.join(compra.productos, ",")

    Libremarket.Repo.query!(
      """
      INSERT INTO compras (
        id_compra,
        productos,
        estado_del_producto,
        forma_de_entrega,
        medio_de_pago,
        infraccion,
        estado_del_pago,
        estado_final_compra
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      """,
      [
        compra.id_compra,
        productos,
        serializar(compra.estado_del_producto),
        serializar(compra.forma_de_entrega),
        serializar(compra.medio_de_pago),
        serializar(compra.infraccion),
        serializar(compra.estado_del_pago),
        serializar(compra.estado_final_compra)
      ]
    )

  end


  defp serializar(nil), do: nil

  defp serializar({:ok, valor}), do: serializar(valor)

  defp serializar({:error, motivo}), do: serializar(motivo)

  defp serializar(valor) when is_atom(valor), do: Atom.to_string(valor)

  defp serializar(valor) when is_binary(valor), do: valor

  defp serializar(valor) when is_number(valor), do: to_string(valor)

  defp serializar(valor), do: inspect(valor)

end
