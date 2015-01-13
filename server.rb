require 'goliath'
require 'tilt'
require "zlib"
require 'rack'
require 'stringio'
require 'erb'

class Server < Goliath::API
  # use ::Rack::Deflater, if: proc { |env| env["PATH_INFO"] =~ /^\/gziped\// }
  use Goliath::Rack::Params
  use(Rack::Static,                     # render static files from ./public
      :root => Goliath::Application.app_path("public"),
      :urls => ["/favicon.ico", '/stylesheets', '/javascripts', '/images'])

  @@request_count = Hash.new(0)
  @@current_path = "/"

  def request_count
    (@@request_count[@@current_path] += 1) % 10
  end

  def on_close(env)
    env.logger.info "Connection closed."
  end

  def response(env)
    case @@current_path = env["PATH_INFO"]
    when /^\/chunked\/(.*\.html)/
      handle(views_path($1)) { |path| chunk(env, path) }
    when /^\/gziped\/(.*\.html)/
      handle(views_path($1)) { |path| gzip(env, path) }
    when /^\/gziped_chunked\/(.*\.html)/
      handle(views_path($1)) { |path| gzip_chunk(env, path) }
    when /^\/(.*\.html)/
      handle(views_path($1)) { |path| ordinary(env, path) }
    else
      raise Goliath::Validation::NotFoundError
    end
  end

  def ordinary(env, path)
    [200, {}, [render(path)]]
  end

  def chunk(env, path)
    content=render(path)
    operation = proc do
      split_html(content).each do |chunk|
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
    io = StringIO.new
    io.binmode
    gzip = Zlib::GzipWriter.new(io)
    content=render(path)
    operation = proc do
      split_html(content).each do |chunk|
        env.chunked_stream_send(compress(gzip, io, chunk))
        io.truncate(0)
        io.rewind
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

    [200, headers, [compress(gzip, io, render(path))]]
  ensure
    gzip.close
  end

  def views_path(path)
    File.dirname(__FILE__) + '/views/' + path
  end

  def render(path)
    data = File.read(path)
    template = Tilt['erb'].new(nil, nil, {}){ data }
    template.render self
  end

  def compress(gzip, io, data)
    gzip.write(data)
    gzip.flush
    io.string.force_encoding('binary')
  end

  # def split_html(html)
  #   doc = Nokogiri::HTML(html)
  #   splited = []
  #   bf = 0
  #   b = doc.css('.split')
  #   puts html.length
  #   puts b.length
  #   b.each_with_index do |split, index|
  #     puts bf
  #     splited << html[bf...(bf=html.index(split.to_s))]
  #   end
  #   splited << html[bf..-1]
  #   splited
  # end

  def split_html(html)
    html.split("<!-- split -->")
  end

  def handle(path)
    if File.exist?(path)
      yield path
    else
      [404, {}]
    end
  end
end
