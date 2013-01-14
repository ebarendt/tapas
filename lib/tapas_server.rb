require 'faraday'

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
