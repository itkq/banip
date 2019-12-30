# frozen_string_literal: true

require 'aws-sdk-wafregional'
require 'banip/ban_updater/base'

module Banip
  module BanUpdater
    class WAF < Base
      def initialize(region, ip_set_id)
        @region = region
        @ip_set_id = ip_set_id
      end

      def update(state)
        ip_set_descriptors_to_be_inserted = living_entries(state).map { |e| entry_to_ip_set_descriptor(e) } - ip_set.ip_set_descriptors
        ip_set_descriptors_to_be_deleted = ip_set.ip_set_descriptors - living_entries(state).map { |e| entry_to_ip_set_descriptor(e) }

        if ip_set_descriptors_to_be_inserted.empty? && ip_set_descriptors_to_be_deleted.empty?
          return false
        end

        updates = ip_set_descriptors_to_be_inserted.map { |d| { action: 'INSERT', ip_set_descriptor: d } } + \
          ip_set_descriptors_to_be_deleted.map { |d| { action: 'DELETE', ip_set_descriptor: d } }

        waf_regional.update_ip_set(
          change_token: waf_regional.get_change_token.change_token,
          ip_set_id: @ip_set_id,
          updates: updates,
        )

        true
      end

      def description
        "Update ip_set for Web ACL"
      end

      private

      def living_entries(state)
        state.entries.select(&:living?).sort_by(&:cidr_block)
      end

      def ip_set
        waf_regional.get_ip_set(ip_set_id: @ip_set_id).ip_set
      end

      def entry_to_ip_set_descriptor(entry)
        if IPAddr.new(entry.cidr_block).ipv4?
          Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: entry.cidr_block)
        else
          Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV6', value: entry.cidr_block)
        end
      end

      def waf_regional
        @waf_regional ||= Aws::WAFRegional::Client.new(region: @region)
      end
    end
  end
end
