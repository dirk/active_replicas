module ActiveReplicas
  # Manages connection pools to the primary and replica databases. Returns
  # proxy connection instances from those pools on request.
  #
  # Also hanldes the internal state of switching back and forth from replica
  # to primary connections based on heuristics or overrides.
  class ProxyingConnectionPool
    def initialize(proxy_configuration)
      # Creates new `ActiveRecord::ConnectionAdapters::ConnectionSpecification`
      # instances for the connection pools to use.
      resolver = ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new({})
      specification = ->(spec) {
        resolver.spec(spec)
      }

      @primary_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new specification.(proxy_configuration[:primary])

      @replica_pools = (proxy_configuration[:replicas] || {}).map do |name, config_spec|
        [ name, specification.(config_spec) ]
      end.to_h

      # Calls to `with_primary` will increment and decrement this.
      @primary_depth = 0
      # Current connection pool.
      @current_pool = nil
      # Thread-safe map of the connections from each pool. Cleared in tandem
      # with the connection pools.
      @connections = Concurrent::Map.new
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

    # Additional methods
    # ==================

    def with_primary
      previous_pool = @current_pool

      @primary_depth += 1
      @current_pool = @primary_pool

      yield connection
    ensure
      @primary_pool = [@primary_depth - 1, 0].max
      @current_pool = previous_pool
    end

    # Quick accessor to a primary connection.
    #
    # NOTE: If this is not already in a `with_primary` block then calling this
    #   will irreversably place the proxying pool in the primary state until
    #   `clear_active_connections!` is called! If you want to *temporarily*
    #   use the primary then explicitly do so using `with_primary`.
    def primary_connection
      if @connections.key? @primary_pool
        conn = @connections[@primary_pool]
      else
        @primary_depth += 1
        @current_pool = @primary_pool
        conn = connection
      end

      conn
    end

    def each_pool
      yield @primary_pool

      @replica_pools.each do |_name, pool|
        yield pool
      end
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
