# frozen_string_literal: true

require 'banip/slash_command/parser'

module Banip
  class CLI
    def initialize(state_store, ban_updaters)
      @state_store = state_store
      @ban_updaters = ban_updaters
    end

    def start
      loop do
        print '> '
        input = STDIN.gets&.chomp
        if input.nil?
          exit 0
        end

        case input
        when 'show state'
          puts JSON.pretty_generate(@state_store.fetch_state.as_json)
          next
        when 'help'
          puts SlashCommand::Parser.help
          next
        when 'exit'
          exit 0
        end

        command =
          begin
            SlashCommand::Parser.parse(input)
          rescue SlashCommand::Error => e
            puts e.message
            next
          end
        puts command.execute(@state_store, @ban_updaters, slack_link)
      end
    end

    private

    def slack_link
      ENV.fetch('SLACK_LINK', 'https://example.slack.com/archives/C11111111/p2222222222222222')
    end
  end
end
