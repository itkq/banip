# frozen_string_literal: true

require 'banip/slack/validator'
require 'banip/interactive_message/authenticator'
require 'banip/interactive_message/parser'
require 'banip/interactive_message/renderer'
require 'banip/interactive_message/request'

module Banip
  module InteractiveMessage
    class Handler
      def initialize(state_store, authenticator)
        @state_store = state_store
        @authenticator = authenticator
      end

      def handle(raw_request)
        if slack_validator && !slack_validator.valid_signature?(raw_request)
          return [401, {}, "invalid signagure"]
        end

        req = Request.new(raw_request)
        renderer = Renderer.new(req)

        handler =
          if req.action.approved?
            :handle_approval
          elsif req.action.rejected?
            :handle_rejection
          elsif req.action.cancelled?
            :handle_cancellation
          end

        json = self.send(handler, renderer, req)
        puts json

        json
      end

      private

      def handle_approval(renderer, req)
        begin
          @authenticator.authenticate_approver!(req)
        rescue Authenticator::Error => e
          return Renderer.render_error(e)
        end

        result = Parser.parse(req.payload).execute(@state_store, req.original_message_link)
        renderer.render_approved_message(result)
      end

      def handle_rejection(renderer, req)
        begin
          @authenticator.authenticate_rejector!(req)
        rescue Authenticator::Error => e
          return Renderer.render_error(e)
        end

        renderer.render_rejected_message
      end

      def handle_cancellation(renderer, req)
        begin
          @authenticator.authenticate_canceller!(req)
        rescue Authenticator::Error => e
          return Renderer.render_error(e)
        end

        renderer.render_cancelled_message
      end

      def slack_validator
        @slack_validator ||=
          if ENV['BANIP_SLACK_SIGNING_SECRET']
            Slack::Validator.new(ENV['BANIP_SLACK_SIGNING_SECRET'])
          end
      end
    end
  end
end
