set :user, 'cheekymo'
set :repository, "git@github.com:cmonkey/tracks.git"

task :production do
  setup_production_access
  #set :repository, "#{user}@#{domain}:/home/#{user}/git/#{application}.git"
  set :deploy_to, "/home/#{user}/apps/#{application}"
end

task :stage do
  set :application, 'tracks.stage'
  set :domain, 'stage.tracks.org.nz'
  #set :repository, "#{user}@#{domain}:/home/#{user}/git/tracks.git"
  set :deploy_to, "/home/#{user}/apps/#{application}"
  role :app, domain
  role :web, domain
  role :db, domain, :primary => true
end

set :scm, :git
set :scm_username, user
set :runner, user
#set :scm_verbose, true
set :use_sudo, false
set :branch, "master"
set :deploy_via, :checkout
set :git_shallow_clone, 1

set :chmod755, "app config db lib public vendor script script/* public/disp*"

set :group_writable, false
default_run_options[:pty] = true

namespace :deploy do

  task :start, :roles => :app do
#    run "rm -rf /home/#{user}/public_html/#{domain};ln -s #{current_path}/public /home/#{user}/public_html/#{domain}"
  end

  task :restart, :roles => :app do
    run "pkill -9 -u #{user} dispatch.fcgi"
  end

end

after 'deploy:symlink', 'deploy:finishing_touches'

namespace :deploy do
  task :finishing_touches, :roles => :app do
    run "cp -pf #{deploy_to}/to_copy/environment.rb #{current_path}/config/environment.rb"
    run "cp -pf #{deploy_to}/to_copy/database.yml #{current_path}/config/database.yml"
    run "cp -pf #{deploy_to}/to_copy/.htaccess #{current_path}/public/.htaccess"
    run "ln -s #{deploy_to}/shared/paths #{current_path}/public/paths"
  end
end


namespace :backup do
  before 'backup:db', 'setup_production_access'
  task :default do
    db
  end

  desc "Initiate a backup of the production database"
  task :db, :roles => :db do
    run "cd tmp; ./mybackupit.sh"
  end
end


task :setup_production_access do
  set :application, 'tracks'
  set :domain, 'tracks.org.nz'
  role :app, domain
  role :web, domain
  role :db, domain, :primary => true
end
