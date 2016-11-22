$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'rubygems'
require 'active_record'

require 'active_replicas'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.syntax = [ :expect, :should ]
  end
end
