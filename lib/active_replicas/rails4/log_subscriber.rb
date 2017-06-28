require 'active_record/log_subscriber'

module ActiveReplicas
  module Rails4
    class LogSubscriber < ActiveRecord::LogSubscriber
      def sql(event)
        self.class.runtime += event.duration
        return unless logger.debug?

        payload = event.payload

        return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

        pool  = nil
        name  = "#{payload[:name]} (#{event.duration.round(1)}ms)"
        sql   = payload[:sql]
        binds = nil

        proxy = ActiveRecord::Base.connection_handler.retrieve_handler.current_proxy
        connection_pool = proxy.pool_which_owns_connection payload[:connection_id]
        if connection_pool
          role =
            if proxy.primary_pool? connection_pool
              'primary'
            elsif proxy.replica_pool? connection_pool
              pool_name = proxy.replica_pools.key connection_pool
              "replica=#{pool_name}"
            else
              'unknown'
            end

          pool = "[#{role}] "
        end

        unless (payload[:binds] || []).empty?
          binds = ' ' + payload[:binds].map { |column, value| render_bind(column, value) }.inspect
        end

        debug "#{pool}#{name} #{sql}#{binds}"
      end

      def logger
        ActiveRecord::Base.logger
      end

      # Take over logging duties from `ActiveRecord::LogSubscriber`.
      def self.hijack_active_record
        self.attach_to :active_record

        subscriber = ActiveSupport::Notifications.notifier.listeners_for('sql.active_record').find do |subscriber|
          ActiveRecord::LogSubscriber === subscriber.instance_eval { @delegate }
        end

        ActiveSupport::Notifications.notifier.unsubscribe(subscriber) if subscriber
      end
    end
  end
  
  LogSubscriber = Rails4::LogSubscriber
end
