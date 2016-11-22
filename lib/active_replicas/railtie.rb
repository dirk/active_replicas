require 'active_support/core_ext/class/attribute_accessors'

module ActiveReplicas
  class Railtie < Rails::Railtie
    cattr_reader :connection_handler

    cattr_accessor :replica_delegated_methods
    cattr_accessor :primary_delegated_methods

    # Reports what the database can handle, see URL for more information:
    #   https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/abstract/database_limits.rb
    DATABASE_LIMITS_METHODS = [
      :allowed_index_name_length, :column_name_length,
      :columns_per_multicolumn_index, :columns_per_table, :in_clause_length,
      :index_name_length, :indexes_per_table, :joins_per_query,
      :sql_query_length, :table_alias_length, :table_name_length
    ]

    # All the methods which are safe to be delegated to a replica.
    @@replica_delegated_methods = (
      DATABASE_LIMITS_METHODS +
      [
        :active?, :cacheable_query, :case_sensitive_comparison,
        :case_sensitive_modifier, :case_insensitive_comparison,
        :clear_query_cache, :column_name_for_operation, :columns,
        :disable_query_cache!, :disconnect!, :enable_query_cache!,
        :exec_query, :prepared_statements, :query_cache_enabled, :quote,
        :quote_column_name, :quote_table_name,
        :quote_table_name_for_assignment, :raw_connection, :reconnect!,
        :sanitize_limit, :schema_cache, :select, :select_all, :select_one,
        :select_rows, :select_value, :select_values, :substitute_at, :to_sql,
        :type_cast, :valid_type?, :verify!
      ]
    ).uniq

    # Rails methods that translate to SQL DDL (data definition language).
    DDL_METHODS = [
      :add_column, :add_foreign_key, :add_index, :add_reference,
      :add_timestamps, :change_column, :change_column_default,
      :change_column_null, :column_spec, :create_join_table, :create_table,
      :delete_table, :drop_join_table, :drop_table, :enable_extension,
      :execute, :execute_block, :initialize_schema_migrations_table,
      :migration_keys, :remove_column, :remove_columns, :remove_foreign_key,
      :remove_index, :remove_reference, :remove_timestamps, :rename_column,
      :rename_index, :rename_table
    ]

    # Rails methods that deal with create, read, update, delete in SQL
    CRUD_METHODS = [
      :delete, :insert, :next_sequence_value, :truncate, :update
    ]

    # Rails methods that query whether or not the adapter or database engine
    # supports a given feature.
    SUPPORTS_METHODS = [
      :supports_ddl_transactions?, :supports_explain?, :supports_extensions?,
      :supports_foreign_keys?, :supports_index_sort_order?,
      :supports_materialized_views?, :supports_migrations?,
      :supports_partial_index?, :supports_primary_key?, :supports_ranges?,
      :supports_statement_cache?, :supports_transaction_isolation?,
      :supports_views?
    ]

    @@primary_delegated_methods = (
      DDL_METHODS +
      CRUD_METHODS +
      SUPPORTS_METHODS +
      [
        :add_transaction_record, :assume_migrated_upto_version,
        :begin_db_transaction, :commit_db_transaction,
        :disable_referential_integrity, :foreign_keys, :indexes,
        :native_database_types, :prefetch_primary_key?, :primary_key,
        :rollback_db_transaction, :tables, :table_exists?, :transaction,
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
