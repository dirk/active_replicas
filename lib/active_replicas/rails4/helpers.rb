require 'active_record/connection_adapters/connection_specification'

module ActiveReplicas
  module Rails4
    module Helpers
      extend self

      # Returns an instance of `ActiveRecord::ConnectionAdapters::ConnectionPool`
      # configured with the given specification.
      def self.connection_pool_for_spec(config_spec)
        @@resolver ||= ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new({})

        # Turns a hash configuration into a `ConnectionSpecification` that can
        # be passed to a `ConnectionPool`.
        spec = @@resolver.spec ActiveSupport::HashWithIndifferentAccess.new(config_spec)

        ActiveRecord::ConnectionAdapters::ConnectionPool.new spec
      end
    end
  end
end
