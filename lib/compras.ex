
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

  def start_link(opts \\ %{}), do:
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def comprar(pid \\ __MODULE__, productos, forma_de_envio, medio_de_pago), do:
    GenServer.call(pid, {:comprar, productos, forma_de_envio, medio_de_pago})

  def confirmar_compra(pid \\ __MODULE__, id_compra), do:
    GenServer.call(pid, {:confirmar_compra, id_compra})


  def init(_state) do
    {:ok, %{proximo_id_compra: 0, compras: %{}}}
  end


  def handle_call({:confirmar_compra, id_compra}, _from, state) do
    result = Libremarket.Compras.confirmar_compra(id_compra)
    {:reply, result, state}
  end


  def handle_call({:comprar, productos, forma_entrega, medio_de_pago}, _from, state) do

    new_id_compra = state.proximo_id_compra + 1

    reserva = Libremarket.Ventas.Server.reservar_productos(productos)

    compra =
      case reserva do

        {:error, _motivo} ->
          %{
            id_compra: new_id_compra,
            productos: productos,
            estado_del_producto: reserva,
            forma_de_entrega: nil,
            medio_de_pago: medio_de_pago,
            infraccion: nil,
            estado_del_pago: nil,
            estado_final_compra: :compra_rechazada
          }

        {:ok, _} ->
          forma = Libremarket.Compras.selec_forma_entrega(forma_entrega)

          infraccion =
            Libremarket.Infracciones.Server.detectar_infraccion(
              new_id_compra,
              productos
            )

          if infraccion == :infraccion_detectada do

            %{
              id_compra: new_id_compra,
              productos: productos,
              estado_del_producto: reserva,
              forma_de_entrega: forma,
              medio_de_pago: medio_de_pago,
              infraccion: infraccion,
              estado_del_pago: nil,
              estado_final_compra: :compra_rechazada
            }

          else

            pago = Libremarket.Compras.confirmar_compra(new_id_compra)

            if pago == :pago_aprobado do

              if forma_entrega == :correo do
                Libremarket.Envios.Server.agendar_envio(new_id_compra)
              end

              %{
                id_compra: new_id_compra,
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
                id_compra: new_id_compra,
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

    nuevas_compras = Map.put(state.compras, new_id_compra, compra)

    nuevo_estado = %{
      state |
      proximo_id_compra: new_id_compra,
      compras: nuevas_compras
    }

    {:reply, compra, nuevo_estado}
  end
end
