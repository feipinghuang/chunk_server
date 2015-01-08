require 'goliath'
require 'nokogiri'
require "zlib"
require 'rack'
require 'stringio'

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
      split_html(File.read(views_path + path)).each do |chunk|
        env.chunked_stream_send(chunk)
        sleep 0.5
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
      split_html(File.read(views_path + path)).each do |chunk|
        env.chunked_stream_send(compress(gzip, io, chunk))
        io.truncate(0)
        io.rewind
        sleep 0.5
      end
      gzip.close
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

  def split_html(html)
    doc = Nokogiri::HTML(html)
    splited = []
    bf = 0
    doc.css('.split').each_with_index do |split, index|
      splited << html[bf...(bf=html.index(split.to_s))]
    end
    splited << html[bf..-1]
    splited
  end
end
