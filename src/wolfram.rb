wolfkey = "V9PYWE-V6345TL3K5"

if ! ARGV[0] 
	puts "no query specified"
	exit(1)
end
query = ARGV[0]



require 'wolfram-alpha'

options = { "format" => "plaintext" } # see the reference appendix in the documentation.[1]

client = WolframAlpha::Client.new wolfkey, options

response = client.query query

input = response["Input"] # Get the input interpretation pod.
result = response.find { |pod| pod.title == "Result" } # Get the result pod.

require 'yaml'
puts "OBJECT: #{response.to_yaml}"
puts "#{input.subpods[0].plaintext} = #{result.subpods[0].plaintext}"