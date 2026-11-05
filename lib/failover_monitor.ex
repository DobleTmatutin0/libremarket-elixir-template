defmodule Libremarket.FailoverMonitor do
  use GenServer
  require Logger

  # Asumo que tu módulo Repo se llama Libremarket.Repo. Ajustalo si es diferente.
  alias Libremarket.Repo

  @check_interval 5_000 # Verificar cada 5 segundos
  @max_fails 3
  @primary_ip "192.168.56.11"
  @primary_port 5432

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Logger.info("Iniciando monitor de Failover para PostgreSQL...")
    schedule_check()
    {:ok, Map.merge(state, %{fail_count: 0})}
  end

  def handle_info(:check, state) do
    # 1. Comprobar si nuestra base local está en modo recuperación (es réplica)
    case Ecto.Adapters.SQL.query(Repo, "SELECT pg_is_in_recovery();") do
      {:ok, %{rows: [[true]]}} ->
        # Somos réplica, procedemos a hacer ping al Primario
        new_state = check_primary(state)
        schedule_check()
        {:noreply, new_state}

      {:ok, %{rows: [[false]]}} ->
        # Ya somos primario (o ya fuimos promovidos), detenemos el monitor
        Logger.info("La base de datos local es Primaria. Deteniendo chequeos de failover.")
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.error("Error consultando estado de recuperación: #{inspect(reason)}")
        schedule_check()
        {:noreply, state}
    end
  end

  defp check_primary(state) do
    # Convertimos la IP a charlist, requerido por la librería TCP de Erlang
    host = String.to_charlist(@primary_ip)
    
    # 2. Intentar abrir una conexión TCP pura al puerto de PostgreSQL de N1
    case :gen_tcp.connect(host, @primary_port, [], 1_000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        %{state | fail_count: 0} # Reiniciar contador porque N1 está vivo

      {:error, _reason} ->
        new_count = state.fail_count + 1
        Logger.warning("Fallo al conectar con Primario (#{@primary_ip}). Intento #{new_count} de #{@max_fails}")

        # 3. Si se alcanza el límite de fallos, promover la base local
        if new_count >= @max_fails do
          promote_local_db()
          %{state | fail_count: 0}
        else
          %{state | fail_count: new_count}
        end
    end
  end

  defp promote_local_db do
    Logger.warning("¡N1 caído detectado! Promoviendo BD local a Primario...")
    case Ecto.Adapters.SQL.query(Repo, "SELECT pg_promote();") do
      {:ok, _} -> Logger.info("Promoción exitosa. Este nodo ahora es Primario.")
      {:error, err} -> Logger.error("Error al ejecutar pg_promote: #{inspect(err)}")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
