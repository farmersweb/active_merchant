module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class OfflineGateway < Gateway

      self.display_name = 'Offline'

      def authorize(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :authorize)
      end

      def capture(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :capture)
      end

      def refund(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :refund)
      end

      def void(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :void)
      end

      def find_customer(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :find_customer)
      end

      def store(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :store)
      end

      def update(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :update)
      end

      def verify(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :verify)
      end

      def unstore(*args)
        Response.new(true,'',{:raw_response => ''},:gateway => :offline, :action => :unstore)
      end
      alias_method :delete, :unstore
    end
  end
end