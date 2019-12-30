require 'banip/state'

DAY = 24 * 60 * 60
RSpec.describe Banip::State do
  describe '#apply!' do
    let(:cidr_block) { '192.0.2.1/32' }
    let(:slack_link) { 'dummy' }
    let(:expire_in_sec) { DAY }
    let(:now) { Time.local(2019, 12, 31, 17, 0, 0) }
    subject(:state) { described_class.new }

    context 'when there is an entry to ban' do
      around do |example|
        Timecop.freeze(now) do
          state.ban(cidr_block, slack_link, expire_in_sec)
          example.run
        end
      end

      it 'bans the entry' do
        state.apply!
        expect(state.changes).to include("#{cidr_block} has been banned until #{(now + DAY).iso8601} (ban count: 1)")
        entry = state.entries.find { |e| e.cidr_block == cidr_block }
        expect(entry).not_to be_nil
      end
    end

    context 'when there is an entry to expire' do
      around do |example|
        Timecop.freeze(now) do
          state.ban(cidr_block, slack_link, expire_in_sec)
          state.apply!
          state.expire(cidr_block, slack_link)
          example.run
        end
      end

      it 'expire the entry' do
        state.apply!
        expect(state.changes).to include("#{cidr_block} has expired (ban count: 1)")
        entry = state.entries.find { |e| e.cidr_block == cidr_block }
        expect(entry).not_to be_nil
        expect(entry.expired).to eq(true)
      end
    end
  end
end
