require 'goliath'
require 'nokogiri'

class Gziped < Goliath::API
  def response(env)
    path = env["PATH_INFO"]
    env.stream_send FileSystem.new(path).get
    env.stream_close
    [200, {}, Goliath::Response::STREAMING]
  end
end
