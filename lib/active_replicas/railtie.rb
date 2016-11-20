module ActiveReplicas
  class Railtie < Rails::Railtie
    class << self
      attr_reader :connection_handler

      def hijack_active_record(proxy_configuration, overrides: [])
        @connection_handler =
          ActiveReplicas::ConnectionHandler.new proxy_configuration: proxy_configuration,
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
end
