require 'goliath'
require 'nokogiri'

class Chunk < Goliath::API
  def on_close(env)
    env.logger.info "Connection closed."
  end

  def response(env)
    path = env["PATH_INFO"]
    operation = proc do
      FileSystem.new(path).get do |chunk|
        env.chunked_stream_send(chunk)
      end
    end

    callback = proc do |result|
      env.chunked_stream_close
    end

    EM.defer operation, callback

    headers = { 'Content-Type' => 'text/plain', 'X-Stream' => 'Goliath' }
    chunked_streaming_response(200, headers)
  end
end
