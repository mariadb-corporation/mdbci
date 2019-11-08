



class NetworkConfigurator

  def initialize(path, logger)
    @logger = logger
    @path = path
    @configuration = Configuration.new(@path)
  end

end
