defmodule Libremarket.Compras do

  def comprar() do
    Libremarket.Pagos.Server.autorizar_pagos()
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

  def comprar(pid \\ __MODULE__) do
    GenServer.call(pid, :comprar)
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
  def handle_call(:comprar, _from, state) do
    result = Libremarket.Compras.comprar
    {:reply, result, state}
  end

  @doc """
    Callback para un call :listar_productos
  """
  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

end
