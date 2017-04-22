require_relative './com'

class BtcECom < Com

  def initialize
    @pair_param = {
      "ETH_BTC" => "eth_btc",
      "BTC_USD" => "btc_usd",
    }
  end

  def get_board(pair)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do

      uri_base = "https://btc-e.com/api/3"
      uri = URI.parse(uri_base + "/depth/#{pair_param}")

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.start {
        #https.get(uri.request_uri, header)
        https.get(uri.request_uri)
      }

      order_books = JSON.parse(response.body)

      board = {
        lowest_sell: {rate: order_books[pair_param]["asks"][0][0].to_f, amount: order_books[pair_param]["asks"][0][1].to_f},
        highest_buy: {rate: order_books[pair_param]["bids"][0][0].to_f, amount: order_books[pair_param]["bids"][0][1].to_f},
      }
    end
  end

end

