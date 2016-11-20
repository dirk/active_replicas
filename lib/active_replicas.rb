require 'active_replicas/version'
require 'active_replicas/connection_handler'
require 'active_replicas/log_subscriber'
require 'active_replicas/proxying_connection'
require 'active_replicas/proxying_connection_pool'

module ActiveReplicas
  # Your code goes here...
end

require 'active_replicas/railtie' if defined?(Rails)
