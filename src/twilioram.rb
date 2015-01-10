require 'sinatra'
require 'sinatra/reloader'
require 'wolfram-alpha'
require 'twilio-ruby'


set :bind, '0.0.0.0'

get '/sms-question' do
	query = params[:Body]
	if query
		answer = ask_wolf params[:Body]
		twiml = Twilio::TwiML::Response.new do |r|
	    	r.Message answer
	  	end
	 	twiml.text
	end	
end

get '/voice-question' do
	Twilio::TwiML::Response.new do |r|
		r.Gather :numDigits => '1', :action => '/voice-question/handle-gather', :method => 'get' do |g|
			r.Say "Hello, press 2 to ask a question."
		end
	end.text
end

get 'voice-question/handle-gather' do
	if params['Digits'] == '1'
		response = Twilio::TwiML::Response.new do |r|
			r.Record :maxLength => '30', :action => '/voice-question/handle-record', :method => 'get'
		end
	else
		redirect '/voice-question'
	end
	response.text
end

 
get '/voice-question/handle-record' do
	Twilio::TwiML::Response.new do |r|
		if params['RecordingUrl']
    		`wget #{params['RecordingUrl']}`
    	end
	end.text
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


