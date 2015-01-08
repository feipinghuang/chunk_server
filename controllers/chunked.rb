require 'goliath'
require 'nokogiri'

class Chunked < Goliath::API
  def on_close(env)
    env.logger.info "Connection closed."
  end

  def response(env)
    path = env["PATH_INFO"]
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
end
