# frozen_string_literal: true

require 'ipaddr'

require 'banip/action'
require 'banip/slash_command/error'
require 'banip/slash_command/command'

module Banip
  module SlashCommand
    class Builder
      class InvalidActionError < Error; end
      class InvalidCidrBlockError < Error; end
      class InvalidExpireInError < Error; end

      def self.build(action:, cidr_blocks:, expire_in:)
        new(action: action, cidr_blocks: cidr_blocks, expire_in: expire_in).build
      end

      def initialize(action:, cidr_blocks:, expire_in:)
        @action = action
        @cidr_blocks = cidr_blocks
        @expire_in = expire_in
      end

      def build
        validate_action!
        validate_cidr_blocks!
        normalize_cidr_blocks!
        convert_expire_in_to_second!

        Command.new(action: @action, cidr_blocks: @cidr_blocks, expire_in_sec: @expire_in_sec)
      end

      def validate_action!
        unless Command::PERMITTED_ACTIONS.include?(@action)
          raise InvalidActionError.new("permitted actions are: #{Command::PERMITTED_ACTIONS.join("|")}")
        end
      end

      def validate_cidr_blocks!
        if !@cidr_blocks || @cidr_blocks.empty?
          raise InvalidCidrBlockError.new("at least one cidr_block is required")
        end

        @cidr_blocks.each do |cidr_block|
          begin
            IPAddr.new(cidr_block)
          rescue IPAddr::InvalidAddressError
            raise InvalidCidrBlockError.new("#{cidr_block} is invalid address")
          end
        end
      end

      def normalize_cidr_blocks!
        @cidr_blocks.map! do |c|
          ip = IPAddr.new(c)
          "#{ip}/#{ip.prefix}"
        end
      end

      def convert_expire_in_to_second!
        if @action != Action::BAN && @expire_in
          raise InvalidExpireInError.new("#{@action} does not take expire_in")
        end

        unless @expire_in
          @expire_in_sec = nil
          return
        end

        @expire_in_sec = 0
        @expire_in.scan(/(\d+)([d])/) do |n, u|
          scale = {
            "d" => 60 * 60 * 24,
          }[u]

          @expire_in_sec += n.to_i * scale
        end

        if @expire_in_sec == 0
          raise InvalidExpireInError.new("#{@expire_in} is invalid expire_in. Use \d+d")
        end
      end
    end
  end
end
