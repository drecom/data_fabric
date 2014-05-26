require 'active_record/tasks/database_tasks'

module ActiveRecord
  module Tasks
    module DatabaseTasks
      attr_accessor :exclude_data_fabric_shard_regexp
      self.exclude_data_fabric_shard_regexp = /(master|slave|standby)/

      def create_current_data_fabric_cluster(environment = env)
        each_current_data_fabric_cluster_configuration(environment) { |configuration|
          puts "[data_fabric] *** executing to database: #{configuration['database']}"
          create configuration
        }
        ActiveRecord::Base.establish_connection environment
      end

      def drop_current_data_fabric_cluster(environment = env)
        each_current_data_fabric_cluster_configuration(environment) { |configuration|
          puts "[data_fabric] *** executing to database: #{configuration['database']}"
          drop configuration
        }
      end

      def each_current_data_fabric_cluster_connected(environment = env, exclude_pattern = exclude_data_fabric_shard_regexp)
        each_current_data_fabric_cluster_configuration(environment, exclude_pattern) do |configuration|
          ActiveRecord::Base.clear_active_connections!
          ActiveRecord::Base.establish_connection(configuration)
          yield configuration
        end
        ActiveRecord::Base.clear_active_connections!
        ActiveRecord::Base.establish_connection environment
      end

      private

      def each_current_data_fabric_cluster_configuration(environment, exclude_pattern = exclude_data_fabric_shard_regexp)
        environments = [environment]
        environments << 'test' if environment == 'development'
        regexp = Regexp.compile("(#{environments.map {|e| Regexp.escape(e)}.join('|')})")

        configurations = ActiveRecord::Base.configurations.select {|k,v|
          k =~ regexp and (!exclude_pattern or k !~ exclude_pattern) and !environments.include?(k)
        }.values.uniq
        configurations.compact.each do |configuration|
          yield configuration unless configuration['database'].blank?
        end
      end
    end
  end
end
