require_relative './com'

class CoincheckCom < Com
  include Nonce

  def initialize
    @pair_param = {
      "BTC_JPY" => "btc_jpy",
    }
  end

  def get_balance
    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/accounts/balance")

      header = create_header(uri)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }
      res = JSON.parse(response.body)
      {jpy: res["jpy"].to_f, btc: res["btc"].to_f}
    end
  end

  def get_board(pair)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/order_books")

      header = create_header(uri)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }

      order_books = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: order_books["asks"][0][0].to_i, amount: order_books["asks"][0][1].to_f},
        highest_buy: {rate: order_books["bids"][0][0].to_i, amount: order_books["bids"][0][1].to_f}
      }
    end
  end

  def create_order(pair, order_type, rate, amount)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/exchange/orders")

      body_json = {
        rate: rate,
        amount: amount,
        market_buy_amount: nil,
        order_type: order_type,
        position_id: nil,
        pair: pair_param,
      }.to_json

      header = create_header(uri, body_json)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_json

      response = https.request(req)
      JSON.parse(response.body)["id"]
    end
  end

  def cancel(id, pair)
    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/exchange/orders/#{id.to_s}")

      header = create_header(uri)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Delete.new(uri.path, initheader = header)
      response = https.request(req)
      JSON.parse(response.body)["success"].to_s == "true"
    end
  end

  def order_empty?
    rescue_wrap do
      result = get_opens
      result["orders"].empty?
    end
  end

  def cancel!(pair)
    rescue_wrap do
      5.times do
        result = get_opens
        return true if result["orders"].empty?

        result["orders"].each do |order|
          cancel(order["id"], pair)
        end
        sleep(1)
      end
    end
    raise "ERROR: 5 times tried, but not orders not canceled!"
  end

  def get_order_status(order_id)
    rescue_wrap do
      active_result = get_opens["orders"]
      active_order = active_result.find{|x| x["id"].to_s == order_id.to_s}
      if !active_order.nil?
        return {status: "ACTIVE", done_amount: active_order["pending_amount"] }
      end

      trade_result = get_trade_history["transactions"]
      finished_order = trade_result.find{|x| x["order_id"].to_s == order_id.to_s}
      if !finished_order.nil?
        # coincheck では sell時、funds btc がマイナス
        return {status: "COMPLETED", done_amount: finished_order["funds"]["btc"].to_f.abs }
      end

      #すでに取れないぐらい昔のものはCOMPLETEDにしてしまう
      return {status: "COMPLETED", done_amount: nil}
    end
  end

  private

  def create_header(uri, body = "")
    key = ENV["COINCHECK_KEY"]
    secret = ENV["COINCHECK_SECRET"]
    nonce = create_nonce
    message = nonce + uri.to_s + body
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, message)
    header = {
      "Content-Type" => 'application/json',
      "ACCESS-KEY" => key,
      "ACCESS-NONCE" => nonce,
      "ACCESS-SIGNATURE" => signature,
    }
  end

  def get_opens
    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/exchange/orders/opens")

      header = create_header(uri)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }
      result = JSON.parse(response.body)
    end
  end

  def get_trade_history
    rescue_wrap do
      uri_base = "https://coincheck.com"
      uri = URI.parse(uri_base + "/api/exchange/orders/transactions")

      header = create_header(uri)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        https.get(uri.request_uri, header)
      }
      result = JSON.parse(response.body)
    end
  end

end
