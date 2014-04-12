require 'capistrano'
require 'capistrano-unicorn'
require 'rvm/capistrano'

GITHUB_REPOSITORY_NAME = 'lopezlawn'
LINODE_SERVER_HOSTNAME = 'www.lopezlawnandlandscape.com'

set :bundle_flags, '--deployment'
set :application, 'lopezlawnandlandscape.com'
set :deploy_to, '/var/www/apps/lopez'
set :normalize_asset_timestamps, false
set :rails_env, 'production'
set :rvm_ruby_string, :local

set :user, 'root'
set :runner, 'www-data'
set :admin_runner, 'www-data'

ssh_options[:keys] = ['~/.ssh/id_rsa']

set :scm, :git
set :repository, "git@github.com:arturo-c/#{GITHUB_REPOSITORY_NAME}.git"
set :branch, 'master'
set :unicorn_pid, "#{deploy_to}/current/tmp/unicorn.pid"

# Roles
role :app, LINODE_SERVER_HOSTNAME

# Setup Symlinks
#   that should be created after each deployment
symlink_configuration = [
    %w(config/database.yml    config/database.yml),
    %w(db/production.sqlite3  db/production.sqlite3),
    %w(public/system                 public/system)
]

deploy.task :restart, :roles => :app do
  # Fix Permissions

  sudo "chown -R www-data:www-data #{current_path}"
  sudo "chown -R www-data:www-data #{latest_release}"
  sudo "chown -R www-data:www-data #{shared_path}/log"

  # Restart Application
  unicorn.restart
  sudo "ln -nfs #{release_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
end

# Add Configuration Files & Compile Assets
after 'deploy:update_code' do
  # Compile Assets
  run "cd #{release_path}; RAILS_ENV=production; bundle install; rake assets:precompile"
end

#
# Helper Methods
#
# Application Specific Tasks
#   that should be performed at the end of each deployment
def application_specific_tasks
  # system 'cap deploy:whenever:update_crontab'
  # system 'cap deploy:delayed_job:stop'
  # system 'cap deploy:delayed_job:start n=1'
  # system 'cap deploy:run_command command='ls -la''
end

def create_tmp_file(contents)
  system 'mkdir tmp'
  file = File.new("tmp/#{domain}", 'w')
  file << contents
  file.close
end

namespace :deploy do
  desc 'Initializes a bunch of tasks in order after the last deployment process.'
  task :restart do
    puts '\n\n=== Running Custom Processes! ===\n\n'
    create_production_log
    setup_symlinks
    application_specific_tasks
    set_permissions
    unicorn.restart
  end

  desc 'Sets permissions for Rails Application'
  task :set_permissions do
    puts '\n\n=== Setting Permissions! ===\n\n'
    run "chown -R www-data:www-data #{deploy_to}"
    run "chmod -R 766 #{deploy_to}"
  end

  desc 'Creates the production log if it does not exist'
  task :create_production_log do
    unless File.exist?(File.join(shared_path, 'log', 'production.log'))
      puts '\n\n=== Creating Production Log! ===\n\n'
      run "touch #{File.join(shared_path, 'log', 'production.log')}"
    end
  end

  desc 'Creates symbolic links from shared folder'
  task :setup_symlinks do
    puts '\n\n=== Setting up Symbolic Links! ===\n\n'
    symlink_configuration.each do |config|
      #run "ln -nfs #{File.join(shared_path, config[0])} #{File.join(release_path, config[1])}"
    end
  end
end

namespace :appconfig do
  desc 'Copy application config'
  task :copy do
    #upload 'config/application.yml', "#{shared_path}/application.yml", :via => :scp
  end

  desc 'Link the application.yml in the release_path'
  task :symlink do
    #run "test -f #{release_path}/config/application.yml || ln -s #{shared_path}/application.yml #{release_path}/config/application.yml"
  end
end

namespace :db do

  desc 'Syncs the database.yml file from the local machine to the remote machine'
  task :sync_yaml do
    puts '\n\n=== Syncing database yaml to the production server! ===\n\n'
    unless File.exist?('config/database.yml')
      puts 'There is no config/database.yml.\n '
      exit
    end
    upload 'config/database.yml', "#{shared_path}/config/database.yml", :via => :scp
  end

  desc 'Create Production Database'
  task :create do
    puts '\n\n=== Creating the Production Database! ===\n\n'
    run "cd #{current_path}; rake db:create RAILS_ENV=production"
    system 'cap deploy:set_permissions'
  end

  desc 'Migrate Production Database'
  task :migrate do
    puts '\n\n=== Migrating the Production Database! ===\n\n'
    run "cd #{current_path}; rake db:migrate RAILS_ENV=production"
    system 'cap deploy:set_permissions'
  end

  desc 'Resets the Production Database'
  task :migrate_reset do
    puts '\n\n=== Resetting the Production Database! ===\n\n'
    run "cd #{current_path}; rake db:migrate:reset RAILS_ENV=production"
  end

  desc 'Destroys Production Database'
  task :drop do
    puts '\n\n=== Destroying the Production Database! ===\n\n'
    run "cd #{current_path}; rake db:drop RAILS_ENV=production"
    system 'cap deploy:set_permissions'
  end

  desc 'Moves the SQLite3 Production Database to the shared path'
  task :move_to_shared do
    puts '\n\n=== Moving the SQLite3 Production Database to the shared path! ===\n\n'
    run "mv #{current_path}/db/production.sqlite3 #{shared_path}/db/production.sqlite3"
    system 'cap deploy:setup_symlinks'
    system 'cap deploy:set_permissions'
  end

  desc 'Populates the Production Database'
  task :seed do
    puts '\n\n=== Populating the Production Database! ===\n\n'
    run "cd #{current_path}; rake db:seed RAILS_ENV=production"
  end

end


after 'deploy:update_code', 'appconfig:copy'
after 'deploy:update_code', 'appconfig:symlink'
