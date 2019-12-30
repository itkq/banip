require 'banip/state'
require 'banip/ban_updater/waf'

DAY = 24 * 60 * 60
RSpec.describe Banip::BanUpdater::WAF do
  describe '#description' do
    let(:region) { 'ap-northeast-1' }
    let(:ip_set_id) { '01234567-89ab-cdef-0123-456789abcdef' }
    subject(:waf_updater) { described_class.new(region, ip_set_id) }

    it 'returns non-empty text' do
      expect(waf_updater.description).not_to be_empty
    end
  end

  describe '#update' do
    let(:region) { 'ap-northeast-1' }
    let(:ip_set_id) { '01234567-89ab-cdef-0123-456789abcdef' }
    let(:waf_regional) { instance_double(Aws::WAFRegional::Client) }
    let(:slack_link) { 'dummy' }
    let(:change_token) { 'dummy' }
    let(:cidr_block1) { '192.0.2.1/32' }
    let(:cidr_block2) { '192.0.2.2/32' }
    let(:expire_in_sec) { DAY }
    let(:state) do
      state = Banip::State.new
      state.ban(cidr_block1, slack_link, expire_in_sec)
      state.apply!

      state.expire(cidr_block1, slack_link)
      state.ban(cidr_block2, slack_link, expire_in_sec)
      state.apply!

      state
    end

    subject(:waf_updater) { described_class.new(region, ip_set_id) }

    before(:each) do
      allow(waf_updater).to receive(:waf_regional).and_return(waf_regional)
      allow(waf_regional).to receive(:get_change_token).and_return(
        Aws::WAFRegional::Types::GetChangeTokenResponse.new(
          change_token: change_token,
        )
      )
    end

    context 'when there is a CIDR to ban' do
      before do
        allow(waf_regional).to receive(:get_ip_set).with(ip_set_id: ip_set_id).and_return(
          Aws::WAFRegional::Types::GetIPSetResponse.new(
            ip_set: Aws::WAFRegional::Types::IPSet.new(
              ip_set_descriptors: [],
            ),
          )
        )
      end

      it 'updates ip_set' do
        expect(waf_regional).to receive(:update_ip_set).with(
          change_token: change_token,
          ip_set_id: ip_set_id,
          updates: [
            { action: 'INSERT', ip_set_descriptor: Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: cidr_block2) },
          ],
        )
        waf_updater.update(state)
      end
    end

    context 'when there is a CIDR to expire' do
      before do
        allow(waf_regional).to receive(:get_ip_set).with(ip_set_id: ip_set_id).and_return(
          Aws::WAFRegional::Types::GetIPSetResponse.new(
            ip_set: Aws::WAFRegional::Types::IPSet.new(
              ip_set_descriptors: [
                Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: cidr_block1),
                Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: cidr_block2),
              ],
            ),
          )
        )
      end

      it 'updates ip_set' do
        expect(waf_regional).to receive(:update_ip_set).with(
          change_token: change_token,
          ip_set_id: ip_set_id,
          updates: [
            { action: 'DELETE', ip_set_descriptor: Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: cidr_block1) },
          ],
        )
        waf_updater.update(state)
      end
    end

    context 'when state is synced with ip_set' do
      before do
        allow(waf_regional).to receive(:get_ip_set).with(ip_set_id: ip_set_id).and_return(
          Aws::WAFRegional::Types::GetIPSetResponse.new(
            ip_set: Aws::WAFRegional::Types::IPSet.new(
              ip_set_descriptors: [
                Aws::WAFRegional::Types::IPSetDescriptor.new(type: 'IPV4', value: cidr_block2),
              ],
            ),
          )
        )
      end

      it 'does not update ip_set' do
        expect(waf_regional).not_to receive(:update_ip_set)
        waf_updater.update(state)
      end
    end
  end
end
