defmodule Simulador do

  defp comprar(id_producto, forma_de_envio, medio_de_pago) do
    Libremarket.Ui.comprar(id_producto, forma_de_envio, medio_de_pago)
  end

  def simular_compra() do
    envio = Enum.random([:retira, :correo])
    pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    comprar(:rand.uniform(10), envio, pago)
  end

  def simular_compras_secuencial(cantidad \\ 1) do
    for _n <- 1 .. cantidad do
      simular_compra()
    end
  end

  def simular_compras_async(cantidad \\ 1) do
    compras = for _n <- 1 .. cantidad do
      Task.async(fn -> simular_compra() end)
    end
    Task.await_many(compras)
  end

end
