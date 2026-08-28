defmodule Libremarket.Compras do

  def comprar(id_compra) do
    Libremarket.Pagos.Server.autorizar_pagos(id_compra)
  end

  def selec_forma_entrega(forma) do
    if forma == :correo do
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

  # API del cliente

  @doc """
    Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def comprar(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:comprar, id_compra})
  end

  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  # Callbacks

  @doc """
    Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    {
      :ok,
      %{
        productos: [
          %{id: 1, nombre: "Notebook"},
          %{id: 2, nombre: "Mouse"},
          %{id: 3, nombre: "Keyboard"},
        ]
      }
    }
  end

  @doc """
    Callback para un call :comprar
  """
  @impl true
  def handle_call({:comprar, id_compra}, _from, state) do
    result = Libremarket.Compras.comprar(id_compra)
    {:reply, result, state}
  end

  def handle_call({:selec_forma_entrega, forma}, _from, state) do
    result = Libremarket.Compras.selec_forma_entrega(forma)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

end
