require 'net/http'
require 'net/https'

require 'fileutils'
require 'cgi'
require 'pstore'
require 'io/console'

require 'json'
require 'date'
require 'dotenv'

Dotenv.load

module Presence

  PRESENCE_HOST        = 'app.presencepro.com'
  PRESENCE_PORT        = 443
  DEBUG                = true
  DATA_DIR             = ENV['DATA_DIR']
  API_KEY              = ENV['API_KEY']

  FILE_REQUEST_PARAMS  = {
    'sortBy'         => 'creationTime',
    'sortCollection' => 'files',
    'sortOrder'      => 'desc'
  }

  def self.fetch_file_ids
    path = '/cloud/json/filesByCount/4?' + hash_to_params(FILE_REQUEST_PARAMS)

    resp = fetch_response(PRESENCE_HOST,PRESENCE_PORT,path)
    resp = JSON.parse( resp.body )

    return [] unless resp['files']

    resp['files'].map{|f| 
      {
        'id' => f['id'],
        'device' => f['device']['desc'],
        'name' => f['name'],
        'date' => f['creationDate']
      }
    }
  end

  def self.hash_to_params(params)
    params.map{|key,val| "#{key}=#{val}" }.join("&")
  end

  # Download file
  def self.download_file(id)
    path = "/cloud/json/files/#{id}?"
    resp = fetch_response(PRESENCE_HOST,PRESENCE_PORT,path)

    resp
  end

  def self.delete_file(id)
    path   = "/cloud/json/files/#{id}?"
    resp   = fetch_response(PRESENCE_HOST,PRESENCE_PORT,path,:delete)

    resp
  end


  def self.fetch_response(host, port, path, verb=:get)
    http = Net::HTTP.new(host, port)
    http.use_ssl = true if port == 443

    # GET request -> so the host can set his cookies
    if verb == :post
      request = Net::HTTP::Post.new(path)
      request.set_form_data(post_data)
    elsif verb == :get
      request = Net::HTTP::Get.new(path)
    elsif verb == :delete
      request = Net::HTTP::Delete.new(path)
    end
    
    request['API_KEY'] = API_KEY
    resp = http.request(request)
    resp
  end

end

puts " ---- "
puts Time.now
puts "Checking for new files"

files = Presence.fetch_file_ids

puts "Found: #{files.size} files"

files.each do |file|

  puts file.inspect

  id     = file['id']
  date   = file['date']
  name   = file['name']
  device = file['device']  

  d = DateTime.parse( date )
  dest_dir = File.join( Presence::DATA_DIR,
                        d.strftime("%Y"),
                        d.strftime("%m"),
                        d.strftime("%d"),
                        device)

  puts dest_dir
  FileUtils.mkdir_p(dest_dir)

  output_file = File.join(dest_dir, name)


  unless File.exists?(output_file)
    puts "File does not exist, downloading to #{output_file}"

    file = Presence.download_file(id)

    File.write(output_file, file.body)

    puts "About to remove file with id: #{id}"
    Presence.delete_file(id)
  end

end
