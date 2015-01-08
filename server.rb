
require 'goliath/api'
require 'goliath/runner'

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/controllers/*.rb'].each {|file| require file }

require 'rack'

router = Rack::Builder.new do
  map '/chunked' do
    use Goliath::Rack::Params
    run Chunked.new
  end

  map '/gziped' do
    use ::Rack::Deflater
    use ::Rack::ContentLength
    use Goliath::Rack::Params
    run Gziped.new
  end

  map '/' do
    use ::Rack::ContentLength
    run Proc.new {|env| [200, {"Content-Type" => "text/html"}, ["Try /chunks/*.html"]]}
  end
end

runner = Goliath::Runner.new(ARGV, nil)
runner.app = router
runner.run
