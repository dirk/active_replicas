require 'monitor'

require 'active_replicas/rails4/helpers'

module ActiveReplicas
  module Rails4
    # Provisioned for each process by `ConnectionHandler`. Each process owns
    # its own pools of connections to primary and replica databases.
    # Proxying connection pools are then provisioned for each thread.
    class ProcessLocalConnectionHandler
      attr_reader :proxy_configuration
      attr_reader :primary_pool, :replica_pools

      def initialize(proxy_configuration)
        @proxy_configuration = proxy_configuration

        @primary_pool = Helpers.connection_pool_for_spec @proxy_configuration[:primary]

        @replica_pools = (@proxy_configuration[:replicas] || {}).map do |name, config_spec|
          [name, Helpers.connection_pool_for_spec(config_spec)]
        end.to_h

        # Each thread gets its own `ProxyingConnectionPool`.
        @reserved_proxies = Concurrent::Map.new

        extend MonitorMixin
      end

      # Returns a list of *all* the connection pools owned by this handler.
      def connection_pool_list
        [@primary_pool] + @replica_pools.values
      end

      def establish_connection(owner, spec)
        prefix = '[ActiveReplicas::Rails4::ConnectionHandler#establish_connection]'
        ActiveRecord::Base.logger&.warn "#{prefix} Ignoring spec for #{owner.inspect}: #{spec.inspect}"
        ActiveRecord::Base.logger&.info "#{prefix} Called from:\n" + Kernel.caller.first(5).map {|t| "  #{t}" }.join("\n")

        current_proxy
      end

      def active_connections?
        connection_pool_list.any?(&:active_connection?)
      end

      def clear_active_connections!
        synchronize do
          connection_pool_list.each(&:release_connection)
          clear_current_proxy
        end
      end

      def clear_reloadable_connections!
        synchronize do
          connection_pool_list.each(&:clear_reloadable_connections!)
          clear_proxies!
        end
      end

      def clear_all_connections!
        synchronize do
          connection_pool_list.each(&:disconnect!)
          clear_proxies!
        end
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

      def connected?(klass)
        pool = retrieve_connection_pool klass
        pool && pool.connected?
      end

      def remove_connection(owner_klass)
        if proxy = clear_current_proxy
          proxy.automatic_reconnect = false
          proxy.disconnect!
          proxy.spec.config
        end
      end

      def retrieve_connection_pool(klass)
        current_proxy
      end

      # Semi-private implementation methdos
      # ===================================

      # Returns the `ThreadLocalConnectionHandler` for this thread.
      def current_proxy
        @reserved_proxies[current_thread_id] || synchronize do
          @reserved_proxies[current_thread_id] ||= ProxyingConnectionPool.new(self)
        end
      end

      # Remove the current reserved `ProxyingConnectionPool` from the pool.
      def clear_current_proxy
        @reserved_proxies.delete current_thread_id
      end

      # Clear all reserved `ProxyingConnectionPool` instances from the pool.
      def clear_proxies!
        @reserved_proxies.clear
      end

      def current_thread_id
        Thread.current.object_id
      end
    end
  end
end
