package 'build-essential'
package 'ruby'
package 'ruby-dev'
package 'git'
gem_package "sinatra"
gem_package "sinatra-reloader"
gem_package "wolfram-alpha"
gem_package "twilio-ruby"
gem_package "daemons"

# User to run Sinatra
daemon_user = "twilioram"

# Path to place the app using the Chef applications cookbook
app_path = '/opt/twilioram'

# Path to main script run by the daemon
app_entry = "#{app_path}/current/src/twilioram.rb"

# Sinatra stdout log file
app_log = "/tmp/twilioram.log"

# Path to daemon control script
daemon_control = "#{app_path}/twilioram_daemon.rb"
 
user daemon_user do
	action :create
end

# Deploy the application from the github repo and setup nginx
# to proxy to sinatra 
application 'twilioram' do
  path app_path
  repository 'https://github.com/andrewfraley/twilioram.git'
  nginx_load_balancer do
    hosts ['localhost']
    application_port 4567
    set_host_header true
    static_files "/public" => "src/public"
  end
end

# Create symlink to apikeys.rb
link "#{app_path}/current/src/apikeys.rb" do
	to "#{app_path}/apikeys.rb"
end

# Template for the daemon control script
template daemon_control do
	source 'twilioram_daemon.rb.erb'
	variables ({
			:app_entry => app_entry,
			:app_log => app_log
		})
end

# Template for the init script to start the daemon
template "/etc/init.d/twilioram" do
	mode "0755"
	source 'twilioram_init.erb'
	variables ({
			:daemon_user => daemon_user,
			:daemon_control => daemon_control
		})
end

service "twilioram" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action [ :enable, :start ]
end
