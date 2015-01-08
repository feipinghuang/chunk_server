#
# require 'goliath/api'
# require 'goliath/runner'
#
# Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
# Dir[File.dirname(__FILE__) + '/controllers/*.rb'].each {|file| require file }
#
# require 'rack'
#
# router = Rack::Builder.new do
#   map '/chunked' do
#     use Goliath::Rack::Params
#     run Chunked.new
#   end
#
#   map '/gziped' do
#     use ::Rack::ContentLength
#     use ::Rack::Deflater
#     # run Gziped.new
#     run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
#   end
#
#   map '/' do
#     use ::Rack::ContentLength
#     run Proc.new {|env| [200, {"Content-Type" => "text/html"}, ["Try /chunks/*.html"]]}
#   end
# end
#
# runner = Goliath::Runner.new(ARGV, nil)
# runner.app = router
# runner.run


require 'goliath'
require 'nokogiri'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

class Server < Goliath::API
  use ::Rack::Deflater, :if => lambda { |env, status, headers, body| env["PATH_INFO"] =~ /^\/gziped\/(.*\.html)/}

  def on_close(env)
    env.logger.info "Connection closed."
  end

  def response(env)
    case env["PATH_INFO"]
    when /^\/chunked\/(.*\.html)/
      chunk(env, $1)
    when /^\/gziped\/(.*\.html)/
      gzip(env, $1)
    end

  end

  def chunk(env, path)
    operation = proc do
      FileSystem.new(path).get_chunked do |chunk|
        env.chunked_stream_send(chunk)
      end
    end

    callback = proc do |result|
      env.chunked_stream_close
    end

    EM.defer operation, callback

    headers = { 'Content-Type' => 'text/html', 'X-Stream' => 'Goliath' }
    chunked_streaming_response(200, headers)
  end

  def gzip(env, path)
    headers = { 'Content-Type' => 'text/html', 'X-Stream' => 'Goliath' }
    [200, headers, [FileSystem.new(path).get]]
  end
end
