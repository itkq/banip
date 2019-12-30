# frozen_string_literal: true

require 'banip/action'
require 'banip/slack/client'

module Banip
  module SlashCommand
    class Command
      PERMITTED_ACTIONS = [Action::BAN, Action::EXPIRE].freeze

      def self.new_from_original_message(message)
        original_json = JSON.parse(
          message.slice(CODE_BLOCK_JSON_REGEX, 1).strip, symbolize_names: true,
        )
        new(**original_json)
      end

      CODE_BLOCK_JSON_REGEX = /```([^`]+)```/.freeze

      def initialize(action:, cidr_blocks:, expire_in_sec: nil)
        @action = action
        @cidr_blocks = cidr_blocks
        @expire_in_sec = expire_in_sec
      end

      attr_reader :action

      def execute(state_store, ban_updaters, slack_link)
        state = state_store.fetch_state

        case @action
        when Action::BAN
          @cidr_blocks.each do |cidr_block|
            state.ban(cidr_block, slack_link, @expire_in_sec)
          end
        when Action::EXPIRE
          @cidr_blocks.each do |cidr_block|
            state.expire(cidr_block, slack_link)
          end
        end

        state.apply!

        if state.changed?
          state_store.upload(state)
          Slack::Client.build.chat_post_message(state.changes(decorate: true))
        end

        result =
          if state.changed?
            "#{state.changes}\n"
          else
            "State has not changed.\n"
          end

        result + ban_updaters.map { |updater| ban_update(updater, state) }.join("\n")
      end

      def to_code_block
        <<-EOS
```
#{JSON.pretty_generate(self.to_h)}
```
        EOS
      end

      def to_h
        h = {
          action: @action,
          cidr_blocks: @cidr_blocks,
        }

        if @action == BAN_ACTION
          h.merge!(expire_in_sec: @expire_in_sec)
        end

        h
      end

      private

      def ban_update(ban_updater, state)
        begin
          if ban_updater.update(state)
            "#{ban_updater.description} (#{@action}): Succeeded"
          else
            "#{ban_updater.description} (#{@action}): No change"
          end
        rescue => e
          "#{ban_updater.description} (#{@action}): Failed (#{e.message})"
        end
      end
    end
  end
end
