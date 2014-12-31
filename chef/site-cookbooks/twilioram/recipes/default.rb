package 'build-essential'
package 'ruby'
package 'ruby-dev'
gem_package "sinatra"
gem_package "wolfram-alpha"
gem_package "twilio-ruby"

application "twilioram" do
  path "/opt/twilioram/source"
  action :none

  nginx_load_balancer do
    hosts ['foo.bar.com']
  end
end
