require 'sinatra'
require 'sinatra/reloader'
require 'wolfram-alpha'
require 'twilio-ruby'
require 'open-uri'
require 'json'
require 'cgi'

require_relative 'apikeys'

set :bind, '0.0.0.0'

# Handle text messages
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

# Entry point for voice questions, setup a recording
get '/voice-question' do
	response = Twilio::TwiML::Response.new do |r|
		r.Say	"Hello, please ask a question."
		r.Record 	:maxLength => '4', 
					:action => '/voice-question/handle-record',
					:method => 'get',
					:timeout => '2'
	end
	response.text
end

# Handle the recording by downloading it, transcribing it, then sending the query to WolframAlpha
get '/voice-question/handle-record' do
	if params['RecordingUrl']
		wavfile = save_audio(params['RecordingUrl'], params['RecordingSid'])
		delete_message(params['RecordingSid'])
		query = transcribe_speech(wavfile)
		File.delete(wavfile)
		if query
			answer = ask_wolf(query)
		    redirect '/voice-question/handle-repeat?answer=' + CGI.escape(answer) + '&query=' + CGI.escape(query)
		end
	end
	redirect '/voice-question/error'
end

# Speak the results to the user
get '/voice-question/handle-repeat' do
	Twilio::TwiML::Response.new do |r|
		action = '/voice-question/handle-repeat-options?answer=' + CGI.escape(params['answer']) + '&query=' + CGI.escape(params['query'])
		r.Gather :numDigits => '1', :action => action, :method => 'get' do |g|
			if params['query'] && params['answer']
				r.Say params['query']
				r.Say "Answer."
	   			r.Say params['answer']
				r.Say "Press 1 to repeat the answer."
				r.Say "Press 2 to ask a new question."
			else
				redirect '/voice-question'
			end
		end
	end.text
end

# Handle the option menu
get '/voice-question/handle-repeat-options' do
	if params['Digits'] == '2'
		redirect '/voice-question'
	end
	redirect '/voice-question/handle-repeat?answer=' + CGI.escape(params['answer']) + '&query=' + CGI.escape(params['query'])
end

# Whoops!
get '/voice-question/error' do
	Twilio::TwiML::Response.new do |r|
		r.Say 'Sorry, an error has occured.'
	end.text
end

# Retrieve the wave file from Twilio
def save_audio(url, sid)
	# Name the file with the RecordingSid from Twilio
	wavfile = "/tmp/#{sid}.wav"
	File.open(wavfile, "wb") do |file|
		file.write open(url).read
	end
	return wavfile
end

# Upload the wave file to the Google Speech API
def transcribe_speech(wavfile)
	apiurl = "https://www.google.com/speech-api/v2/recognize?output=json&lang=en-us&key=#{GOOGLEKEY}"
	command = "curl -X POST --data-binary @'#{wavfile}' --header 'Content-Type: audio/l16; rate=8000;' '#{apiurl}'"
	response = `#{command}`
	if response 
		transcript = parse_google_speech(response)
		if transcript 
			return transcript
		end
	end
	return false
end

# Get the transcribed text from the Google Speech response
def parse_google_speech(response)
	# The google speech api doesn't return valid JSON, we have to clean it up
	json = response.split('{"result":[]}')[1]
	if valid_json(json)
		result = JSON.parse(json)
		transcript = result['result'][0]['alternative'][0]['transcript']
		return transcript
	end
	return false
end

# Connect to WolframAlpha and submit a query, return the answer
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

# Delete recording message from Twilio
def delete_message(sid)
	@client = Twilio::REST::Client.new ACCOUNT_SID, AUTH_TOKEN
	@client.recordings.get(sid).delete()
end

# Catches json parsing errors
def valid_json(string)  
	JSON.parse(string)  
	return true  
	rescue JSON::ParserError  
	return false  
end 


# Landing page - Sinatra seems really slow about serving static files,
# serve them up through nginx instead
get "/" do
  redirect '/public/'
end

# 404
not_found do
  'But our princess is in another castle...'
end