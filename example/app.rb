# Based off an example single-file Rails application:
#   https://gist.github.com/shawndrost/1629835

require 'rails/all'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_replicas'

require 'logger'
Rails.logger = ActiveRecord::Base.logger = Logger.new STDOUT

class Tester < Rails::Application
  config.secret_key_base = 'abc123'
end

ActiveReplicas::Railtie.hijack_active_record primary: { url: 'mysql2://root@localhost/active_replicas' },
                                             replicas: {
                                               replica0: { url: 'mysql2://root@localhost/active_replicas' }
                                             }

# require 'sqlite3'
# database_file = File.join(File.dirname(__FILE__), 'test.sqlite3')
# SQLite3::Database.new(database_file).tap do |database|
#   database.execute("drop table users;") rescue nil
#   database.execute("create table users (id integer primary key autoincrement, email varchar(100), server_id integer);")
# end
# ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: database_file

class User < ActiveRecord::Base
end

class UsersController < ActionController::Base
  def index
    # Will go to the primary but will let subsequent queries use replicas.
    count = User.connection.with_primary { User.count }

    # Will go to a replica.
    users = User.all.map(&:email)

    User.transaction do
      # This will go to the primary.
      User.create! email: Time.now.to_s
    end

    # Will also go to the primary since we didn't explicitly use the
    # `with_primary` wrapper.
    last_user = User.last&.email

    render text: { count: count, users: users, last_user: last_user }.inspect
  end
end

Tester.routes.draw do
  root to: 'users#index'
end
