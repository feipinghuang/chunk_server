require 'goliath'
require 'nokogiri'

class Gziped < Goliath::API
  def response(env)
    path = env["PATH_INFO"]
    [200, {}, { response: FileSystem.new(path).get }]
  end
end
