require "zlib"
require 'stringio'
class FileSystem
  CHUNKSIZE = 100

  def initialize(uri)
    @uri  = uri
  end

  def get_chunked
    open(root_path + @uri, "rb") do |file|
      yield file.read(CHUNKSIZE) until file.eof?
    end
  end

  def get
    File.read(root_path + @uri)
  end

  def root_path
    File.dirname(__FILE__) + '/../views/'
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
