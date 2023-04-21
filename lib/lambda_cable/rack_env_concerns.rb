module LambdaCable
  # This module allows various classes to access the Lambda event and context. Some classes use
  # the Rack environment `env` which relies on Lamby's assignment of the Lambda event and context 
  # into the Rack environment. Other classes use the Lambda `event` and `context` directly.
  # 
  module RackEnvConcerns
    extend ActiveSupport::Concern
    
    private

    def apigw_id
      request_context['apiId']
    end

    def apigw_endpoint
      "https://#{request_context['domainName']}/#{request_context['stage']}"
    end

    def route_key
      @route_key ||= begin
        key = request_context['routeKey'].sub '$', ''
        ActiveSupport::StringInquirer.new(key)
      end
    end
    

    def connection_id
      request_context['connectionId']
    end

    def request_context
      lambda_event['requestContext']
    end

    def lambda_event
      defined?(event) ? event : env[Lamby::Rack::LAMBDA_EVENT]
    end

    def lambda_context
      defined?(context) ? context : env[Lamby::Rack::LAMBDA_CONTEXT]
    end

    def lambda_cable_message
      lambda_event['body']
    end

    def lambda_rack_env
      Lamby::RackRest.new(event_to_cable, context).env
    end

    # When the connect happens, it is a proxy from API Gateway which only has a stage path, 
    # not a real path. Because of this we have to append the cable mount path to the Lambda
    # event prior to letting Lamby.cmd handle the request. This way we get the full Rails 
    # and Lamby lifecycle as though API Gateway's WebSocket was talking to Rails directly.
    #
    def event_to_cable
      mount_path = ActionCable.server.config.mount_path || '/cable'
      lambda_event.dup.tap do |e|
        e['path'] ||= mount_path
        e['httpMethod'] ||= 'GET'
        e['requestContext'].merge!({
          "resourcePath": mount_path
        })
        # e['headers'] ||= {}
        # e['headers'].merge!(event_to_cable_headers)
      end
    end

    def event_to_cable_headers
      return {} if route_key.connect? 
      origin = ActionCable.server.config.allowed_request_origins.first || apigw_endpoint
      { 'Orgin' => origin }
    end
  end
end
