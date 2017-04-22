require_relative  './market'

INTERVAL = 120 #sec

class ExchangeLog
  def action

    exchange_markets = [
      YahooFinance.new,
      Coincheck.new,
      Zaif.new,
      Bitflyer.new,
      Bitstamp.new,
      BtcE.new,
      Gdax.new,
      Poloniex.new,
      Bitfinex.new,
    ]

    loop do
      begin

        time_stamp = TimeStamp.create(log_at: Time.current)

        %w(USD_JPY BTC_JPY BTC_USD ETH_BTC).each do |pair|

          logs = []
          p pair
          Parallel.map(exchange_markets, in_threads: exchange_markets.size) do |market|
            deal_market(market, pair, time_stamp, logs)
          end
          print_best_combination(logs)
        end
      rescue => e
        puts e.backtrace
        p e.message
      end

      p "--------------------------"
      sleep(INTERVAL)
    end
  end

  private

  def deal_market(market, pair, time_stamp, logs)
    begin

      market.update_board(pair)
      board = market.get_board(pair)
      return if board.nil?

      log = BoardLog.new(lowest_sell_rate: board.lowest_sell[:rate], lowest_sell_amount: board.lowest_sell[:amount],
                         highest_buy_rate: board.highest_buy[:rate], highest_buy_amount: board.highest_buy[:amount])
      log.exchange = Exchange.where(name: market.class.name).first
      log.time_stamp = time_stamp
      log.currency_pair = CurrencyPair.where(pair: pair).first
      log.save

      p "#{market.name} sells #{sprintf("%05f", log.lowest_sell_rate.to_f.round(6))} #{log.lowest_sell_amount.to_f.round(4)}"
      p "#{market.name} buys  #{sprintf("%05f", log.highest_buy_rate.to_f.round(6))} #{log.highest_buy_amount.to_f.round(4)} spread: #{board.spread_percent.round(2)}%"
      logs.push(log)
    rescue => e
      puts e.backtrace
      p e.message
    end
  end

  def print_best_combination(logs)
    return if logs.empty?
    seller = logs.sort{|x, y| x.lowest_sell_rate <=> y.lowest_sell_rate}.first
    buyer = logs.sort{|x, y| x.highest_buy_rate <=> y.highest_buy_rate}.last
    p "lowest_sell: #{Exchange.where(id: seller.exchange_id).first.name} #{seller.lowest_sell_rate} highest_buy: #{Exchange.where(id: buyer.exchange_id).first.name} #{buyer.highest_buy_rate}"

    spread = ((buyer.highest_buy_rate - seller.lowest_sell_rate) / (seller.lowest_sell_rate + buyer.highest_buy_rate) * 2 * 100).round(2)
    if spread > 1
      colored_spread = spread.to_s.green
      if spread > 3
        #3.times do
        #  system('afplay /System/Library/Sounds/Glass.aiff')
        #end
      end
    else
      colored_spread = spread.to_s.red
    end
    puts "benefitable spread(+ means oppotunity green > 1%): " + colored_spread + "%"
  end

end
