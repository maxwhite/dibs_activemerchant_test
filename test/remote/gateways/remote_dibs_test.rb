require 'test_helper'

class RemoteDibsTest < Test::Unit::TestCase
  def setup
    @gateway = DibsGateway.new(fixtures(:dibs_payment))

    @amount = 100
    
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => 4711100000000000,
      :month              => 6,
      :year               => 24,
      :verification_value => 684,
    ) 
    
    # This card decline in process of authorization 
    @auth_declined_card = @credit_card.clone
    @auth_declined_card.number = 541303000000000003
    
    @options = {
      :orderId     =>  generate_unique_id[0...10],
      :currency    =>  'DKK',
      :clientIp    =>  "10.10.10.10",
      :issueNumber =>  5 
   }
  end

  def test_successful_authorize 
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was successful', response.message
  end  
  
  def test_successful_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was successful', auth.message
    assert auth.authorization
    puts auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end
  
  def test_successful_authorize_and_void
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was successful', auth.message
    assert auth.authorization
    
    assert cancel = @gateway.void(auth.authorization)
    assert_success cancel
  end
  
  def test_successful_authorize_capture_and_refund
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was successful', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture 
    assert refund = @gateway.refund(amount, auth.authorization)
    assert_success refund 
  end
  
  def test_successful_create_and_authorize_ticket
    amount = @amount
    assert ticket = @gateway.create_ticket(@credit_card, @options)
    assert_success ticket
    assert ticket.authorization
    assert auth_ticket = @gateway.recurring(ticket.authorization, amount, @options)
    assert_success auth_ticket
  end
  
  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @auth_declined_card, @options)
    assert_failure response
    assert_equal "REJECTED_BY_ACQUIRER", response.message
  end 

  def test_invalid_login
    gateway = DibsGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Validation error at field: merchantId - Parameter length should not be less than 1 characters', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal 'Validation error at field: transactionId - Parameter length should not be less than 1 characters', response.message
  end
end
