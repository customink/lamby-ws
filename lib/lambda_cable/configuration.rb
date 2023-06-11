module LambdaCable
  class Configuration
    def initialize
      initialize_defaults
    end

    def reconfigure
      instance_variables.each { |var| instance_variable_set var, nil }
      initialize_defaults
      yield(self) if block_given?
      self
    end

    # Number in milliseconds of the interval for the client to send ping type messages over the WebSocket connection.
    # This keeps API Gateway connections from timing out which appear to be around a few minutes. Increase this to 60s (60000)
    # to reduce Lambda invocations. Higher values make reconnects slower.
    #
    def ping_interval
      @ping_interval ||= ::Rack::Builder.new { run ::Rails.application }.to_app
    end

    def ping_interval=(interval)
      @ping_interval = interval
    end

    private

    def initialize_defaults
      @ping_interval = 10000
    end
  end
end
