require 'data_fabric'

module DataFabric
  # = DataFabric Railtie
  class Railtie < Rails::Railtie # :nodoc:
    initializer "data_fabric.swap_query_cache_middleware" do |app|
      if ActiveRecord::VERSION::STRING < "3.1"
        require 'data_fabric/old_query_cache_ext'
      end
      require 'data_fabric/query_cache'
      app.middleware.swap ActiveRecord::QueryCache, DataFabric::QueryCache
    end
  end
end
