require 'data_fabric/connection_proxy'

class ActiveRecord::ConnectionAdapters::ConnectionHandler
  def clear_active_connections_with_data_fabric!
    clear_active_connections_without_data_fabric!
    DataFabric::ConnectionProxy.shard_pools.each_value { |pool| pool.release_connection }
  end
  alias_method_chain :clear_active_connections!, :data_fabric
end

module DataFabric
  module Extensions
    def self.included(model)
      DataFabric.logger.info { "Loading data_fabric #{DataFabric::Version::STRING} with ActiveRecord #{ActiveRecord::VERSION::STRING}" }

      # Wire up ActiveRecord::Base
      model.extend ClassMethods
      ActiveRecord::ConnectionAdapters::ConnectionHandler.instance_exec do
        include ConnectionHandlerExtension
      end
      ConnectionProxy.shard_pools = {}
    end

    module ConnectionHandlerExtension
      extend ActiveSupport::Concern

      included do
        alias_method_chain :pool_for, :data_fabric
      end

      private

      def pool_for_with_data_fabric(owner)
        owner_to_pool.fetch(owner.name) {
          if ancestor_pool = pool_from_any_process_for(owner)
            if ancestor_pool.is_a?(DataFabric::PoolProxy)
              # Use same PoolProxy object
              owner_to_pool[owner.name] = ancestor_pool
            else
              # A connection was established in an ancestor process that must have
              # subsequently forked. We can't reuse the connection, but we can copy
              # the specification and establish a new connection with it.
              establish_connection owner, ancestor_pool.spec
            end
          else
            owner_to_pool[owner.name] = nil
          end
        }
      end
    end

    # Class methods injected into ActiveRecord::Base
    module ClassMethods
      def data_fabric(options)
        DataFabric.logger.info { "Creating data_fabric proxy for class #{name}" }
        pool_proxy = PoolProxy.new(ConnectionProxy.new(self, options))
        klass      = self
        klass_name = name
        DataFabric.shard_class_list << klass

        # Clear current connections
        klass.remove_connection
        ch = connection_handler

        ch.class_to_pool.clear if defined?(ch.class_to_pool)
        ch.send(:class_to_pool)[klass_name] = ch.send(:owner_to_pool)[klass_name] = pool_proxy
      end

      def multi_shard_transaction(*args, &block)
        raise unless block_given?
        klass = args.shift

        options = args.last.is_a?(Hash) ? args.pop : {}

        klass.transaction(options) do
          if args.empty?
            block.call
          else
            multi_shard_transaction(*args, options, &block)
          end
        end
      end

      def all_shard_transaction(options = {}, &block)
        class_list = DataFabric.shard_class_list.uniq
        multi_shard_transaction(*class_list, options, &block)
      end
    end
  end
end
