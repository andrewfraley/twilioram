package 'build-essential'
package 'ruby'
package 'ruby-dev'
package 'git'
gem_package "sinatra"
gem_package "sinatra-reloader"
gem_package "wolfram-alpha"
gem_package "twilio-ruby"

application 'twilioram' do
  path '/opt/twilioram'
  repository 'https://github.com/andrewfraley/twilioram.git'
  nginx_load_balancer do
    hosts ['localhost']
    application_port 4567
  end
end
