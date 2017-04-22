require_relative './com'

class BitflyerCom < Com

  include Nonce

  def initialize
    @pair_param = {
      "ETH_BTC" => "ETH_BTC",
      "BTC_JPY" => "BTC_JPY",
    }
    @currency_param = {
      "BTC" => "BTC",
      "ETH" => "ETH",
    }
  end

  def get_balance
    rescue_wrap do
      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/me/getbalance")

      header = create_header(uri.path.to_s, "GET")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }
      res = JSON.parse(response.body)

      {jpy: search_amount(res, "JPY").to_i, btc: search_amount(res, "BTC").to_f, eth: search_amount(res, "ETH").to_f}
    end
  end

  def get_board(pair)
    product_code = @pair_param[pair]
    return nil if product_code.nil?

    rescue_wrap do
      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/board?product_code=#{product_code}")

      header = create_header(uri, "GET")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }

      order_books = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: order_books["asks"][0]["price"].to_f, amount: order_books["asks"][0]["size"].to_f},
        highest_buy: {rate: order_books["bids"][0]["price"].to_f, amount: order_books["bids"][0]["size"].to_f}
      }
    end
  end

  def create_order(pair, order_type, rate, amount)
    product_code = @pair_param[pair]
    return nil if product_code.nil?

    rescue_wrap do

      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/me/sendchildorder")

      body_json = {
        product_code: product_code,
        child_order_type: "LIMIT",
        side: convert_order_type(order_type),
        price: rate,
        size: amount,
        #minute_to_expire: 50000,
        time_in_force: "GTC"
      }.to_json

      header = create_header(uri.path, "POST", body_json)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_json

      response = https.request(req)
      JSON.parse(response.body)["child_order_acceptance_id"].to_s
    end
  end

  def cancel(id, pair)
    product_code = @pair_param[pair]
    return nil if product_code.nil?

    rescue_wrap do
      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/me/cancelchildorder")

      body_json = {
        product_code: product_code,
        child_order_acceptance_id: id.to_s,
      }.to_json

      header = create_header(uri.path, "POST", body_json)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_json

      response = https.request(req)
      response.code == "200"
    end
  end

  def cancel!(pair)
    product_code = @pair_param[pair]
    return nil if product_code.nil?
    rescue_wrap do

      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/me/cancelallchildorders")

      body_json = {
        product_code: product_code,
      }.to_json

      header = create_header(uri.path, "POST", body_json)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_json

      response = https.request(req)

      response.code == "200"
    end
  end

  def get_order_status(order_id)
    rescue_wrap do
      result = get_opens

      found = result.find{|x| x["child_order_acceptance_id"].to_s == order_id.to_s}
      # 見つからない場合は、古い取引なので、COMPLETEDにしてしまう
      return {status: "COMPLETED", done_amount: nil } if found.nil?

      case found["child_order_state"]
      when "ACTIVE"
        status = "ACTIVE"
      when "COMPLETED"
        status = "COMPLETED"
      when "CANCELED"
        status = "CANCELED"
      else # EXPIRED, REJECTED
        status = "CANCELED"
      end

      return{ status: status, done_amount: found["executed_size"] }
    end
  end

  def order_empty?
    rescue_wrap do
      result = get_opens

      result.each do |order|
        return false if order["child_order_state"] == "ACTIVE"
      end
      true
    end
  end


  def withdraw(currency, amount, address)
    currency_code = @currency_param[currency]
    return nil if currency_code.nil?

    rescue_wrap do
      uri_base = "https://api.bitflyer.jp"
      uri = URI.parse(uri_base + "/v1/me/sendcoin")

      body = {
        currency_code: currency_code,
        amount: amount,
        address: address,
      }
      body.merge!({ additional_fee: 0.0002 }) if currency_code == "BTC"
      body_json = body.to_json

      header = create_header(uri.path, "POST", body_json)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_json

      response = https.request(req)
      JSON.parse(response.body)
    end
  end

  private

  def create_header(path, method, body = "")
    key = ENV["BITFLYER_KEY"]
    secret = ENV["BITFLYER_SECRET"]
    nonce = create_nonce
    message = nonce + method.to_s + path.to_s +  body
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, message)
    header = {
      "ACCESS-KEY" => key,
      "ACCESS-TIMESTAMP" => nonce,
      "ACCESS-SIGN" => signature,
      "Content-Type" => 'application/json',
    }
  end

  def search_amount(ary, currency)
    amount = nil
    ary.each do |a|
      if a["currency_code"] == currency.to_s
        amount = a["amount"]
        break
      end
    end

    amount
  end

  def convert_order_type(order_type)
    return "BUY" if order_type == "buy"
    return "SELL" if order_type == "sell"
    raise
  end

  def get_opens
    rescue_wrap do
      uri_base = "https://api.bitflyer.jp"
      path = "/v1/me/getchildorders"
      query = "?product_code=ETH_BTC"
      uri = URI.parse(uri_base + path + query)

      header = create_header(path + query, "GET")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }
      res = JSON.parse(response.body)
    end
  end


end

