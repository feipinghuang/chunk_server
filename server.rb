require 'goliath'
require 'nokogiri'
require "zlib"
require "time"  # for Time.httpdate
require 'rack'
require 'stringio'

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

class Server < Goliath::API
  # use ::Rack::Deflater, if: proc { |env| env["PATH_INFO"] =~ /^\/gziped\// }

  def on_close(env)
    env.logger.info "Connection closed."
  end

  def response(env)
    case env["PATH_INFO"]
    when /^\/chunked\/(.*\.html)/
      chunk(env, $1)
    when /^\/gziped\/(.*\.html)/
      gzip(env, $1)
    when /^\/gziped_chunked\/(.*\.html)/
      gzip_chunk(env, $1)
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

  def gzip_chunk(env, path)
    operation = proc do
      FileSystem.new(path).get_chunked do |chunk|
        env.chunked_stream_send(gzip_string(chunk))
      end
    end

    callback = proc do |result|
      env.chunked_stream_close
    end

    EM.defer operation, callback

    headers = { 'Content-Type' => 'text/html', 'Content-Encoding' => "gzip", 'X-Stream' => 'Goliath' }
    chunked_streaming_response(200, headers)
  end

  def gzip(env, path)
    headers = { 'Content-Type' => 'text/html', 'Content-Encoding' => "gzip", 'X-Stream' => 'Goliath' }

    [200, headers, [gzip_string(FileSystem.new(path).get)]]
  end

  def gzip_string(str)
    s = StringIO.new("")
    gzip = ::Zlib::GzipWriter.new(s)
    gzip.write(str)
    gzip.flush
    gzip.close
    s.string
  end
end
