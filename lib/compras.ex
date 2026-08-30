defmodule Libremarket.Compras do

  def confirmar_compra(id_compra) do
    Libremarket.Pagos.Server.autorizar_pagos(id_compra)
  end

  def selec_producto(id_producto) do
    Libremarket.Ventas.Server.reservar_productos(id_producto)
  end

  def detectar_infraccion(id_compra) do
    Libremarket.Infracciones.Server.detectar_infraccion(id_compra)
  end

  def selec_forma_entrega(forma_de_envio) do
    if forma_de_envio == :correo do
      Libremarket.Envios.Server.calcular_costo()
    else
      :retiro_en_tienda
    end
  end

  def confirmar_compra() do
    :compra_confirmada
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
  def comprar(pid \\ __MODULE__, id_producto, forma_de_envio) do
    GenServer.call(pid, {:comprar, id_producto, forma_de_envio})
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

  def handle_call({:comprar, id_producto, forma_de_envio}, _from, state) do
    new_id_compra = Map.get(state, :proximo_id_compra)
    result = Libremarket.Compras.selec_producto(id_producto)
    result1 = Libremarket.Compras.selec_forma_entrega(forma_de_envio)
    result2 = Libremarket.Compras.detectar_infraccion(new_id_compra)

    compra = %{
      id_compra: new_id_compra,
      producto: id_producto,
      estado_del_producto: result,
      forma_de_entrega: result1,
      infraccion: result2
    }

    new_state_compras = Map.put(state.compras, new_id_compra, compra)

    new_state = %{state | proximo_id_compra: new_id_compra + 1, compras: new_state_compras}
    {:reply, compra, new_state}
  end


end
