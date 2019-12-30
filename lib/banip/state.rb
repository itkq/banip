# frozen_string_literal: true

require 'banip/entry'

module Banip
  class State
    def initialize(hash = {})
      @state = hash.map { |k, v| [k.to_s, Entry.new(**v)] }.to_h
      @entries_to_ban = []
      @entries_to_expire = []
    end

    attr_reader :entries_to_ban, :entries_to_expire

    def ban(cidr_block, slack_link, expire_in_sec)
      entry =
        if @state[cidr_block]
          @state[cidr_block].ban!(slack_link, expire_in_sec)
        else
          Banip::Entry.build(cidr_block, slack_link, expire_in_sec)
        end

      @entries_to_ban << entry
    end

    def expire(cidr_block, slack_link)
      if @state[cidr_block] && @state[cidr_block].living?
        entry = @state[cidr_block]
        @entries_to_expire << entry.expire!(slack_link)
      end
    end

    def update
      @entries_to_expire = []
      @state.each do |_, entry|
        if entry.should_expire?
          @entries_to_expire << entry.expire!(nil)
        end
      end

      !@entries_to_expire.empty?
    end

    def apply!
      @entries_to_ban.each do |entry|
        @state[entry.cidr_block] = entry
      end
      @entries_to_expire.each do |entry|
        @state[entry.cidr_block] = entry
      end
      @changes = @entries_to_ban.map(&:change) + @entries_to_expire.map(&:change)

      @entries_to_ban = []
      @entries_to_expire = []

      self
    end

    def changed?
      !@changes.empty?
    end

    def changes(decorate: false)
      (@changes || []).map { |c| c.to_s(decorate: decorate) }.join("\n")
    end

    def entries
      @state.values
    end

    def to_json
      as_json.to_json
    end

    def as_json
      @state.sort.map { |k, v| [k, v.as_json] }.to_h
    end
  end
end
