# -*- coding: utf-8 -*-
require 'active_record'
require 'data_fabric'
require 'data_fabric/sharded_database_tasks'

db_namespace = namespace :db do
  desc 'Create data_fabric databases config/database.yml for the current Rails.env'
  task :create => [:load_config] do
    unless ENV['DATABASE_URL']
      ActiveRecord::Tasks::DatabaseTasks.create_current_data_fabric_cluster
    end
  end

  desc 'Drops data_fabric databases for the current Rails.env (use db:drop:all to drop all databases)'
  task :drop => [:load_config] do
    unless ENV['DATABASE_URL']
      ActiveRecord::Tasks::DatabaseTasks.drop_current_data_fabric_cluster
    end
  end

  desc "Migrate data_fabric databases (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task :migrate => [:environment, :load_config] do
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true

    ActiveRecord::Tasks::DatabaseTasks.each_current_data_fabric_cluster_connected do |configuration|
      puts "[data_fabric] *** Migrating database: #{configuration['database']}"
      ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths, ENV["VERSION"] ? ENV["VERSION"].to_i : nil) do |migration|
        ENV["SCOPE"].blank? || (ENV["SCOPE"] == migration.scope)
      end
      db_namespace['_dump'].invoke
    end
  end
end
