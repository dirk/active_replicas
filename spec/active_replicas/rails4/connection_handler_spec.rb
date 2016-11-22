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
      @handler.establish_connection nil, nil

      config = @handler.remove_connection nil
      expect(config).to eq({ adapter: 'sqlite3', database: 'tmp/primary.sqlite3' })
    end
  end
end
