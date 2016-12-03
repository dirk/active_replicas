require 'active_support/core_ext/module/delegation'
require 'active_support/hash_with_indifferent_access'
require 'monitor'

module ActiveReplicas
  # Manages connection pools to the primary and replica databases. Returns
  # proxy connection instances from those pools on request.
  #
  # Also hanldes the internal state of switching back and forth from replica
  # to primary connections based on heuristics or overrides.
  #
  # NOTE: This proxy instance should be provisioned per-thread and it is *not*
  #   thread-safe!
  class ProxyingConnectionPool
    attr_reader :handler

    # handler - `ProcessLocalConnectionHandler` which created this pool.
    def initialize(handler)
      @handler = handler

      # Calls to `with_primary` will increment and decrement this.
      @primary_depth = 0
      # Current connection pool.
      @current_pool = nil
    end

    delegate :primary_pool, :replica_pools, to: :handler

    # ConnectionPool interface methods
    # ================================

    def connection
      pool = current_pool

      conn = pool.connection
      return unless conn

      ProxyingConnection.new connection: conn,
                             is_primary: pool == primary_pool,
                             proxy:      self
    end

    def active_connection?
      all_pools.any?(&:active_connection?)
    end

    def release_connection
      all_pools.each(&:release_connection)

      @primary_depth = 0
      @current_pool = nil
    end

    def with_connection(&block)
      current_pool.with_connection(&block)
    end

    def connected?
      current_pool.connected?
    end

    def disconnect!
      all_pools.each(&:disconnect!)
    end

    def clear_reloadable_connections!
      all_pools.each(&:clear_reloadable_connections!)
    end

    def current_pool
      if @current_pool == nil
        @current_pool = next_pool
      end

      @current_pool
    end

    # ConnectionPool attribute readers and accessors
    # ==============================================

    def automatic_reconnect=(new_value)
      all_pools.each do |pool|
        pool.automatic_reconnect = new_value
      end
    end

    def connections
      primary_pool.connections
    end

    def spec
      primary_pool.spec
    end

    # Additional methods
    # ==================

    def with_primary
      previous_pool = @current_pool

      @primary_depth += 1
      @current_pool = primary_pool

      yield connection
    ensure
      @primary_depth = [@primary_depth - 1, 0].max
      @current_pool = previous_pool
    end

    def using_primary?
      @primary_depth > 0
    end

    # Quick accessor to a primary connection.
    #
    # NOTE: If this is not already in a `with_primary` block then calling this
    #   will irreversably place the proxying pool in the primary state until
    #   `release_connection!` is called! If you want to *temporarily*
    #   use the primary then explicitly do so using `with_primary`.
    def primary_connection
      if @primary_depth == 0
        @primary_depth += 1
        @current_pool = primary_pool
      end

      connection
    end

    # Returns an `Enumerable` over all the pools, primary and replicas, used
    # by this proxying pool.
    def all_pools
      [primary_pool] + replica_pools.values
    end

    def pool_which_owns_connection(object_id)
      return primary_pool if primary_pool.connections.any? { |c| c.object_id == object_id }

      replica_pools.values.each do |pool|
        return pool if pool.connections.any? { |c| c.object_id == object_id }
      end

      nil
    end

    def primary_pool?(pool)
      pool == primary_pool
    end

    def replica_pool?(pool)
      replica_pools.values.include? pool
    end

    private

    def next_pool
      replicas = replica_pools.values

      if replicas.empty?
        primary_pool
      else
        replicas.sample
      end
    end
  end
end
