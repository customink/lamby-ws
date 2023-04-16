require 'aws-sdk-apigatewaymanagementapi'

module LambdaCable
  module Connection
    class WebSocket
      include LambdaCable::RackEnvConcerns

      def initialize(env, event_target)
        @env, @event_target = env, event_target
        @dynamodb = LambdaCable::Connection::DynamoDb.new(env)
      end

      def possible?
        true
      end

      def alive?
        resp = client.get_connection connection_id: connection_id
        resp.status_code == 200
      rescue Aws::ApiGatewayManagementApi::Errors::GoneException,
             Aws::ApiGatewayManagementApi::Errors::Http410Error
        false
      end

      def transmit(data)
        client.post_to_connection data: data, connection_id: connection_id
      rescue Aws::ApiGatewayManagementApi::Errors::GoneException,
             Aws::ApiGatewayManagementApi::Errors::Http410Error => e
        close
      end

      def close
        dynamodb.close
        client.delete_connection connection_id: connection_id
      rescue Aws::ApiGatewayManagementApi::Errors::GoneException,
             Aws::ApiGatewayManagementApi::Errors::Http410Error
      end

      def protocol
        'wss'
      end

      def rack_response
        open
        [ 200, rack_response_headers, [] ]
      end

      private
      
      attr_reader :env, :event_target, :dynamodb

      def open
        dynamodb.open
        event_target.on_open
      end

      def client
        @client ||= Aws::ApiGatewayManagementApi::Client.new(
          region: ENV['AWS_REGION'], 
          endpoint: apigw_endpoint
        )
      end

      def rack_response_headers
        protocols = lambda_event.dig 'headers', 'Sec-WebSocket-Protocol'
        return {} unless protocols
        protocol = protocols.split(',').first { |p| ActionCable::INTERNAL[:protocols].include? p }
        protocol ? { 'Sec-WebSocket-Protocol' => protocol } : {}
      end
    end
  end
end
