#!/usr/bin/env ruby

require 'faraday'
require 'nokogiri'

class BasicServer

  attr_accessor :server
  attr_accessor :username
  attr_accessor :password

  def initialize(server, username, password)
    @server = server
    @username = username
    @password = password
  end

  def conn
    @conn || Faraday.new(:url => server.to_s) do |faraday|
      faraday.basic_auth username, password
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end
  end

  def get(path)
    conn.get(path)
  end

end

class TapasServer

  attr_accessor :server
  attr_accessor :username
  attr_accessor :password

  def initialize(server, username, password)
    @server = server
    @username = username
    @password = password
  end

  def conn
    @conn || Faraday.new(:url => server.to_s) do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end
  end

  def authenticate
    response = conn.post '/subscriber/login', { username: username, password: password }
    @cookie = response.headers['set-cookie']
  end

  def get(path)
    conn.get(path) do |req|
      req.headers['Cookie'] = @cookie
    end
  end

  def save_file(path)
    response = get(path)
    disposition = response.headers['content-disposition']
    filename = Faraday::Utils.parse_query(disposition)["filename"].gsub(/\"/, '')
    file_data = response.body
    IO.write(filename, file_data)
  end

end

username = ARGV[0]
password = ARGV[1]
uri = URI(ARGV[2])
server = URI::Generic.build(scheme: uri.scheme, host: uri.host, port: uri.port)
file_url = "#{uri.path}?#{uri.query}"

#feed_server = BasicServer.new(server, username, password)
#rss_feed = feed_server.get('/feed').body

#xml_doc = Nokogiri::XML(rss_feed)
xml_doc = Nokogiri::XML(IO.read('feed.xml'))
items = xml_doc.xpath('//item')
items.each do |item|
  children = item.children
  title = (children / 'title').first.child.content
  description = (children / 'description').first.child.content
  description_doc = Nokogiri::HTML(description)
  links = description_doc.css('ul li a')

  links_to_download = links.each_with_object([]) do |link, memo|
    if link['href'] =~ /rubytapas.dpdcart.com\/subscriber\/download/
      memo << { filename: link.content, link: link['href'] }
    end
  end

  puts title
  puts links_to_download
end

#tapas_server = TapasServer.new(server, username, password)
#tapas_server.authenticate
#tapas_server.save_file(file_url)
