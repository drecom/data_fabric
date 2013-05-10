# -*- coding: utf-8 -*-
require 'active_record'
require 'data_fabric'
require 'data_fabric/sharded_database_tasks'

db_namespace = namespace :db do
  Rake.application.lookup('db:create').clear
  desc 'Create the database from DATABASE_URL or config/database.yml for the current Rails.env (use db:create:all to create all dbs in the config)'
  task :create => [:load_config] do
    if ENV['DATABASE_URL']
      ActiveRecord::Tasks::DatabaseTasks.create_database_url
    else
      ActiveRecord::Tasks::DatabaseTasks.create_current_cluster
    end
  end

  Rake.application.lookup('db:drop').clear
  desc 'Drops the database using DATABASE_URL or the current Rails.env (use db:drop:all to drop all databases)'
  task :drop => [:load_config] do
    if ENV['DATABASE_URL']
      ActiveRecord::Tasks::DatabaseTasks.drop_database_url
    else
      ActiveRecord::Tasks::DatabaseTasks.drop_current_cluster
    end
  end

  Rake.application.lookup('db:migrate').clear
  desc "Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task :migrate => [:environment, :load_config] do
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true

    ActiveRecord::Tasks::DatabaseTasks.each_current_cluster_connected do |configuration|
      puts "*** Migrating database: #{configuration['database']}"
      ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths, ENV["VERSION"] ? ENV["VERSION"].to_i : nil) do |migration|
        ENV["SCOPE"].blank? || (ENV["SCOPE"] == migration.scope)
      end
      db_namespace['_dump'].invoke
    end
  end
end
