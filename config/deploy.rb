require 'capistrano'
require 'capistrano-unicorn'
require 'rvm/capistrano'

GITHUB_REPOSITORY_NAME = 'lopezlawn'
LINODE_SERVER_HOSTNAME = 'www.lopezlawnandlandscape.com'

set :bundle_flags,               '--deployment'
set :application,                'lopez'
set :deploy_to,                  '/var/www/apps/lopez'
set :normalize_asset_timestamps, false
set :rails_env,                  'production'
set :rvm_ruby_string, :local

set :user,                       'root'
set :runner,                     'www-data'
set :admin_runner,               'www-data'

ssh_options[:keys] = ['~/.ssh/id_rsa']

set :scm,        :git
set :repository, 'git@github.com:arturo-c/#{GITHUB_REPOSITORY_NAME}.git'
set :branch,     'master'

# Roles
role :app, LINODE_SERVER_HOSTNAME

# Add Configuration Files & Compile Assets
after 'deploy:update_code' do
  # Compile Assets
  run "cd #{release_path}; RAILS_ENV=production; bundle install; rake assets:precompile"
end

deploy.task :restart, :roles => :app do
  # Fix Permissions
  sudo "chown -R www-data:www-data #{current_path}"
  sudo "chown -R www-data:www-data #{latest_release}"
  sudo "chown -R www-data:www-data #{shared_path}/log"

  # Restart Application
  unicorn.restart
  #sudo "ln -nfs #{release_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
end

namespace :mongoid do
  desc "Copy mongoid config"
  task :copy do
    upload "config/mongoid.yml", "#{shared_path}/mongoid.yml", :via => :scp
  end

  desc "Link the mongoid config in the release_path"
  task :symlink do
    run "test -f #{release_path}/config/mongoid.yml || ln -s #{shared_path}/mongoid.yml #{release_path}/config/mongoid.yml"
  end

  desc "Create MongoDB indexes"
  task :index do
    run "cd #{current_path} && rake db:mongoid:create_indexes", :once => true
  end
end

namespace :appconfig do
  desc "Copy application config"
  task :copy do
    upload "config/application.yml", "#{shared_path}/application.yml", :via => :scp
  end

  desc "Link the application.yml in the release_path"
  task :symlink do
    run "test -f #{release_path}/config/application.yml || ln -s #{shared_path}/application.yml #{release_path}/config/application.yml"
  end
end


after "deploy:update_code", "appconfig:copy"
after "deploy:update_code", "appconfig:symlink"
