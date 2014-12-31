require 'sinatra'
require 'sinatra/reloader'
require 'wolfram-alpha'
require 'twilio-ruby'


set :bind, '0.0.0.0'

get '/question' do
	query = params[:Body]
	if query
		answer = ask_wolf params[:Body]
		twiml = Twilio::TwiML::Response.new do |r|
	    	r.Message answer
	  	end
	 	twiml.text
	end	
end

not_found do
  'But our princess is in another castle...'
end

def ask_wolf(query)
	wolfkey = "V9PYWE-V6345TL3K5"
	options = { "format" => "plaintext" }
	client = WolframAlpha::Client.new wolfkey, options
	response = client.query query
	input = response["Input"]

	result = response.find { |pod| pod.title == "Result" }
	if result
		return "#{result.subpods[0].plaintext}"
	else
		return "Unable to fufill query :/"
	end
end


