#!/usr/bin/env ruby

require 'faraday'

username = ARGV[0]
password = ARGV[1]
uri = URI(ARGV[2])
server = URI::Generic.build(scheme: uri.scheme, userinfo: uri.userinfo, host: uri.host, port: uri.port).to_s
file_url = "#{uri.path}?#{uri.query}"

conn = Faraday.new(:url => server) do |faraday|
  faraday.request  :url_encoded             # form-encode POST params
  faraday.response :logger                  # log requests to STDOUT
  faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
end

response = conn.post '/subscriber/login', { username: username, password: password }
cookie = response.headers['set-cookie']

response = conn.get(file_url) do |req|
  req.headers['Cookie'] = cookie
end
disposition = response.headers['content-disposition']
filename = Faraday::Utils.parse_query(disposition)["filename"].gsub(/\"/, '')
file_data = response.body
IO.write(filename, file_data)
