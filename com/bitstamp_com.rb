require_relative './com'

class BitstampCom < Com

  def initialize
    @pair_param = {
      "BTC_USD" => "btcusd",
    }
  end

  def get_board(pair)

    currency_pair = @pair_param[pair]
    return nil if currency_pair.nil?

    rescue_wrap do
      uri_base = "https://www.bitstamp.net/api/v2/"
      uri = URI.parse(uri_base + "/order_book/#{currency_pair}/")

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
        highest_buy: {rate: order_books["bids"][0][0].to_f, amount: order_books["bids"][0][1].to_f},
      }
    end
  end

end

