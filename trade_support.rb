module TradeSupport

  MIN_AMOUNT = {
    "BTC_JPY" => 0.005, #btc
  }
  WAITING_TRADE_CONFIRM_SEC = 3 #秒, オーダーしてから待つ.
  ROUND_AMOUNT_DIGIT = {
    "BTC_JPY" => 3,
  }

  class << self

    def ring
      3.times do
        system('afplay /System/Library/Sounds/Glass.aiff')
      end
    end

    def adapt_min_amount(amount, pair)
      if amount > MIN_AMOUNT[pair]
        amount
      else
        MIN_AMOUNT[pair]
      end
    end

    def calc_amount(buy_target_market, sell_target_market, limit, pair)
      amount = [
        buy_target_market.get_board(pair).buy_taker_amount,
        sell_target_market.get_board(pair).sell_taker_amount,
        limit,
      ].min.round(ROUND_AMOUNT_DIGIT[pair])

      amount = adapt_min_amount(amount, pair)
    end

    def order_with_history(market, order_type, rate, amount, pair)
      currency_pair = CurrencyPair.where(pair: pair).first
      order_status = OrderStatus.where(status: "ACTIVE").first

      order_id = market.create_order(pair, order_type, rate, amount)
      p "#{order_type} order_id: #{order_id}"
      puts "#{order_type} ".yellow + "#{rate}, #{amount} at #{market.name}"

      exchange = Exchange.where(name: market.class.name).first
      history = OrderHistory.new(order_id: order_id, order_type: order_type, rate: rate, amount: amount, done_amount: 0)
      history.exchange = exchange
      history.currency_pair = currency_pair
      history.order_status = order_status
      history.save
      history
    end

    def wait_and_cancel(market, order_type, order_id, pair)
      sleep(WAITING_TRADE_CONFIRM_SEC)
      cancel_status = market.cancel(order_id, pair)
      p "#{order_type} cancel : #{cancel_status}"
    end


    def trade(buy_market, sell_market, amount, pair)
      cross = CrossTradeRelation.create

      action = Proc.new do |market, order_type|
        rate = market.get_board(pair).send("#{order_type}_taker_rate")

        history = order_with_history(market, order_type, rate, amount, pair)

        cross.send("#{order_type}_order_history_id=", history.id)
        cross.save

        TradeSupport.wait_and_cancel(market, order_type, history.order_id, pair)
      end

      Parallel.map([[sell_market, "sell"], [buy_market, "buy"]], in_threads: 2) do |args|
        action.call(args[0], args[1])
      end

    end

    def update_order_status(exchange_markets)
      OrderHistory.where(order_status_id: OrderStatus.where(status: "ACTIVE").first.id).reverse.each do |active_order|
        market = exchange_markets.find{|x| x.class.name == active_order.exchange.name }
        result = market.get_order_status(active_order.order_id)
        p result
        if !result.nil?
          active_order.update(order_status_id: OrderStatus.where(status: result[:status]).first.id, done_amount: result[:done_amount])
        end
      end
    end

    def refresh_balance(exchange_markets)
      btc_sum = 0
      jpy_sum = 0
      eth_sum = 0
      Parallel.map(exchange_markets, in_threads: exchange_markets.size) do |market|
        market.update_balance
        balance = market.get_balance
        next if balance.nil?
        p "#{market.name} JPY:#{sprintf("%7d", balance.jpy || 0)} BTC:#{sprintf("%3.5f", balance.btc || 0)} ETH:#{sprintf("%4.3f", balance.eth || 0)} "
        jpy_sum += balance.jpy if !balance.jpy.nil?
        btc_sum += balance.btc if !balance.btc.nil?
        eth_sum += balance.eth if !balance.eth.nil?
      end

      begin
        # BTC/JPY
        btc_avail_markets = exchange_markets.map{|x| x.get_board("BTC_JPY").center_rate rescue nil }.compact
        btc_avr_rate = if btc_avail_markets.empty?
                         0
                       else
                         (btc_avail_markets.inject(0){|sum, a| sum += a} / btc_avail_markets.size) rescue 0
                       end
        btc_val = btc_sum * btc_avr_rate

        # ETH/BTC
        eth_avail_markets = exchange_markets.map{|x| x.get_board("ETH_BTC").center_rate rescue nil }.compact
        eth_avr_rate = if eth_avail_markets.empty?
                         0
                       else
                         (eth_avail_markets.inject(0){|sum, a| sum += a} / eth_avail_markets.size) rescue 0
                       end
        eth_val = eth_sum * eth_avr_rate * btc_avr_rate # ETH/BTC * BTC/JPY

        p "BTC:#{sprintf("%2.4f", btc_sum)} ETH:#{sprintf("%2.4f", eth_sum)} JPY:#{sprintf("%7d", jpy_sum)} NET:#{sprintf("%7d", jpy_sum + btc_val + eth_val)}"
        p "---------------------------"
      rescue => e
        p e.message
        puts e.backtrace.join("\n")
        nil
      end
    end

    def search_best_trade(exchange_markets, limit, least_benefit, least_benefit_percent, pair)

      exchange_markets = exchange_markets.reject{|x| x.get_board(pair).nil? || x.get_balance.nil? }
      main_currency = pair.split('_')[0].downcase #ex: "BTC_JPY" => btc
      counter_currency = pair.split('_')[1].downcase #ex: "BTC_JPY" => jpy

      candidates = []
      exchange_markets.each do |buy_market|
        counterparts = exchange_markets - [buy_market]
        counterparts.each do |sell_market|

          #get rate
          buy_rate = buy_market.get_board(pair).buy_taker_rate
          sell_rate = sell_market.get_board(pair).sell_taker_rate

          #diff check
          unit_diff = sell_rate - buy_rate
          next if unit_diff <= 0 # never allow minus

          #amount check
          amount = TradeSupport.calc_amount(buy_market, sell_market, limit, pair)

          next if sell_market.get_balance.send(main_currency) < amount
          next if buy_market.get_balance.send(counter_currency) < buy_rate * amount

          # calc benefit for 1unit
          unit_sell_commission = sell_rate * sell_market.commission_percent[pair]/100
          unit_buy_commission = buy_rate * buy_market.commission_percent[pair]/100

          unit_benefit = unit_diff - unit_sell_commission - unit_buy_commission
          unit_benefit_percent = unit_benefit / (buy_rate + sell_rate) * 2 * 100
          next if unit_benefit_percent < least_benefit_percent

          # actual benefit
          benefit = unit_benefit * amount
          next if benefit < least_benefit

          candidates.push({
            buy: buy_market,
            sell: sell_market,
            difference: unit_diff,
            amount: amount,
            benefit: benefit,
          })

          #p "unit_sell_commission #{unit_sell_commission}"
          #p "unit_buy_commission #{unit_buy_commission}"
          #p "benefit #{benefit}"
          #p "unit_benefit_percent #{unit_benefit_percent}"
        end
      end

      candidates.sort{|x, y| x[:benefit] <=> y[:benefit]}.last

    end

  end

end


