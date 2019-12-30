# frozen_string_literal: true

require 'banip/slash_command/error'
require 'banip/slash_command/builder'

module Banip
  module SlashCommand
    class Parser
      class ParseError < Error; end

      def self.parse(text)
        new.parse(text)
      end

      def self.help
        '(ban|expire) cidr_blocks [expire_in (optional, e.g. 3d)]'
      end

      def parse(text)
        elems = text.split(" ")

        if elems.size > 3
          raise ParseError.new("too many arguments")
        end

        action, cidr_blocks_str, expire_in = elems

        cidr_blocks = []
        if cidr_blocks_str
          cidr_blocks = cidr_blocks_str.split(",")
        end

        SlashCommand::Builder.build(
          action: action,
          cidr_blocks: cidr_blocks,
          expire_in: expire_in,
        )
      end
    end
  end
end
