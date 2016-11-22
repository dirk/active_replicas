require 'active_support/hash_with_indifferent_access'

module ActiveReplicas
  # Manages connection pools to the primary and replica databases. Returns
  # proxy connection instances from those pools on request.
  #
  # Also hanldes the internal state of switching back and forth from replica
  # to primary connections based on heuristics or overrides.
  class ProxyingConnectionPool
    attr_reader :primary_pool, :replica_pools

    def initialize(proxy_configuration)
      @primary_pool = ProxyingConnectionPool.connection_pool_for_spec proxy_configuration[:primary]

      @replica_pools = (proxy_configuration[:replicas] || {}).map do |name, config_spec|
        [ name, ProxyingConnectionPool.connection_pool_for_spec(config_spec) ]
      end.to_h

      # Calls to `with_primary` will increment and decrement this.
      @primary_depth = 0
      # Current connection pool.
      @current_pool = nil
      # Thread-safe map of the connections from each pool. Cleared in tandem
      # with the connection pools.
      @connections = Concurrent::Map.new
    end

    # Returns an instance of `ActiveRecord::ConnectionAdapters::ConnectionPool`
    # configured with the given specification.
    def self.connection_pool_for_spec(config_spec)
      @@resolver ||= ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new({})

      # Turns a hash configuration into a `ConnectionSpecification` that can
      # be passed to a `ConnectionPool`.
      spec = @@resolver.spec ActiveSupport::HashWithIndifferentAccess.new(config_spec)

      ActiveRecord::ConnectionAdapters::ConnectionPool.new spec
    end

    # ConnectionPool interface methods
    # ================================

    def connection
      pool = current_pool

      @connections[pool] ||= begin
        conn = pool.connection
        return unless conn

        ProxyingConnection.new connection: conn,
                               is_primary: pool == @primary_pool,
                               proxy:      self
      end
    end

    def release_connection
      each_pool &:release_connection

      @primary_depth = 0
      @current_pool = nil
      @connections.clear
    end

    def connected?
      current_pool.connected?
    end

    def disconnect!
      each_pool &:disconnect!
    end

    def current_pool
      if @current_pool == nil
        @current_pool = next_pool
      end

      @current_pool
    end

    def automatic_reconnect=(new_value)
      each_pool do |pool|
        pool.automatic_reconnect = new_value
      end
    end

    # Additional methods
    # ==================

    def with_primary
      previous_pool = @current_pool

      @primary_depth += 1
      @current_pool = @primary_pool

      yield connection
    ensure
      @primary_depth = [@primary_depth - 1, 0].max
      @current_pool = previous_pool
    end

    # Quick accessor to a primary connection.
    #
    # NOTE: If this is not already in a `with_primary` block then calling this
    #   will irreversably place the proxying pool in the primary state until
    #   `clear_active_connections!` is called! If you want to *temporarily*
    #   use the primary then explicitly do so using `with_primary`.
    def primary_connection
      if @primary_depth == 0
        @primary_depth += 1
        @current_pool = @primary_pool
      end

      connection
    end

    def each_pool
      yield @primary_pool

      @replica_pools.each do |_name, pool|
        yield pool
      end
    end

    def pool_which_owns_connection(object_id)
      return @primary_pool if @primary_pool.connections.any? { |c| c.object_id == object_id }

      @replica_pools.values.each do |pool|
        return pool if pool.connections.any? { |c| c.object_id == object_id }
      end

      nil
    end

    def primary_pool?(pool)
      pool == @primary_pool
    end

    def replica_pool?(pool)
      @replica_pools.values.include? pool
    end

    private

    def next_pool
      replicas = @replica_pools.values

      if replicas.empty?
        @primary_pool
      else
        replicas.sample
      end
    end
  end
end
