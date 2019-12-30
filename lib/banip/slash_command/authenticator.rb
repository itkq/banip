# frozen_string_literal: true

require 'banip/slash_command/error'

module Banip
  module SlashCommand
    class Authenticator
      class NotAuthenticatedError < Error; end

      # override to implement the original validation
      def authenticate_requester!(request)
      end
    end
  end
end
