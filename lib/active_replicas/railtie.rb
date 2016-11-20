module ActiveReplicas
  class Railtie < Rails::Railtie
    cattr_reader :connection_handler

    cattr_accessor :replica_delegated_methods
    cattr_accessor :primary_delegated_methods

    @@replica_delegated_methods = [
      :active?, :clear_query_cache, :columns, :disable_query_cache!,
      :disconnect!, :enable_query_cache!, :query_cache_enabled,
      :raw_connection, :reconnect!, :sanitize_limit, :schema_cache,
      :select, :select_all, :select_one, :select_rows, :select_value,
      :select_values, :substitute_at, :to_sql, :verify!
    ]

    @@primary_delegated_methods = [
      :insert, :next_sequence_value, :prefetch_primary_key?,
      :transaction, :transaction_state, :update
    ]

    def self.hijack_active_record(proxy_configuration, overrides: [])
      ProxyingConnection.generate_replica_delegations
      ProxyingConnection.generate_primary_delegations

      @@connection_handler =
        ConnectionHandler.new proxy_configuration: proxy_configuration,
                              delegate: ActiveRecord::Base.connection_handler,
                              overrides: overrides

      ActiveRecord::Base.class_eval do
        def self.connection_handler
          ActiveReplicas::Railtie.connection_handler
        end
      end
    end
  end
end
