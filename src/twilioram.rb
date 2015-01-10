WOLFKEY = 'V9PYWE-V6345TL3K5'
GOOGLEKEY = 'AIzaSyAaVeupY5Rm6kt6ITUhIMfkHWUpjDVyelM'

require 'sinatra'
require 'sinatra/reloader'
require 'wolfram-alpha'
require 'twilio-ruby'
require 'open-uri'
require 'json'


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
    		wavfile = save_audio(params['RecordingUrl'])
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

def save_audio(url)
	# Download the twilio audio to a file with UTC timstamp in the name plus a random number to avoid naming conflicts
	# (We could probably use the RecordingSID instead)
	time = Time.now.getutc
	randnum = rand(100...1000)
	wavfile = "/tmp/twilio-#{time}-#{randnum}.wav"
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

# 404
not_found do
  'But our princess is in another castle...'
end