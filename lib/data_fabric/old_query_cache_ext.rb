require 'active_record/connection_adapters/query_cache'

module ActiveRecord
  module ConnectionAdapters
    module QueryCache
      def enable_query_cache!
        @query_cache_enabled = true
      end

      def disable_query_cache!
        @query_cache_enabled = false
      end
    end
  end
end
