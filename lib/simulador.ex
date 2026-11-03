
defmodule Simulador do

  def simular_compra() do
    productos =
      Enum.take_random(
        Enum.to_list(1..10),
        Enum.random(1..3)
      )

    simular_compra(productos)
  end


  def simular_compra(id_producto) when is_integer(id_producto) do
    simular_compra([id_producto])
  end


  def simular_compra(productos) when is_list(productos) do
    envio = if :rand.uniform(100) <= 70, do: :correo, else: :retira
    pago = Enum.random([:efectivo, :transferencia, :tarjeta])

    Libremarket.Compras.Server.comprar(productos, envio, pago)
  end


  def simular_compras_secuencial(cantidad \\ 1) do
    for _n <- 1..cantidad do
      simular_compra()
    end
  end


  def simular_compras_async(cantidad \\ 1) do
    compras =
      for _n <- 1..cantidad do
        Task.async(fn -> simular_compra() end)
      end

    Task.await_many(compras)
  end

end
