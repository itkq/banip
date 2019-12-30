# frozen_string_literal: true

require 'sinatra/base'
require 'banip/state_store'
require 'banip/slash_command/handler'
require 'banip/interactive_message/handler'

module Banip
  class App < Sinatra::Base
    configure do
      enable :logging
    end

    helpers do
      def state_store
        @state_store ||= StateStore::S3.new(ENV.fetch('BANIP_REGION'), ENV.fetch('BANIP_S3_BUCKET'), ENV.fetch('BANIP_S3_STATE_KEY'))
      end

      def command_handler
        @command_handler ||= SlashCommand::Handler.new(SlashCommand::Authenticator.new)
      end

      def message_handler
        @message_handler ||= InteractiveMessage::Handler.new(state_store, InteractiveMessage::Authenticator.new)
      end
    end

    post '/slack/command' do
      content_type :json
      command_handler.handle(request)
    end

    post '/slack/message' do
      content_type :json
      message_handler.handle(request)
    end
  end
end
