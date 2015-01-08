class FileSystem
  CHUNKSIZE = 100

  def initialize(uri)
    @uri  = uri
  end

  def get
    open(root_path + @uri, "rb") do |file|
      yield file.read(CHUNKSIZE) until file.eof?
    end
  end

  def root_path
    File.dirname(__FILE__) + '/../views'
  end
end
