defmodule Libremarket.Ui do

  def comprar(_producto, _medio_de_pago, _forma_de_entrega) do
    id_producto = :rand.uniform(10)
    forma_entrega = if :rand.uniform(100) <= 70, do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :tarjeta])
    confirmado = :rand.uniform(100) <= 80

    if confirmado do
      Libremarket.Compras.Server.comprar(id_producto, forma_entrega, medio_pago)
    else
      {:compra_cancelada, id_producto}
    end
  end

end
