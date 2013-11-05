require 'test_helper'

class OfflineTest < Test::Unit::TestCase
  def setup
    @gateway = OfflineGateway.new()
  end

  def test_authorize
    assert response = @gateway.authorize()
    assert_equal true, response.success?
    assert_equal :authorize, response.action
    assert_equal :offline, response.gateway
  end

  def test_capture
    assert response = @gateway.capture()
    assert_equal true, response.success?
    assert_equal :capture, response.action
    assert_equal :offline, response.gateway
  end

  def test_refund
    assert response = @gateway.refund()
    assert_equal true, response.success?
    assert_equal :refund, response.action
    assert_equal :offline, response.gateway
  end

  def test_void
    assert response = @gateway.void()
    assert_equal true, response.success?
    assert_equal :void, response.action
    assert_equal :offline, response.gateway
  end

  def test_verify
    assert response = @gateway.verify()
    assert_equal true, response.success?
    assert_equal :verify, response.action
    assert_equal :offline, response.gateway
  end

  def test_find_customer
    assert response = @gateway.find_customer()
    assert_equal true, response.success?
    assert_equal :find_customer, response.action
    assert_equal :offline, response.gateway
  end

  def test_store
    assert response = @gateway.store()
    assert_equal true, response.success?
    assert_equal :store, response.action
    assert_equal :offline, response.gateway
  end

  def test_update
    assert response = @gateway.update()
    assert_equal true, response.success?
    assert_equal :update, response.action
    assert_equal :offline, response.gateway
  end

  def test_unstore
    assert response = @gateway.unstore()
    assert_equal true, response.success?
    assert_equal :unstore, response.action
    assert_equal :offline, response.gateway
  end
end
