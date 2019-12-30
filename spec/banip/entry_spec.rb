require 'banip/entry'

DAY = 24 * 60 * 60
RSpec.describe Banip::Entry do
  describe '#build' do
    let(:cidr_block) { '192.0.2.1/32' }
    let(:slack_link) { 'dummy' }

    context 'when expire_in is passed' do
      let(:expire_in) { 3 * DAY }
      subject(:entry) { described_class.build(cidr_block, slack_link, expire_in) }

      it 'returns an entry initialized with specified expire_in' do
        expect(entry.change).not_to be_nil
      end
    end

    context 'when expiration_lambda is passed' do
      let(:expiration_lambda) { lambda { |ban_count| ban_count == 1 ? 3 * DAY : 0 } }
      subject(:entry) { described_class.build(cidr_block, slack_link, expiration_lambda: expiration_lambda) }

      it 'returns an entry initialized with specified expiration_lambda' do
        expect(entry.change).not_to be_nil
      end
    end

    context 'without any specification about expiration' do
      subject(:entry) { described_class.build(cidr_block, slack_link) }

      it 'returns an entry initialized with DEFAULT_EXPIRATION_LAMBDA' do
        expect(entry.change).not_to be_nil
      end
    end
  end

  describe '#ban!' do
    let(:cidr_block) { '192.0.2.1/32' }
    let(:slack_link) { 'dummy' }
    let(:built_time) { Time.local(2019, 12, 31, 17, 0, 0) }
    let(:now) { built_time + DAY }

    context 'when entry has been already banned' do
      around do |example|
        Timecop.freeze(built_time) do
          @entry = described_class.build(cidr_block, slack_link)
        end

        Timecop.freeze(now) do
          example.run
        end
      end

      it 'bans an entry again' do
        @entry.ban!(slack_link)
        expect(@entry.cidr_block).to eq(cidr_block)
        expect(@entry.since).to eq(now.iso8601)
        expect(@entry.expired).to eq(false)
        expect(@entry.expire_at).to eq((now + 2 * DAY).iso8601)
        expect(@entry.ban_count).to eq(2)

        last_history = @entry.histories.last
        expect(last_history.action).to eq(Banip::Action::BAN)
        expect(last_history.executed_at).to eq(now.iso8601)
        expect(last_history.slack_link).to eq(slack_link)

        change = @entry.change
        expect(change.action).to eq(Banip::Action::BAN)
        expect(change.cidr_block).to eq(cidr_block)
        expect(change.ban_count).to eq(2)
        expect(change.expire_at).to eq(@entry.expire_at)
      end
    end

    context 'when entry has expired' do
      around do |example|
        Timecop.freeze(built_time) do
          @entry = described_class.build(cidr_block, slack_link)
          @entry.expire!(slack_link)
        end

        Timecop.freeze(now) do
          example.run
        end
      end

      it 'bans an entry' do
        @entry.ban!(slack_link)
        expect(@entry.cidr_block).to eq(cidr_block)
        expect(@entry.since).to eq(now.iso8601)
        expect(@entry.expired).to eq(false)
        expect(@entry.expire_at).to eq((now + 2 * DAY).iso8601)
        expect(@entry.ban_count).to eq(2)

        last_history = @entry.histories.last
        expect(last_history.action).to eq(Banip::Action::BAN)
        expect(last_history.executed_at).to eq(now.iso8601)
        expect(last_history.slack_link).to eq(slack_link)

        change = @entry.change
        expect(change.action).to eq(Banip::Action::BAN)
        expect(change.cidr_block).to eq(cidr_block)
        expect(change.ban_count).to eq(2)
        expect(change.expire_at).to eq(@entry.expire_at)
      end
    end

    context 'when expire_in is passed' do
      let(:expire_in) { 5 * DAY }
      subject(:entry) { described_class.build(cidr_block, slack_link) }

      it 'bans an entry for expire_in' do
        entry.ban!(slack_link, expire_in)
        expect(Time.parse(entry.expire_at) - Time.parse(entry.since)).to eq(expire_in)
      end
    end

    context 'when expiration_lambda is passed' do
      let(:expiration_lambda) do
        lambda do |ban_count|
          ban_count <= 2 ? 1 * DAY : 3 * DAY
        end
      end
      subject(:entry) { described_class.build(cidr_block, slack_link) }

      it 'bans an entry by following expiration_lambda' do
        entry.ban!(slack_link, expiration_lambda: expiration_lambda)
        expect(Time.parse(entry.expire_at) - Time.parse(entry.since)).to eq(1 * DAY)
        entry.ban!(slack_link, expiration_lambda: expiration_lambda)
        expect(Time.parse(entry.expire_at) - Time.parse(entry.since)).to eq(3 * DAY)
        entry.ban!(slack_link, expiration_lambda: expiration_lambda)
        expect(Time.parse(entry.expire_at) - Time.parse(entry.since)).to eq(3 * DAY)
      end
    end
  end

  describe '#expire!' do
    let(:cidr_block) { '192.0.2.1/32' }
    let(:slack_link) { 'dummy' }
    let(:built_time) { Time.local(2019, 12, 31, 17, 0, 0) }
    let(:now) { built_time + 60 * 60 }

    context 'when entry alives' do
      around do |example|
        Timecop.freeze(built_time) do
          @entry = described_class.build(cidr_block, slack_link)
        end
        Timecop.freeze(now) do
          example.run
        end
      end

      it 'makes it expired' do
        @entry.expire!(slack_link)
        expect(@entry.cidr_block).to eq(cidr_block)
        expect(@entry.since).to eq(built_time.iso8601)
        expect(@entry.expired).to eq(true)
        expect(@entry.expire_at).to eq(now.iso8601)
        expect(@entry.ban_count).to eq(1)

        last_history = @entry.histories.last
        expect(last_history.action).to eq(Banip::Action::EXPIRE)
        expect(last_history.executed_at).to eq(now.iso8601)
        expect(last_history.slack_link).to eq(slack_link)

        change = @entry.change
        expect(change.action).to eq(Banip::Action::EXPIRE)
        expect(change.cidr_block).to eq(cidr_block)
        expect(change.ban_count).to eq(1)
        expect(change.expire_at).to eq(@entry.expire_at)
      end
    end

    context 'when entry has already expired' do
      around do |example|
        Timecop.freeze(built_time) do
          @entry = described_class.build(cidr_block, slack_link)
          @entry.expire!(slack_link)
        end
        Timecop.freeze(now) do
          example.run
        end
      end

      it 'does nothing' do
        @entry.expire!(slack_link)
        expect(@entry.cidr_block).to eq(cidr_block)
        expect(@entry.since).to eq(built_time.iso8601)
        expect(@entry.expired).to eq(true)
        expect(@entry.expire_at).to eq(built_time.iso8601)
        expect(@entry.ban_count).to eq(1)

        last_history = @entry.histories.last
        expect(last_history.action).to eq(Banip::Action::EXPIRE)
        expect(last_history.executed_at).to eq(built_time.iso8601)
        expect(last_history.slack_link).to eq(slack_link)

        change = @entry.change
        expect(change.action).to eq(Banip::Action::EXPIRE)
        expect(change.cidr_block).to eq(cidr_block)
        expect(change.ban_count).to eq(1)
        expect(change.expire_at).to eq(@entry.expire_at)
      end
    end
  end
end
