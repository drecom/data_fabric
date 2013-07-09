require 'active_record/query_cache'

module DataFabric
  class QueryCache
    class BodyProxy # :nodoc:
      def initialize(original_cache_value, target, connection_id)
        @original_cache_value = original_cache_value
        @target               = target
        @connection_id        = connection_id
      end

      def method_missing(method_sym, *arguments, &block)
        @target.send(method_sym, *arguments, &block)
      end

      def respond_to?(method_sym, include_private = false)
        super || @target.respond_to?(method_sym)
      end

      def each(&block)
        @target.each(&block)
      end

      def close
        @target.close if @target.respond_to?(:close)
      ensure
        klasses = [ActiveRecord::Base, *DataFabric::ConnectionProxy.shard_pools.values]
        if ActiveRecord::VERSION::STRING >= '3.1'
          ActiveRecord::Base.connection_id = @connection_id
        end
        klasses.each do |k|
          k.connection.clear_query_cache
          unless @original_cache_value
            k.connection.disable_query_cache!
          end
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      old = ActiveRecord::Base.connection.query_cache_enabled
      klasses = [ActiveRecord::Base, *DataFabric::ConnectionProxy.shard_pools.values]
      klasses.each do |k|
        k.connection.enable_query_cache!
      end

      status, headers, body = @app.call(env)
      connection_id = if ActiveRecord::Base.respond_to?(:connection_id)
                        ActiveRecord::Base.connection_id
                      end
      [status, headers, BodyProxy.new(old, body, connection_id)]
    rescue Exception => e
      klasses.each do |k|
        k.connection.clear_query_cache
        unless old
          k.connection.disable_query_cache!
        end
      end
      raise e
    end
  end
end
