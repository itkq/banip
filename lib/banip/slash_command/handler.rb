# frozen_string_literal: true

require 'banip/slack/validator'
require 'banip/slash_command/authenticator'
require 'banip/slash_command/error'
require 'banip/slash_command/parser'
require 'banip/slash_command/renderer'
require 'banip/slash_command/request'

module Banip
  module SlashCommand
    class Handler
      def initialize(authenticator)
        @authenticator = authenticator
      end

      def handle(raw_request)
        if slack_validator && !slack_validator.valid_signature?(raw_request)
          return [401, {}, "invalid signagure"]
        end

        req = Request.new(raw_request)

        begin
          @authenticator.authenticate_requester!(req)
          command = Parser.parse(req.text)
        rescue Error => e
          return Renderer.render_error(e)
        end

        json = Renderer.new(req, command).render_approval_request
        puts json

        json
      end

      private

      def slack_validator
        @slack_validator ||=
          if ENV['BANIP_SLACK_SIGNING_SECRET']
            Slack::Validator.new(ENV['BANIP_SLACK_SIGNING_SECRET'])
          end
      end
    end
  end
end
