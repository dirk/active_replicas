require 'concurrent/map'

module ActiveReplicas
  module Rails4
    # Wraps around Rails' `ActiveRecord::ConnectionAdapters::ConnectionHandler`
    # to provide proxy wrappers around requested connections.
    class ConnectionHandler
      def initialize(proxy_configuration:, delegate: nil, overrides: nil)
        @proxy_configuration = proxy_configuration
        # @delegate          = delegate
        # @overrides         = Set.new(overrides || [])

        # Each process will get its own map of connection keys to database
        # connection instances.
        @process_to_connection_pool = Concurrent::Map.new
      end

      def establish_connection(owner, _spec)
        raise "ActiveReplicas cannot establish connection for #{owner.name}"
      end

      def clear_active_connections!
        proxying_connection_pool.release_connection
      end

      # Cribbed from:
      #   https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb#L568
      def retrieve_connection(klass)
        pool = retrieve_connection_pool klass
        raise ConnectionNotEstablished, "No connection pool for #{klass}" unless pool
        conn = pool.connection
        raise ConnectionNotEstablished, "No connection for #{klass} in connection pool" unless conn
        conn
      end

      def retrieve_connection_pool(klass)
        proxying_connection_pool
      end

      def connected?(klass)
        pool = retrieve_connection_pool klass
        pool && pool.connected?
      end

      def remove_connection(owner_klass)
        if pool = @process_to_connection_pool.delete(Process.pid)
          pool.automatic_reconnect = false
          pool.disconnect!
          pool.spec.config
        end
      end

      def proxying_connection_pool
        @process_to_connection_pool[Process.pid] ||= ProxyingConnectionPool.new(@proxy_configuration)
      end
    end
  end

  ConnectionHandler = Rails4::ConnectionHandler
end
