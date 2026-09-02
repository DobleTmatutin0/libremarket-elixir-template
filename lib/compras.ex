defmodule Libremarket.Compras do

  def confirmar_compra(id_compra) do
    Libremarket.Pagos.Server.autorizar_pagos(id_compra)
  end

  def selec_producto(id_producto) do
    # new_id_compra = :rand.uniform(1000)
    Libremarket.Ventas.Server.reservar_productos(id_producto)
    # result2 = Libremarket.Infracciones.Server.detectar_infraccion(new_id_compra)
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
  @moduledoc """
    Compras
  """

  use GenServer

  ##########################
  # API del cliente
  ##########################

  @doc """
    Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
    representa todo el proceso de la compra, seleccionar el producto, tipo de envio, etc
  """
  def comprar(pid \\ __MODULE__, productos, forma_de_envio, medio_de_pago) do
    GenServer.call(pid, {:comprar, productos, forma_de_envio, medio_de_pago})
  end

  @doc """
    boton de confirmacion para autorizar el pago
  """
  def confirmar_compra(pid \\ __MODULE__, id_compra) do
    GenServer.call(pid, {:confirmar_compra, id_compra})
  end

  ##########################
  # Callbacks
  ##########################

  @doc """
    Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {
        :ok,
        %{
            proximo_id_compra: 0,
            compras: %{}
        }
    }
  end

  @doc """
    Callback para un call :comprar
  """
  @impl true
  def handle_call({:confirmar_compra, id_compra}, _from, state) do
    result = Libremarket.Compras.confirmar_compra(id_compra)
    {:reply, result, state}
  end

  def handle_call({:comprar, productos, forma_entrega, medio_de_pago}, _from, state) do
    new_id_compra = :rand.uniform(1000)
    reserva = Libremarket.Ventas.Server.reservar_productos(productos)
    infraccion = Libremarket.Infracciones.Server.detectar_infraccion(new_id_compra, productos)
    forma = Libremarket.Compras.selec_forma_entrega(forma_entrega)

    if reserva == {:error, :el_producto_no_existe} or reserva == {:error, :out_of_stock} do
      {:reply, :out_of_stock, state}
    else
      if infraccion == :infraccion_detectada do
        {:reply, :infraccion_detectada, state}
      else
        compra = %{
          id_compra: new_id_compra,
          productos: productos,
          estado_del_producto: reserva,
          forma_de_entrega: forma,
          medio_de_pago: medio_de_pago,
          infraccion: infraccion
        }

        new_state = Map.put(state.compras, new_id_compra, compra)
        nueva_estructura = %{state | compras: new_state}

        pago = Libremarket.Compras.confirmar_compra(new_id_compra)

        if pago == :pago_aprobado do
          if forma_entrega == :correo do
            Libremarket.Envios.Server.agendar_envio(new_id_compra)
          end
          {:reply, compra, nueva_estructura}
        else
          Libremarket.Ventas.Server.liberar_productos(productos)
          {:reply, :compra_rechazada, nueva_estructura}
        end
      end
    end
  end


end
