require 'spec_helper'

is_rails4 = ActiveRecord::VERSION::MAJOR == 4

describe ActiveReplicas::Rails4::ConnectionHandler, if: is_rails4 do
  subject { ActiveReplicas::Rails4::ConnectionHandler }

  before do
    @handler = subject.new proxy_configuration: {
                             primary: { url: 'sqlite3:tmp/primary.sqlite3' },
                             replicas: {
                               default0: { url: 'sqlite3:tmp/replica_default0.sqlite3' }
                             }
                           }
  end

  describe '#remove_connection' do
    it "turns off reconnects, disconnects, and returns the primary's config" do
      primary_config = { adapter: 'sqlite3', database: 'tmp/primary.sqlite3' }

      spec = double 'connection specification', config: primary_config

      @handler.establish_connection nil, spec

      config = @handler.remove_connection nil
      expect(config).to eq(primary_config)
    end
  end

  describe '#initialize' do
    before do
      @primary_pool = double 'primary connection pool'
      @replica_pool = double 'replica connection pool'

      allow(ActiveReplicas::Rails4::Helpers).to receive(:connection_pool_for_spec) do |spec|
        case spec
        when :primary then @primary_pool
        when :replica then @replica_pool
        else raise "Un-stubbed connection specification: #{spec}"
        end
      end

      @subject = subject.new proxy_configuration: {
                               primary: :primary,
                               replicas: { default0: :replica }
                             }
    end
  end
end
