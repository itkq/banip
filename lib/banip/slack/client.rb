# frozen_string_literal: true

require 'slack-ruby-client'

module Slack
  class Client
    def self.build
      new(token: ENV.fetch('BANIP_SLACK_TOKEN'))
    end

    DEFAULT_CHANNEL = ENV.fetch('BANIP_SLACK_CHANNEL', '#banip')

    def initialize(token:)
      @token = token
    end

    def list_usergroups_users(usergroup)
      # raise Slack::Web::Api::Errors::SlackError if usergroup is invalid
      client.usergroups_users_list(usergroup: usergroup, include_disabled: false)["users"]
    end

    def chat_post_message(text, channel: DEFAULT_CHANNEL)
      client.chat_postMessage(channel: channel, text: text)
    end

    private

    def client
      @client = Slack::Web::Client.new(token: @token)
    end
  end
end
