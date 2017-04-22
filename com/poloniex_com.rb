require_relative './com'

class PoloniexCom < Com

  def initialize
    @pair_param = {
      "ETH_BTC" => "BTC_ETH",
      "BTC_USD" => "USDT_BTC",
    }
  end

  def get_board(pair)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do

      depth = 5 # 5 for buy and 5 for sell. total 10.

      uri_base = "https://poloniex.com"
      uri = URI.parse(uri_base + "/public?command=returnOrderBook&currencyPair=#{pair_param}&depth=#{depth}")

      #header = create_header(uri, "GET")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        #https.get(uri.request_uri, header)
        https.get(uri.request_uri)
      }

      order_books = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: order_books["asks"][0][0].to_f, amount: order_books["asks"][0][1].to_f},
        highest_buy: {rate: order_books["bids"][0][0].to_f, amount: order_books["bids"][0][1].to_f},}

      return nil if board[:lowest_sell][:amount] < 0 || board[:highest_buy][:amount] < 0 # something wrong case

      board
    end
  end

end

