defmodule WandererApp.Kills.ClientTest do
  # Calls the client's callbacks directly with a stand-in socket process, so no
  # WandererKills server is needed.
  use ExUnit.Case, async: true

  alias WandererApp.Kills.Client

  # A process that stays alive until stopped, like the WebSocket client process
  defp fake_socket do
    {:ok, pid} = Agent.start(fn -> :socket end)
    pid
  end

  defp connected_state(socket_pid, last_message_ms_ago) do
    %Client{
      socket_pid: socket_pid,
      connected: true,
      connecting: false,
      last_message_time: System.system_time(:millisecond) - last_message_ms_ago
    }
  end

  describe "health check reconnect" do
    test "closes the old socket when no message arrived for 15 minutes" do
      socket = fake_socket()
      state = connected_state(socket, :timer.minutes(16))

      {:noreply, new_state} = Client.handle_info(:health_check, state)

      assert new_state.socket_pid == nil
      refute Process.alive?(socket), "the stale WebSocket must be closed, not just forgotten"
    end

    test "leaves a healthy connection alone" do
      socket = fake_socket()
      state = connected_state(socket, :timer.seconds(10))

      {:noreply, new_state} = Client.handle_info(:health_check, state)

      assert new_state.socket_pid == socket
      assert Process.alive?(socket)
      Agent.stop(socket)
    end
  end

  describe "disconnected" do
    test "closes the socket it drops" do
      socket = fake_socket()
      state = connected_state(socket, 0)

      {:noreply, new_state} = Client.handle_info({:disconnected, :channel_closed}, state)

      assert new_state.socket_pid == nil
      refute new_state.connected
      refute Process.alive?(socket)
    end

    test "copes with a socket that is already gone" do
      socket = fake_socket()
      Agent.stop(socket)
      state = connected_state(socket, 0)

      assert {:noreply, %{socket_pid: nil}} =
               Client.handle_info({:disconnected, {:socket_died, :normal}}, state)
    end
  end
end
