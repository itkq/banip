# frozen_string_literal: true

require 'banip/slack/response'

module Banip
  module SlashCommand
    class Renderer
      def self.render_error(error)
        Slack::Response.new(
          response_type: "ephemeral",
          text: "An error occurred: #{error}",
        ).to_json
      end

      def initialize(request, command)
        @request = request
        @command = command
      end

      def render_approval_request
        text = <<-EOS
<@#{user_id}> wants to *#{@command.action} CIDRs* under the following conditions:
#{command.to_code_block}
        EOS

        Slack::Response.new(
          response_type: "in_channel",
          text: text,
          attachments: [
            Slack::Attachment.new(
              text: ENV.fetch('BANIP_APPROVAL_REQUEST_TEXT', "*Approval Request*"),
              fallback: "TBD",
              callback_id: "banip_approval_request",
              color: "#3AA3E3",
              attachment_type: "default",
              actions: [
                Slack::Action.approve_button,
                Slack::Action.reject_button,
                Slack::Action.cancel_button,
              ]
            ),
          ],
        ).to_json
      end

      def user_id
        @request.user_id
      end
    end
  end
end
