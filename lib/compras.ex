defmodule Libremarket.Compras do

  def confirmar_compra(id_compra) do
    Libremarket.Pagos.Server.autorizar_pagos(id_compra)
  end

  #cambiar nombre de result
  def selec_producto(id_producto) do
    # new_id_compra = :rand.uniform(1000)
    result = Libremarket.Ventas.Server.reservar_productos(id_producto)
    # result2 = Libremarket.Infracciones.Server.detectar_infraccion(new_id_compra)
  end

  def detectar_infraccion(id_compra) do
    result = Libremarket.Infracciones.Server.detectar_infraccion(new_id_compra)
  end

  def selec_forma_entrega(forma) do
    if forma == :correo do
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

  def comprar(pid \\ __MODULE__) do
    GenServer.call(pid, {:comprar, id_compra})
  end

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
  def init(state) do
    {:ok, state}
  end

  @doc """
    Callback para un call :comprar
  """
  @impl true
  def handle_call({:confirmar_compra, id_compra}, _from, state) do
    result = Libremarket.Compras.confirmar_compra(id_compra)
    {:reply, result, state}
  end

  def handle_call({:comprar, id_producto, forma}, _from, state) do
    new_id_compra = :rand.uniform(1000)
    result = Libremarket.Compras.select_producto(id_producto)
    result1 = Libremarket.Compras.selec_forma_entrega(forma)
    result2 = Libremarket.Compras.detectar_infraccion(new_id_compra)
    compra = %{
      id_compra: new_id_compra
      producto: id_producto
      estado_del_producto: result
      forma_de_entrega: result1
      infraccion: result2
    }
    new_state = Map.#???
    {:reply, compra, state}
  end


end
