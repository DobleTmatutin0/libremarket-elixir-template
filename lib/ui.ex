defmodule Libremarket.Ui do

  def comprar(productos, forma_entrega, medio_pago) do

    confirmado = :rand.uniform(100) <= 80

    if confirmado do
      Libremarket.Compras.Server.comprar(productos, forma_entrega, medio_pago)
    else
      {:compra_cancelada, productos}
    end
  end

end
