Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/controllers/*.rb'].each {|file| require file }

router = Rack::Builder.new do
  map '/chunks' do
    use Goliath::Rack::Params
    run Chunk.new
  end
  map '/' do
    use ::Rack::ContentLength
    run Proc.new {|env| [200, {"Content-Type" => "text/html"}, ["Try /chunks/*.html"]]}
  end
end

runner = Goliath::Runner.new(ARGV, nil)
runner.app = router
runner.run
