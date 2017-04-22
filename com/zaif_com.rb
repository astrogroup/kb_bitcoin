require_relative './com'

class ZaifCom < Com
  include Nonce

  def initialize
    @pair_param = {
      "BTC_JPY" => "btc_jpy",
    }
    @nonce_length = 10
  end

  def get_balance
    rescue_wrap do
      # respons deposit means total deposit. deposit = funds + order
      uri_base = "https://api.zaif.jp/tapi"
      uri = URI.parse(uri_base)

      body_query = to_query({
        method: "get_info",
        nonce: create_nonce,
      })

      header = create_header(body_query)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_query

      response = https.request(req)

      result = JSON.parse(response.body)
      { jpy: result["return"]["deposit"]["jpy"].to_f, btc: result["return"]["deposit"]["btc"].to_f }
    end
  end

  def get_board(pair)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do

      uri_base = "https://api.zaif.jp/api/1/"
      uri = URI.parse(uri_base + "depth/#{pair_param}")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      response = https.start {
        https.get(uri.request_uri)
      }

      result = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: result["asks"][0][0].to_i, amount: result["asks"][0][1].to_f},
        highest_buy: {rate: result["bids"][0][0].to_i, amount: result["bids"][0][1].to_f}
      }
    end
  end

  def create_order(pair, order_type, rate, amount)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do

      uri_base = "https://api.zaif.jp/tapi"
      uri = URI.parse(uri_base)

      body_query = to_query({
        method: "trade",
        nonce: create_nonce,
        currency_pair: pair_param,
        action: convert_order_type(order_type),
        price: rate,
        amount: amount,
      })

      header = create_header(body_query)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_query

      response = https.request(req)
      result = JSON.parse(response.body)

      result["return"]["order_id"].to_s
    end
  end

  #idは上のクラスではstringで扱うが、zaifに送る時はnumerical
  def cancel(id, pair)
    rescue_wrap do
      uri_base = "https://api.zaif.jp/tapi"
      uri = URI.parse(uri_base)

      body_query = to_query({
        method: "cancel_order",
        nonce: create_nonce,
        order_id: id.to_i,
      })

      header = create_header(body_query)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_query

      response = https.request(req)
      result = JSON.parse(response.body)

      # result => {"success"=>0, "error"=>"order not found"}
      # result => {"success"=>1, "return"=>
      # {"order_id"=>116985236,
      # "funds"=>{"jpy"=>3322.5655, "btc"=>2.1268, "xem"=>0.0, "mona"=>0.0}}}
      # のように、注文が完了してorder not foundのときもあれば、キャンセル受付できる時もある

      return true if response.code == "200" #エラーキャッチされない限り指定したオーダーはキャンセルされた（か、すでに完了済み）と想定
    end
  end

  def order_empty?
    rescue_wrap do
      result = get_active_orders
      result.empty?
    end
  end

  def cancel!(pair)
    rescue_wrap do
      5.times do
        result = get_active_orders
        return true if result.empty?

        result.each do |key, v|
          cancel(key, pair)
        end
        sleep(1)
      end
    end

    raise "ERROR: 5 times tried, but not orders not canceled!"
  end

  def get_order_status(order_id)
    rescue_wrap do
      active_result = get_active_orders
      active_order = active_result.select{|key, val| key.to_s == order_id.to_s}

      if !(active_order.empty?)
        # zaifでは done_amountはないみたい
        return {status: "ACTIVE", done_amount: nil}
      end

      return {status: "COMPLETED", done_amount: nil}
      # zaifではtrade_historyにorder_idがそもそも出てこない。order_idっぽく見えるのは、別物
      #trade_result = get_trade_history
      #finished_order = trade_result.select{|key, val| key.to_s == order_id.to_s}
      #if !finished_order.empty?
      #  return {status: "COMPLETED", done_amount: finished_order["amount"].to_f }
      #end

      #nil
    end
  end

  private

  def create_header(body = "")
    key = ENV["ZAIF_KEY"]
    secret = ENV["ZAIF_SECRET"]
    nonce = create_nonce
    message = body
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), secret, message)
    header = {
      "Key" => key,
      "Sign" => signature,
    }
  end

  def convert_order_type(type)
    return "bid" if type == "buy"
    return "ask" if type == "sell"
  end

  def get_active_orders(option={})
    rescue_wrap do
      uri_base = "https://api.zaif.jp/tapi"
      uri = URI.parse(uri_base)

      body_query = to_query({
        method: "active_orders",
        nonce: create_nonce,
      }.merge(option))

      header = create_header(body_query)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_query

      response = https.request(req)
      result = JSON.parse(response.body)

      result_list = result["return"]

      result_list.each do|k, v|
        v["datetime"] = Time.at(v["timestamp"].to_i)
      end

      result_list

    end
  end

  def get_trade_history(option={})
    rescue_wrap do
      uri_base = "https://api.zaif.jp/tapi"
      uri = URI.parse(uri_base)

      body_query = to_query({
        method: "trade_history",
        nonce: create_nonce,
        currency_pair: "btc_jpy",
      }.merge(option))

      header = create_header(body_query)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https.verify_depth = 5

      req = Net::HTTP::Post.new(uri.path, initheader = header)
      req.body = body_query

      response = https.request(req)
      result = JSON.parse(response.body)

      result_list = result["return"]

      result_list.each do|k, v|
        v["datetime"] = Time.at(v["timestamp"].to_i)
      end

      result_list
    end
  end

  def to_query(hash)
    hash.collect{|key,val| "#{key}=#{val}"}.join('&')
  end

end




