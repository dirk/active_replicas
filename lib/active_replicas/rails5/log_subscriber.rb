require 'active_record/log_subscriber'

module ActiveReplicas
  module Rails5
    class LogSubscriber < ActiveRecord::LogSubscriber
      def sql(event)
        self.class.runtime += event.duration
        return unless logger.debug?

        payload = event.payload

        return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

        pool = nil
        name = "#{payload[:name]} (#{event.duration.round(1)}ms)"
        sql = payload[:sql]
        binds = nil

        proxy = ActiveRecord::Base.connection_handler.retrieve_handler.current_proxy
        connection_pool = proxy.pool_which_owns_connection payload[:connection_id]
        if connection_pool
          role = if proxy.primary_pool? connection_pool
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
          binds = ' ' + payload[:binds].map { |attr| render_bind(attr) }.inspect
        end

        name = colorize_payload_name(name, payload[:name])
        sql = color(sql, sql_color(sql), true)

        debug "#{pool}#{name} #{sql}#{binds}"
      end

      # Take over logging duties from `ActiveRecord::LogSubscriber`.
      def self.hijack_active_record
        self.attach_to :active_record

        subscriber = ActiveSupport::Notifications.notifier.listeners_for('sql.active_record').find do |subscriber|
          ActiveRecord::LogSubscriber === subscriber.instance_eval { @delegate }
        end

        ActiveSupport::Notifications.notifier.unsubscribe(subscriber) if subscriber
      end

      # The below are all private to `ActiveRecord::LogSubscriber` so we have
      # to just copy them wholesale:
      #   https://github.com/rails/rails/blob/314ffecd/activerecord/lib/active_record/log_subscriber.rb#L59-L92

      def colorize_payload_name(name, payload_name)
        if payload_name.blank? || payload_name == "SQL" # SQL vs Model Load/Exists
          color(name, MAGENTA, true)
        else
          color(name, CYAN, true)
        end
      end

      def sql_color(sql)
        case sql
          when /\A\s*rollback/mi
            RED
          when /select .*for update/mi, /\A\s*lock/mi
            WHITE
          when /\A\s*select/i
            BLUE
          when /\A\s*insert/i
            GREEN
          when /\A\s*update/i
            YELLOW
          when /\A\s*delete/i
            RED
          when /transaction\s*\Z/i
            CYAN
          else
            MAGENTA
        end
      end

      def logger
        ActiveRecord::Base.logger
      end
    end
  end

  LogSubscriber = Rails5::LogSubscriber
end
