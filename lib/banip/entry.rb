# frozen_string_literal: true

require 'time'
require 'banip/action'

module Banip
  class Entry
    def self.build(cidr_block, slack_link, expire_in = nil, expiration_lambda: DEFAULT_EXPIRATION_LAMBDA)
      new(cidr_block: cidr_block).ban!(slack_link, expire_in, expiration_lambda: expiration_lambda)
    end

    DAY = 24 * 60 * 60
    DEFAULT_EXPIRATION_LAMBDA = lambda do |ban_count|
      case ban_count
      when 0
        0
      when 1
        1 * DAY
      when 2
        2 * DAY
      when 3
        3 * DAY
      when 4
        7 * DAY
      when 5
        14 * DAY
      else
        30 * DAY
      end
    end

    # @param [String]           cidr_block
    # @param [String (ISO8601)] since
    # @param [String (ISO8601)] expire_at
    # @param [Boolean]          expired
    # @param [Integer]          ban_count
    # @param [Array<History>]   histories
    def initialize(cidr_block:, since: nil, expire_at: nil, expired: false, ban_count: 0, histories: [])
      @cidr_block = cidr_block
      @since = since
      @expire_at = expire_at
      @expired = expired
      @ban_count = ban_count
      @histories = histories
      @change = nil
    end

    attr_reader :cidr_block, :since, :expire_at, :expired, :ban_count, :histories, :change

    # @param [String]  slack_link
    # @param [Integer] expire_in
    # @param [Proc]    expiration_lambda
    def ban!(slack_link, expire_in = nil, expiration_lambda: DEFAULT_EXPIRATION_LAMBDA)
      @since = Time.now.iso8601
      @ban_count += 1
      @expired = false
      unless expire_in
        expire_in = expiration_lambda.call(@ban_count)
      end
      @expire_at = (Time.parse(@since) + expire_in).iso8601
      @histories << History.build_ban_history(@since, slack_link)
      @change = Change.build_ban_change(@cidr_block, @ban_count, @expire_at)

      self
    end

    # @param [String] slack_link
    def expire!(slack_link)
      if expired?
        return self
      end

      now = Time.now.iso8601
      @expired = true
      @expire_at = now
      @histories << History.build_expire_history(now, slack_link)
      @change = Change.build_expire_change(@cidr_block, @ban_count, @expire_at)

      self
    end

    def should_expire?
      living? && Time.parse(@expire_at) <= Time.now
    end

    def living?
      !expired?
    end

    def expired?
      @expired
    end

    def as_json
      {
        cidr_block: @cidr_block,
        since: @since,
        expire_at: @expire_at,
        expired: @expired,
        ban_count: @ban_count,
        histories: @histories.map(&:as_json),
      }
    end

    History = Struct.new(:action, :executed_at, :slack_link) do
      def self.build_ban_history(executed_at, slack_link)
        new(Action::BAN, executed_at, slack_link)
      end

      def self.build_expire_history(executed_at, slack_link)
        new(Action::EXPIRE, executed_at, slack_link)
      end

      def as_json
        to_h
      end
    end

    Change = Struct.new(:action, :cidr_block, :ban_count, :expire_at) do
      def self.build_ban_change(cidr_block, ban_count, expire_at)
        new(Action::BAN, cidr_block, ban_count, expire_at)
      end

      def self.build_expire_change(cidr_block, ban_count, expire_at)
        new(Action::EXPIRE, cidr_block, ban_count, expire_at)
      end

      def to_s(decorate: false)
        case action
        when Action::BAN
          prefix = decorate ? ':boom: ' : ''
          "#{prefix}#{self.cidr_block} has been banned until #{self.expire_at} (ban count: #{self.ban_count})"
        when Action::EXPIRE
          prefix = decorate ? ':fire-extinguisher: ' : ''
          "#{prefix}#{self.cidr_block} has expired (ban count: #{self.ban_count})"
        end
      end
    end
  end
end
