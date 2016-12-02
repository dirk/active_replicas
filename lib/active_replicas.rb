require 'active_replicas/version'
require 'active_replicas/log_subscriber'
require 'active_replicas/proxying_connection'
require 'active_replicas/proxying_connection_pool'

if defined? ActiveRecord
  version = ActiveRecord::VERSION::MAJOR

  if version == 4
    require 'active_replicas/rails4/helpers'
    require 'active_replicas/rails4/connection_handler'
  else
    raise "Unsupported ActiveRecord version: #{version}"
  end
end

require 'active_replicas/railtie' if defined? Rails
