require 'spec_helper'

describe ActiveReplicas::ProxyingConnection do
  subject { ActiveReplicas::ProxyingConnection }

  describe '#delegate_to' do
    let(:method) { :some_method }
    let(:args)   { [ double('argument') ] }

    before do
      @proxying_pool = double 'proxying connection pool'
      @connection = double 'connection'
      @primary_connection = double 'primary connection'

      @proxying_pool.stub primary_connection: @primary_connection

      @subject = subject.new connection: @connection,
                             proxy: @proxying_pool,
                             is_primary: is_primary
    end

    describe 'when proxing primary' do
      let(:is_primary) { true }

      it 'always uses own connection' do
        expect(@connection).to receive(method).with(*args).twice

        @subject.delegate_to :primary, method, *args
        @subject.delegate_to :replica, method, *args
      end
    end

    describe 'when proxying replica' do
      let(:is_primary) { false }

      it 'uses primary if primary role requested' do
        expect(@primary_connection).to receive(method).with(*args)

        @subject.delegate_to :primary, method, *args
      end

      it 'uses primary if proxying pool is using primary' do
        @proxying_pool.stub using_primary?: true

        expect(@primary_connection).to receive(method).with(*args)

        # Requesting the replica role to ensure it ignores it.
        @subject.delegate_to :replica, method, *args
      end

      it 'uses own connection by default' do
        @proxying_pool.stub using_primary?: false

        expect(@connection).to receive(method).with(*args)

        @subject.delegate_to :replica, method, *args
      end
    end
  end
end
