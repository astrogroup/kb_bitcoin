require_relative './com'

class YahooFinanceCom < Com

  def initialize
    @pair_param = {
      "USD_JPY" => "USDJPY",
    }
  end

  # 参考：外為オンラインは、夜２３時頃から朝７時頃はレートが更新されないみたいなので使えない
  # uri = URI.parse("http://www.gaitameonline.com/rateaj/getrate")

  def get_board(pair)
    pair_param = @pair_param[pair]
    return nil if pair_param.nil?

    rescue_wrap do

      uri = URI.parse("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(%22#{pair_param}%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.start {
        http.get(uri.request_uri)
      }

      parsed_response = JSON.parse(response.body)

      board = {
        lowest_sell: {
          rate: parsed_response["query"]["results"]["rate"]["Ask"].to_f,
          amount: nil,
        },
        highest_buy: {
          rate: parsed_response["query"]["results"]["rate"]["Bid"].to_f,
          amount: nil,
        },
      }
    end
  end

end

