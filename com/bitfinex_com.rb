require_relative './com'

class BitfinexCom < Com
  include Nonce

  def initialize
    @pair_param = {
      "ETH_BTC" => "ethbtc",
      "BTC_USD" => "btcusd",
    }
    @currency_param = {
      "BTC" => "bitcoin",
      "ETH" => "ethereum",
    }
  end

  def get_board(pair)
    symbol = @pair_param[pair]
    return nil if symbol.nil?

    rescue_wrap do

      getting_board_length = 5 # 5 for buy and 5 for sell. total 10.

      uri_base = "https://api.bitfinex.com"
      uri = URI.parse(uri_base + "/v1/book/#{symbol}?limit_bids=#{getting_board_length.to_s}&limit_asks=#{getting_board_length.to_s}")

      #header = create_header(uri, "GET")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri)
      }

      order_books = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: order_books["asks"][0]["price"].to_f, amount: order_books["asks"][0]["amount"].to_f},
        highest_buy: {rate: order_books["bids"][0]["price"].to_f, amount: order_books["bids"][0]["amount"].to_f},
      }
      board
    end
  end

  def get_balance
    rescue_wrap do
      uri_base = "https://api.bitfinex.com"
      path = "/v1/balances"
      uri = URI.parse(uri_base + path)

      header = create_header(path)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      #req.body = body_json

      response = https.request(req)
      res = JSON.parse(response.body)

      btc = res.find{|x| x["type"] == "exchange" && x["currency"] == "btc"}["amount"].to_f rescue nil
      eth = res.find{|x| x["type"] == "exchange" && x["currency"] == "eth"}["amount"].to_f rescue nil
      {btc: btc, eth: eth}
    end
  end


  def create_order(pair, order_type, rate, amount)
    symbol = @pair_param[pair]
    return nil if symbol.nil?

    rescue_wrap do

      uri_base = "https://api.bitfinex.com"
      path = "/v1/order/new"
      uri = URI.parse(uri_base + path)

      params = {
        symbol: symbol,
        amount: amount.to_s,
        type: "exchange limit",
        side: order_type,
        exchange: 'bitfinex',
        price: rate.to_s,
      }
      header = create_header(path, params)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)

      response = https.request(req)
      JSON.parse(response.body)["id"].to_s
    end
  end

  def cancel(id, pair)
    rescue_wrap do
      uri_base = "https://api.bitfinex.com"
      path = "/v1/order/cancel"
      uri = URI.parse(uri_base + path)

      params = {
        order_id: id.to_i,
      }
      header = create_header(path, params)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)

      response = https.request(req)
      response.code == "200"
    end
  end

  #Todo: まだ中身作ってない
  def get_order_status(order_id)
    return{ status: "COMPLETED", done_amount: 0 }
  end

  def withdraw(currency, amount, address)
    symbol = @currency_param[currency]
    return nil if symbol.nil?

    rescue_wrap do

      uri_base = "https://api.bitfinex.com"
      path = "/v1/withdraw"
      uri = URI.parse(uri_base + path)

      params = {
        withdraw_type: symbol,
        walletselected: "exchange",
        amount: amount.to_s,
        address: address,
      }
      header = create_header(path, params)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)

      response = https.request(req)
      JSON.parse(response.body)
    end
  end

  private

  def create_header(path, options={})
    secret = ENV["BITFINEX_SECRET"]
    payload = build_payload(path, options)
    signature = OpenSSL::HMAC.hexdigest("sha384", secret, payload)

    header = {
      #"ACCESS-KEY" => key,
      #"ACCESS-TIMESTAMP" => nonce,
      "Content-Type" => 'application/json',
      "Accept" => 'application/json',
      "X-BFX-PAYLOAD" => payload,
      "X-BFX-SIGNATURE" => signature,
      "X-BFX-APIKEY" => ENV["BITFINEX_KEY"],
    }
  end

  def build_payload(path, params = {})
    payload = {}
    payload['nonce'] = create_nonce
    payload['request'] = path
    payload.merge!(params) if params
    Base64.strict_encode64(payload.to_json)
  end

end

