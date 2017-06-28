require 'active_support/core_ext/module/delegation'
require 'concurrent/map'

require 'active_replicas/rails5/process_local_connection_handler'
require 'active_replicas/rails5/proxying_connection_pool'

module ActiveReplicas
  module Rails5
    # Wraps around Rails' `ActiveRecord::ConnectionAdapters::ConnectionHandler`
    # to provide proxy wrappers around requested connections.
    #
    # This is the process-safe handler; it creates instances of
    # `ThreadLocalConnectionHandler` to provide proxy wrappers for each thread.
    class ConnectionHandler
      attr_accessor :proxy_configuration

      def initialize(proxy_configuration:)
        # Must symbolize for compatibility with how Rails will pass
        # configuration specs in `#establish_connection`.
        @proxy_configuration = proxy_configuration.deep_symbolize_keys

        # Each process will get its own thread-safe handler.
        @process_to_handler = Concurrent::Map.new
      end

      delegate :active_connections?, :clear_active_connections!,
        :clear_all_connections!, :clear_reloadable_connections!, :connected?,
        :connection_pool_list, :establish_connection, :remove_connection,
        :retrieve_connection, :retrieve_connection_pool,
        to: :retrieve_handler

      def clear_all_connections!
        # We also want to clear the process's connection handler in case our
        # configuration has been changed.
        if handler = @process_to_handler.delete(Process.pid)
          handler.clear_all_connections!
        end
      end

      # Returns a `ProcessLocalConnectionHandler` which is local to the
      # current process.
      def retrieve_handler
        @process_to_handler[Process.pid] ||= ProcessLocalConnectionHandler.new(@proxy_configuration)
      end
    end
  end

  ConnectionHandler = Rails5::ConnectionHandler
end
