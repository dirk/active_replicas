module ActiveReplicas
  class Railtie < Rails::Railtie
    cattr_reader :connection_handler

    cattr_accessor :replica_delegated_methods
    cattr_accessor :primary_delegated_methods

    @@replica_delegated_methods = [
      :active?, :clear_query_cache, :column_name_for_operation, :columns,
      :disable_query_cache!, :disconnect!, :enable_query_cache!,
      :query_cache_enabled, :quote_column_name, :quote_table_name,
      :raw_connection, :reconnect!, :sanitize_limit, :schema_cache, :select,
      :select_all, :select_one, :select_rows, :select_value, :select_values,
      :substitute_at, :to_sql, :verify!
    ]

    # Rails methods that translate to SQL DDL (data definition language).
    DDL_METHODS = [
      :add_column, :add_foreign_key, :add_index, :add_reference,
      :add_timestamps, :change_column, :change_column_default,
      :change_column_null, :create_join_table, :create_table,
      :drop_join_table, :drop_table, :enable_extension, :execute,
      :execute_block, :initialize_schema_migrations_table, :remove_column,
      :remove_columns, :remove_foreign_key, :remove_index, :remove_reference,
      :remove_timestamps, :rename_column, :rename_index, :rename_table
    ]

    # Rails methods that deal with create, read, update, delete in SQL
    CRUD_METHODS = [
      :delete, :insert, :truncate, :update
    ]

    @@primary_delegated_methods = (
      DDL_METHODS +
      CRUD_METHODS +
      [
        :next_sequence_value, :prefetch_primary_key?, :transaction,
        :transaction_state
      ]
    ).uniq

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

      # Take over logging duties now that we're the main connection handler.
      LogSubscriber.hijack_active_record
    end
  end
end
