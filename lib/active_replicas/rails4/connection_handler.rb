require 'concurrent/map'

module ActiveReplicas
  module Rails4
    # Wraps around Rails' `ActiveRecord::ConnectionAdapters::ConnectionHandler`
    # to provide proxy wrappers around requested connections.
    class ConnectionHandler
      attr_accessor :proxy_configuration

      def initialize(proxy_configuration:, delegate: nil, overrides: nil)
        @proxy_configuration = proxy_configuration
        # @delegate          = delegate
        # @overrides         = Set.new(overrides || [])

        # Each process will get its own map of connection keys to database
        # connection instances.
        @process_to_connection_pool = Concurrent::Map.new
      end

      def connection_pool_list
        [ @process_to_connection_pool[Process.pid] ].compact
      end

      def establish_connection(owner, spec)
        prefix = '[ActiveReplicas::Rails4::ConnectionHandler#establish_connection]'
        ActiveRecord::Base.logger&.warn "#{prefix} Ignoring spec for #{owner.inspect}: #{spec.inspect}"
        ActiveRecord::Base.logger&.info "#{prefix} Called from:\n" + Kernel.caller.first(5).map {|t| "  #{t}" }.join("\n")

        proxying_connection_pool
      end

      def clear_active_connections!
        proxying_connection_pool.release_connection
      end

      def clear_reloadable_connections!
        proxying_connection_pool.clear_reloadable_connections!
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
        remove_proxying_connection_pool
      end

      def remove_proxying_connection_pool
        if proxying_pool = @process_to_connection_pool.delete(Process.pid)
          proxying_pool.automatic_reconnect = false
          proxying_pool.disconnect!
          proxying_pool.primary_pool.spec.config
        end
      end

      def proxying_connection_pool
        @process_to_connection_pool[Process.pid] ||= ProxyingConnectionPool.new(@proxy_configuration)
      end
    end
  end

  ConnectionHandler = Rails4::ConnectionHandler
end
