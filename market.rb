
require_relative './com/coincheck_com'
require_relative './com/zaif_com'
require_relative './com/bitflyer_com'
require_relative './com/bitstamp_com'
require_relative './com/btc_e_com'
require_relative './com/gdax_com'
require_relative './com/bitfinex_com'
require_relative './com/poloniex_com'

require_relative './com/yahoo_finance_com'

class Balance
  attr_accessor :jpy, :btc, :eth

  def initialize(attributes = nil)
    attributes.each do |k, v|
      send("#{k.to_s}=", v) if respond_to?("#{k.to_s}=")
    end if attributes
    yield self if block_given?
  end

end

class Board
  attr_accessor :lowest_sell, :highest_buy, :pair

  def initialize(attributes = nil)
    attributes.each do |k, v|
      send("#{k.to_s}=", v) if respond_to?("#{k.to_s}=")
    end if attributes
    yield self if block_given?
  end

  def buy_taker_rate
    #即買えるはずのレート
    @lowest_sell[:rate]
  end

  def buy_taker_amount
    @lowest_sell[:amount]
  end

  def sell_taker_rate
    #即売れるはずのレート
    @highest_buy[:rate]
  end

  def sell_taker_amount
    @highest_buy[:amount]
  end

  def center_rate
    (@lowest_sell[:rate] + @highest_buy[:rate]) / 2
  end

  def spread_percent
    spread / center_rate * 100
  end

  def spread
    @lowest_sell[:rate] - @highest_buy[:rate]
  end

  private

end

class Market
  attr_accessor :commission_percent

  def initialize #call this from only children's 'super'
    @commission_percent ||= {} # unit:%
    @name = sprintf("%-10s", self.class)# superで呼ばれて、呼び出し元の各クラスになることを想定
    @boards ||= {}
  end

  def cancel(id, pair) # only bitflyer needs 'pair' parameter...
    @com.cancel(id, pair)
  end

  def cancel!(pair) # only bitflyer needs 'pair' parameter...
    @com.cancel!(pair)
  end

  def create_order(pair, order_type, rate, amount)
    return nil if !@com.available_pair?(pair)
    @com.create_order(pair, order_type, rate, amount)
  end

  def get_board(pair)
    @boards[pair] #return nil if not found pair
  end

  def update_board(pair)
    return nil if !@com.available_pair?(pair)

    new_board_base = @com.get_board(pair)

    if new_board_base == nil # example: network error
      @boards.delete_if{|k, v| k == pair} # remove old board
      return nil
    end

    new_board = Board.new(new_board_base)
    @boards[pair] = new_board
    new_board
  end

  def get_balance
    @balance
  end

  def update_balance
    balance = @com.get_balance
    @balance =  balance.nil? ? nil : Balance.new(balance)
  end

  def get_order_status(order_id)
    @com.get_order_status(order_id)
  end

  def name
    @name
  end

  def withdraw(currency, amount, destination_address)
    @com.withdraw(currency, amount, destination_address)
  end

end

class YahooFinance < Market

  def initialize
    @com = YahooFinanceCom.new
    super
  end

end

class Coincheck < Market

  def initialize
    @com = CoincheckCom.new
    @commission_percent = {
      "BTC_JPY" => 0, # unit: %
    }
    super
  end

end

class Zaif < Market

  def initialize
    @com = ZaifCom.new
    @commission_percent = {
      "BTC_JPY" => 0, # unit: %
    }
    super
  end

end

class Bitflyer < Market

  def initialize
    @com = BitflyerCom.new
    @commission_percent = {
      "BTC_JPY" => 0.03, # unit: %
      "ETH_BTC" => 0.2, # unit: %
    }
    super
  end

end

class Bitstamp < Market

  def initialize
    @com = BitstampCom.new
    super
  end

end


class BtcE < Market

  def initialize
    @com = BtcECom.new
    super
  end

end


class Gdax < Market

  def initialize
    @com = GdaxCom.new
    super
  end
end

class Bitfinex < Market

  def initialize
    @com = BitfinexCom.new
    @commission_percent = {
      "ETH_BTC" => 0.2, # unit: %
    }
    super
  end
end

class Poloniex < Market

  def initialize
    @com = PoloniexCom.new
    super
  end
end


