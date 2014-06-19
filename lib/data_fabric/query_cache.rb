require 'active_record/query_cache'

module DataFabric
  class QueryCache < ActiveRecord::QueryCache
    def call(env)
      enabled       = ActiveRecord::Base.connection.query_cache_enabled
      connection_id = ActiveRecord::Base.connection_id
      klasses = DataFabric::ConnectionProxy.shard_pools.values
      klasses.each do |k|
        k.connection.enable_query_cache!
      end

      response = @app.call(env)
      response[2] = Rack::BodyProxy.new(response[2]) do
        restore_query_cache_settings(connection_id, enabled)
      end

      response
    rescue Exception => e
      restore_query_cache_settings(connection_id, enabled)
      raise e
    end

    private

    def restore_query_cache_settings(connection_id, enabled)
      klasses = DataFabric::ConnectionProxy.shard_pools.values
      klasses.each do |k|
        ActiveRecord::Base.connection_id = connection_id
        k.connection.clear_query_cache
        k.connection.disable_query_cache! unless enabled
      end
    end
  end
end
