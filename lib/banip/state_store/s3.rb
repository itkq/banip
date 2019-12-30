# frozen_string_literal: true

require 'banip/state'
require 'banip/state_store/base'
require 'aws-sdk-s3'

module Banip
  module StateStore
    class S3
      def initialize(s3_region, s3_bucket, s3_key)
        @s3 = Aws::S3::Client.new(region: s3_region)
        @s3_bucket = s3_bucket
        @s3_key = s3_key
      end

      def fetch_state
        Banip::State.new(JSON.parse(@s3.get_object(bucket: @s3_bucket, key: @s3_key).body.read, symbolize_names: true))
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::AccessDenied
        Banip::State.new
      end

      def upload(state)
        @s3.put_object(bucket: @s3_bucket, key: @s3_key, content_type: 'application/json', body: state.to_json)
      end
    end
  end
end
