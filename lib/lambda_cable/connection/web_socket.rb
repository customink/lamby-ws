require 'aws-sdk-apigatewaymanagementapi'

module LambdaCable
  module Connection
    class WebSocket
      include LambdaCable::RackEnvConcerns

      def initialize(env, event_target)
        @env, @event_target = env, event_target
        @dynamodb = LambdaCable::Server::ConnectionsDb.new(env)
      end

      def possible?
        true
      end

      def alive?
        LambdaCable.logger.debug "[DEBUG] LambdaCable::Connection::WebSocket#alive? connection_id: #{connection_id}"
        resp = client.get_connection connection_id: connection_id
        resp.status_code == 200
      rescue Aws::ApiGatewayManagementApi::Errors::GoneException,
             Aws::ApiGatewayManagementApi::Errors::Http410Error
        # TODO: Should we call close here?
        false
      end

      def transmit(data)
        LambdaCable.logger.debug "[DEBUG] LambdaCable::Connection::WebSocket#transmit connection_id: #{connection_id} data: #{data.inspect}"
        client.post_to_connection data: data, connection_id: connection_id
      rescue Aws::ApiGatewayManagementApi::Errors::GoneException,
             Aws::ApiGatewayManagementApi::Errors::Http410Error => e
        close
      end

      def close
        LambdaCable.logger.debug "[DEBUG] LambdaCable::Connection::WebSocket#close connection_id: #{connection_id}"
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
        @client ||= begin
          LambdaCable.logger.debug "[DEBUG] LambdaCable::Connection::WebSocket#client apigw_endpoint: #{apigw_endpoint}"
          Aws::ApiGatewayManagementApi::Client.new region: ENV['AWS_REGION'], endpoint: apigw_endpoint
        end
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
