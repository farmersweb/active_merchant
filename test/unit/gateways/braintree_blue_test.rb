require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase
  def setup
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :public_key => 'test',
      :private_key => 'test'
    )
  end

  def test_refund_legacy_method_signature
    Braintree::Transaction.expects(:refund).
      with('transaction_id', nil).
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund('transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_refund_method_signature
    Braintree::Transaction.expects(:refund).
      with('transaction_id', '10.00').
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund(1000, 'transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_void_transaction
    Braintree::Transaction.expects(:void).
      with('transaction_id').
      returns(braintree_result(:id => "void_transaction_id"))

    response = @gateway.void('transaction_id', :test => true)
    assert_equal "void_transaction_id", response.authorization
  end

  def test_user_agent_includes_activemerchant_version
    assert Braintree::Configuration.instantiate.user_agent.include?("(ActiveMerchant #{ActiveMerchant::VERSION})")
  end

  def test_merchant_account_id_present_when_provided_on_gateway_initialization
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "present")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"))
  end

  def test_merchant_account_id_on_transaction_takes_precedence
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "account_on_transaction")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "account_on_transaction")
  end

  def test_merchant_account_id_present_when_provided
    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "present")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "present")
  end

  def test_merchant_account_id_absent_if_not_provided
    Braintree::Transaction.expects(:sale).with do |params|
      not params.has_key?(:merchant_account_id)
    end.returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"))
  end

  def test_find_customer

    billing_address = mock(
        :street_address => "1 E Main St",
        :extended_address => "Suite 403",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622"
    )
    credit_card = mock(
        :bin => '401288',
        :expiration_date => '12/2020',
        :token => '123ygh',
        :last_4 => '1881',
        :card_type => 'MasterCard',
        :masked_number => '401288******1881',
        :cardholder_name => 'John Smith'
    )
    customer = mock(
        :id => '123',
        :email => 'email',
        :first_name => 'John',
        :last_name => 'Smith',
    )
    credit_card.stubs(:billing_address).returns(billing_address)
    customer.stubs(:credit_cards).returns([credit_card])

    Braintree::Customer.expects(:find).with do |params|
      assert_equal '123', params
    end.returns(customer)

    response = @gateway.find_customer('123')
    assert_equal '123', response.params["customer"]["id"]
    assert_equal '401288', response.params["customer"]["credit_cards"][0]["bin"]
    assert_equal '12/2020', response.params["customer"]["credit_cards"][0]["expiration_date"]
    assert_equal '123ygh', response.params["customer"]["credit_cards"][0]["token"]
    assert_equal '1881', response.params["customer"]["credit_cards"][0]["last_4"]
    assert_equal 'MasterCard', response.params["customer"]["credit_cards"][0]["card_type"]
    assert_equal '401288******1881', response.params["customer"]["credit_cards"][0]["masked_number"]
    assert_equal 'John Smith', response.params["customer"]["credit_cards"][0]["cardholder_name"]
    assert_equal '1 E Main St', response.params["customer"]["credit_cards"][0]["billing_address"]["street_address"]
    assert_equal '60622', response.params["customer"]["credit_cards"][0]["billing_address"]["postal_code"]
  end

  def test_failed_find_customer
    Braintree::Customer.expects(:find).with do |params|
      assert_equal "123", params
    end.raises(Braintree::NotFoundError)
    response = @gateway.find_customer("123")
    assert_failure response
  end

  def test_store_with_verify_card_true
    billing_address = mock(
        :street_address => "1 E Main St",
        :extended_address => "Suite 403",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622"
    )
    credit_card = mock(
        :bin => '401288',
        :expiration_date => '12/2020',
        :last_4 => '1881',
        :card_type => 'MasterCard',
        :masked_number => '401288******1881',
        :cardholder_name => 'John Smith'
    )
    credit_card.stubs(:billing_address).returns(billing_address)
    credit_card.stubs(:token).returns('398fjda')

    customer = mock(
        :email => 'email',
        :first_name => 'John',
        :last_name => 'Smith'
    )
    customer.stubs(:credit_cards).returns([credit_card])
    customer.stubs(:id).returns('123')

    result = Braintree::SuccessfulResult.new(:customer => customer, :credit_card => credit_card)

    Braintree::Customer.expects(:find).with do |params|
      assert_equal customer.id, params
    end.raises(Braintree::NotFoundError)

    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal true, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :id => customer.id, :verify_card => true)

    assert_equal '123', response.params["customer_vault_id"]
    assert_equal '398fjda', response.params["token"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_store_with_verify_card_false
    billing_address = mock(
        :street_address => "1 E Main St",
        :extended_address => "Suite 403",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622"
    )
    credit_card = mock(
        :bin => '401288',
        :expiration_date => '12/2020',
        :last_4 => '1881',
        :card_type => 'MasterCard',
        :masked_number => '401288******1881',
        :cardholder_name => 'John Smith'
    )
    credit_card.stubs(:billing_address).returns(billing_address)
    credit_card.stubs(:token).returns('398fjda')

    customer = mock(
        :email => 'email',
        :first_name => 'John',
        :last_name => 'Smith'
    )
    customer.stubs(:credit_cards).returns([credit_card])
    customer.stubs(:id).returns('123')

    result = Braintree::SuccessfulResult.new(:customer => customer, :credit_card => credit_card)

    Braintree::Customer.expects(:find).with do |params|
      assert_equal customer.id, params
    end.raises(Braintree::NotFoundError)

    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal false, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :id => '123', :verify_card => false)
    assert_equal "123", response.params["customer_vault_id"]
    assert_equal '398fjda', response.params["token"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_store_with_billing_address_options
    billing_address_attributes = {
      :address1 => "1 E Main St",
      :address2 => "Suite 403",
      :city => "Chicago",
      :state => "Illinois",
      :zip_code => "60622",
      :country_name => "US"
    }

    billing_address = mock(
        :street_address => "1 E Main St",
        :extended_address => "Suite 403",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622"
    )
    credit_card = mock(
        :bin => '401288',
        :expiration_date => '12/2020',
        :last_4 => '1881',
        :card_type => 'MasterCard',
        :masked_number => '401288******1881',
        :cardholder_name => 'John Smith'
    )
    credit_card.stubs(:billing_address).returns(billing_address)
    credit_card.stubs(:token).returns('398fjda')

    customer = mock(
        :email => 'email',
        :first_name => 'John',
        :last_name => 'Smith'
    )
    customer.stubs(:credit_cards).returns([credit_card])
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)

    Braintree::Customer.expects(:find).with do |params|
      assert_equal customer.id, params
    end.raises(Braintree::NotFoundError)

    Braintree::Customer.expects(:create).with do |params|
      assert_not_nil params[:credit_card][:billing_address]
      [:street_address, :extended_address, :locality, :region, :postal_code, :country_name].each do |billing_attribute|
        params[:credit_card][:billing_address].has_key?(billing_attribute) if params[:billing_address]
      end
      params
    end.returns(result)

    @gateway.store(credit_card("41111111111111111111"), :id => '123', :billing_address => billing_address_attributes)
  end

  def test_store_existing_customer
    billing_address = mock(
        :street_address => "1 E Main St",
        :extended_address => "Suite 403",
        :locality => "Chicago",
        :region => "Illinois",
        :postal_code => "60622"
    )
    credit_card = mock(
        :bin => '401288',
        :expiration_date => '12/2020',
        :last_4 => '1881',
        :card_type => 'MasterCard',
        :masked_number => '401288******1881',
        :cardholder_name => 'John Smith'
    )
    credit_card.stubs(:token).returns('123ygh')
    credit_card.stubs(:billing_address).returns(billing_address)
    customer = mock(
        :email => 'john@smith.com',
        :first_name => 'John',
        :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    customer.stubs(:credit_cards).returns([])
    result = Braintree::SuccessfulResult.new(:customer => customer, :credit_card => credit_card)

    Braintree::Customer.expects(:find).with do |params|
      assert_equal customer.id, params
    end.returns(customer)

    Braintree::CreditCard.expects(:create).with do |params|
      cc = {
          :number=>"41111111111111111111",
          :cvv=>"123",
          :expiration_month=>"09",
          :expiration_year=>"2014",
          :cardholder_name=>"Longbob Longsen",
          :customer_id=>"123",
          :options=>{
              :verify_card=>true
          }}
      assert_equal params, cc
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :id => customer.id, :verify_card => true)

    braintree_customer = {"email"=>"john@smith.com",
                          "first_name"=>"John",
                          "last_name"=>"Smith",
                          "credit_cards"=>
                              [{"bin"=>"401288",
                                "expiration_date"=>"12/2020",
                                "token"=>"123ygh",
                                "last_4"=>"1881",
                                "card_type"=>"MasterCard",
                                "masked_number"=>"401288******1881",
                                "cardholder_name"=>"John Smith",
                                "billing_address"=>
                                    {"street_address"=>"1 E Main St",
                                     "extended_address"=>"Suite 403",
                                     "city"=>"Chicago",
                                     "state"=>"Illinois",
                                     "postal_code"=>"60622"}}],
                          "id"=>"123"}
    assert_equal braintree_customer, response.params["customer"]
    assert_equal '123', response.params["customer_vault_id"]
    assert_equal '123ygh', response.params["token"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_update_with_cvv
    stored_credit_card = mock(:token => "token", :default? => true)
    customer = mock(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::Customer.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:update).with do |vault, params|
      assert_equal "567", params[:credit_card][:cvv]
      [vault, params]
    end.returns(result)

    @gateway.update('vault_id', credit_card("41111111111111111111", :verification_value => "567"))
  end

  def test_update_with_verify_card_true
    stored_credit_card = mock(:token => "token", :default? => true)
    customer = mock(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::Customer.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:update).with do |vault, params|
      assert_equal true, params[:credit_card][:options][:verify_card]
      [vault, params]
    end.returns(result)

    @gateway.update('vault_id', credit_card("41111111111111111111"), :verify_card => true)
  end

  def test_merge_credit_card_options_ignores_bad_option
    params = {:first_name => 'John', :credit_card => {:cvv => '123'}}
    options = {:verify_card => true, :bogus => 'ignore me'}
    merged_params = @gateway.send(:merge_credit_card_options, params, options)
    expected_params = {:first_name => 'John', :credit_card => {:cvv => '123', :options => {:verify_card => true}}}
    assert_equal expected_params, merged_params
  end

  def test_merge_credit_card_options_handles_nil_credit_card
    params = {:first_name => 'John'}
    options = {:verify_card => true, :bogus => 'ignore me'}
    merged_params = @gateway.send(:merge_credit_card_options, params, options)
    expected_params = {:first_name => 'John', :credit_card => {:options => {:verify_card => true}}}
    assert_equal expected_params, merged_params
  end

  def test_merge_credit_card_options_handles_billing_address
    billing_address = {
      :address1 => "1 E Main St",
      :city => "Chicago",
      :state => "Illinois",
      :zip_code => "60622",
      :country => "US"
    }
    params = {:first_name => 'John'}
    options = {:billing_address => billing_address}
    expected_params = {
      :first_name => 'John',
      :credit_card => {
        :billing_address => {
          :street_address => "1 E Main St",
          :extended_address => nil,
          :company => nil,
          :locality => "Chicago",
          :region => "Illinois",
          :postal_code => "60622",
          :country_code_alpha2 => "US"
        },
        :options => {}
      }
    }
    assert_equal expected_params, @gateway.send(:merge_credit_card_options, params, options)
  end

  def test_merge_credit_card_options_only_includes_billing_address_when_present
    params = {:first_name => 'John'}
    options = {}
    expected_params = {
      :first_name => 'John',
      :credit_card => {
        :options => {}
      }
    }
    assert_equal expected_params, @gateway.send(:merge_credit_card_options, params, options)
  end

  def test_address_country_handling
    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country => "US"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha2 => "US"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_name] == "United States of America")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_name => "United States of America"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha3] == "USA")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha3 => "USA"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_numeric] == 840)
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_numeric => 840})
  end

  def test_passes_recurring_flag
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:recurring => true)).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"), :recurring => true)

    Braintree::Transaction.expects(:sale).
      with(Not(has_entries(:recurring => true))).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"))
  end

  def test_configured_logger_has_a_default
    # The default is actually provided by the Braintree gem, but we
    # assert its presence in order to show ActiveMerchant need not
    # configure a logger
    assert Braintree::Configuration.logger.is_a?(Logger)
  end

  def test_configured_logger_has_a_default_log_level_defined_by_active_merchant
    assert_equal Logger::WARN, Braintree::Configuration.logger.level
  end

  def test_configured_logger_respects_any_custom_log_level_set_without_overwriting_it
    with_braintree_configuration_restoration do
      assert Braintree::Configuration.logger.level != Logger::DEBUG
      Braintree::Configuration.logger.level = Logger::DEBUG

      # Re-instatiate a gateway to show it doesn't affect the log level
      BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )

      assert_equal Logger::WARN, Braintree::Configuration.logger.level
    end
  end

  def test_that_setting_a_wiredump_device_on_the_gateway_sets_the_braintree_logger_upon_instantiation
    with_braintree_configuration_restoration do
      logger = Logger.new(STDOUT)
      ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = logger

      assert_not_equal logger, Braintree::Configuration.logger

      BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )

      assert_equal logger, Braintree::Configuration.logger
      assert_equal Logger::DEBUG, Braintree::Configuration.logger.level
    end
  end

  private

  def braintree_result(options = {})
    Braintree::SuccessfulResult.new(:transaction => Braintree::Transaction._new(nil, {:id => "transaction_id"}.merge(options)))
  end

  def with_braintree_configuration_restoration(&block)
    # Remember the wiredump device since we may overwrite it
    existing_wiredump_device = ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device

    yield

    # Restore the wiredump device
    ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = existing_wiredump_device

    # Reset the Braintree logger
    Braintree::Configuration.logger = nil
  end
end
