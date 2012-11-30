#!/usr/bin/env ruby

require 'faraday'
require 'nokogiri'

class TapasServer

  attr_accessor :server
  attr_accessor :username
  attr_accessor :password

  def initialize(server, username, password)
    @server = server
    @username = username
    @password = password
  end

  def fetch_feed
    conn(true).get('/feed').body
  end

  def save_file(directory, file_name, file_path)
    puts "Saving to #{file_name}"
    response = get(file_path)
    file_data = response.body
    save_path = File.join(directory, file_name)
    IO.write(save_path, file_data)
  end

  private

  def get(path)
    authenticate
    conn.get(path) do |req|
      req.headers['Cookie'] = @cookie
    end
  end

  def authenticate
    @cookie ||= conn.post('/subscriber/login', { username: username, password: password }).headers['set-cookie']
  end

  def conn(basic = false)
    @conn ||= {}
    @conn[basic] ||= Faraday.new(:url => server.to_s) do |faraday|
      faraday.basic_auth(username, password) if basic
      faraday.request  :url_encoded             # form-encode POST params
      # faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end
  end

end

def extract_links_to_download(server, feed)
  xml_doc = Nokogiri::XML(feed)
  items = xml_doc.xpath('//item')
  items.map do |item|
    children = item.children
    title = (children / 'title').first.child.content
    description = (children / 'description').first.child.content
    description_doc = Nokogiri::HTML(description)
    links = description_doc.css('ul li a')

    links_to_download = links.each_with_object([]) do |link, memo|
      if link['href'] =~ /rubytapas.dpdcart.com\/subscriber\/download/
        memo << { filename: link.content, link: link['href'].gsub(/#{server}/, '') }
      end
    end

    { title: title, links: links_to_download }
  end
end

def download_episode(episode, tapas_server)
  Dir.mkdir("downloads") unless File.directory?("downloads")
  directory = File.join("downloads", episode[:title])
  return if episode[:links].empty? || File.directory?(directory)

  puts "Downloading #{episode[:title]}..."
  Dir.mkdir(directory)
  episode[:links].each do |link|
    tapas_server.save_file(directory, link[:filename], link[:link])
  end
end

username = ARGV[0]
password = ARGV[1]
server = "https://rubytapas.dpdcart.com"

unless username && password
  puts "username and password are required"
  exit(1)
end

tapas_server = TapasServer.new(server, username, password)
feed = tapas_server.fetch_feed
extract_links_to_download(server, feed).each do |episode|
  download_episode(episode, tapas_server)
end
