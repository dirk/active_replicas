require 'active_record/connection_adapters/abstract/query_cache'

module ActiveReplicas
  class ProxyingConnectionPool
    delegate :connection_cache_key, :disable_query_cache!,
      :enable_query_cache!, :query_cache_enabled,
      to: :current_pool
  end
end
