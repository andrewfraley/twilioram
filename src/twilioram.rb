require 'sinatra'
require 'sinatra/reloader'
require 'wolfram-alpha'
require 'twilio-ruby'
require 'open-uri'
require 'json'

require_relative 'apikeys'

set :bind, '0.0.0.0'

get '/sms-question' do
	query = params[:Body]
	if query
		answer = ask_wolf(params[:Body])
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

get '/voice-question/handle-gather' do
	if params['Digits'] == '2'
		response = Twilio::TwiML::Response.new do |r|
			r.Record 	:maxLength => '6', 
						:action => '/voice-question/handle-record',
						:method => 'get',
						:timeout => '1'
		end
	else
		redirect '/voice-question'
	end
	response.text
end
 
get '/voice-question/handle-record' do
	Twilio::TwiML::Response.new do |r|
		if params['RecordingUrl']
    		wavfile = save_audio(params['RecordingUrl'], params['RecordingSid'])
    		delete_message(params['RecordingSid'])
    		r.Say "Please wait."
    		query = transcribe_speech(wavfile)
    		File.delete(wavfile)
    		if query
				answer = ask_wolf(query)
				r.Say query
				r.Say "Answer."
			    r.Say answer
			end	
    	end
	end.text
end

def save_audio(url, sid)
	# Name the file with the RecordingSid from Twilio
	wavfile = "/tmp/#{sid}.wav"
	File.open(wavfile, "wb") do |file|
		file.write open(url).read
	end
	return wavfile
end

def transcribe_speech(wavfile)
	apiurl = "https://www.google.com/speech-api/v2/recognize?output=json&lang=en-us&key=#{GOOGLEKEY}"
	command = "curl -X POST --data-binary @'#{wavfile}' --header 'Content-Type: audio/l16; rate=8000;' '#{apiurl}'"
	response = `#{command}`
	transcript = parse_google_speech(response)
	if transcript 
		return transcript
	end
	return "Sorry, something went wrong"
end


def parse_google_speech(response)
	# The google speech api doesn't return valid JSON, we have to clean it up
	json = response.split('{"result":[]}')[1]
	result = JSON.parse(json)
	transcript = result['result'][0]['alternative'][0]['transcript']
	return transcript
end

def ask_wolf(query)
	options = { "format" => "plaintext" }
	client = WolframAlpha::Client.new WOLFKEY, options
	response = client.query query
	input = response["Input"]

	result = response.find { |pod| pod.title == "Result" }
	if result
		return "#{result.subpods[0].plaintext}"
	else
		return "Sorry, unable to process query"
	end
end

def delete_message(sid)
	@client = Twilio::REST::Client.new ACCOUNT_SID, AUTH_TOKEN
	@client.recordings.get(sid).delete()
end

# 404
not_found do
  'But our princess is in another castle...'
end