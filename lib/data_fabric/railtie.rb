require 'data_fabric'

module DataFabric
  # = DataFabric Railtie
  class Railtie < Rails::Railtie # :nodoc:
    initializer "data_fabric.swap_query_cache_middleware" do |app|
      require 'data_fabric/query_cache'
      app.middleware.swap ActiveRecord::QueryCache, DataFabric::QueryCache
    end

    rake_tasks do
      load "data_fabric/railties/databases.rake"
    end
  end
end
