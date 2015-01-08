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
      open(views_path + path, "rb") do |file|
        until file.eof?
          env.chunked_stream_send(file.read(100))
        end
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
    io = StringIO.new
    io.binmode
    gzip = Zlib::GzipWriter.new(io)

    operation = proc do
      open(views_path + path, "rb") do |file|
        until file.eof?
          content = file.read(100)
          content = compress(gzip, io, content)
          env.chunked_stream_send(content)
          io.truncate(0)
          io.rewind
        end
        gzip.close
      end
    end

    callback = proc do |result|
      env.chunked_stream_close
    end

    EM.defer operation, callback

    headers = { 'Content-Type' => 'text/html',
                'Content-Encoding' => "gzip",
                'X-Stream' => 'Goliath' }
    chunked_streaming_response(200, headers)
  end

  def gzip(env, path)
    io = StringIO.new
    io.binmode
    gzip = Zlib::GzipWriter.new(io)
    headers = { 'Content-Type' => 'text/html', 'Content-Encoding' => "gzip", 'X-Stream' => 'Goliath' }

    [200, headers, [compress(gzip, io, FileSystem.new(path).get)]]
  ensure
    gzip.close
  end

  def views_path
    File.dirname(__FILE__) + '/views/'
  end

  def compress(gzip, io, data)
    gzip.write(data)
    gzip.flush
    io.string.force_encoding('binary')
  end
end
