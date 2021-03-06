require 'test_helper'

class BaseTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
  end
  
  def teardown
    ActiveMerchant::Billing::Base.mode = :test
  end
  
  def test_should_return_a_new_gateway_specified_by_symbol_name
    assert_equal BogusGateway,         Base.gateway(:bogus)
    assert_equal BraintreeGateway,     Base.gateway(:braintree)
    assert_equal BalancedGateway,      Base.gateway(:balanced)
    assert_equal StripeGateway,        Base.gateway(:stripe)
  end

  def test_should_raise_when_invalid_gateway_is_passed
    assert_raise NameError do
      Base.gateway(:nil)
    end

    assert_raise NameError do
      Base.gateway('')
    end

    assert_raise NameError do
      Base.gateway(:hotdog)
    end
  end

  def test_should_return_an_integration_by_name
    bogus = Base.integration(:bogus)
    
    assert_equal Integrations::Bogus, bogus
    assert_instance_of Integrations::Bogus::Notification, bogus.notification('name=cody')
  end

  def test_should_set_modes
    Base.mode = :test
    assert_equal :test, Base.mode
    assert_equal :test, Base.gateway_mode
    assert_equal :test, Base.integration_mode

    Base.mode = :production
    assert_equal :production, Base.mode
    assert_equal :production, Base.gateway_mode
    assert_equal :production, Base.integration_mode

    Base.mode             = :development
    Base.gateway_mode     = :test
    Base.integration_mode = :staging
    assert_equal :development, Base.mode
    assert_equal :test,        Base.gateway_mode
    assert_equal :staging,     Base.integration_mode
  end
  
  def test_should_identify_if_test_mode
    Base.gateway_mode = :test
    assert Base.test?
    
    Base.gateway_mode = :production
    assert_false Base.test?
  end

end
