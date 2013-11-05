require 'test_helper'

class GatewayTest < Test::Unit::TestCase

  def test_offline_gateway
    assert @gateway = ActiveMerchant::Billing::Gateway.factory(:offline)
    assert_equal @gateway.display_name, "Offline"
  end

  def test_braintree_vault_gateway
    assert @gateway = ActiveMerchant::Billing::Gateway.factory(:braintree_vault)
    assert_equal @gateway.display_name, "Braintree (Blue Platform)"
  end
end