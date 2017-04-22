
require_relative './market'
require_relative './trade_support'
require 'pry'
require 'yaml'
require 'parallel'
require 'openssl'
require 'json'

config_dir_path = File.expand_path('../', __FILE__)
yml_path = config_dir_path + '/password.yml'
unless File.exist?(yml_path) # load default example.yml
  require 'fileutils'
  FileUtils.cp(config_dir_path + '/password_example.yml', yml_path)
end
config = YAML.load(File.read(yml_path))
config.each do |key, value|
  ENV[key] = value unless value.is_a? Hash
end


class Trade

  LIMIT = {
    "BTC_JPY" => 0.15, # BTC. limit BTC amount for 1 transaction
  }
  LEAST_BENEFIT = {
    #"BTC_JPY" => 5, # yen. each transaction's benefit should be bigger than this value  bitflyerは切り捨てするっぽいし、2円以上はマスト.
    "BTC_JPY" => 0
  }
  LEAST_BENEFIT_PERCENT = {
    #"BTC_JPY" => 0.05, # 0.05%=1万円で5円. ex: 0.2btc buy & sell, 0.05% means 0.0001btc =~ 10 yen
    "BTC_JPY" => 0.00
  }

  def action
    full_exchange_markets = [
      coincheck = Coincheck.new,
      zaif = Zaif.new,
      #bitflyer = Bitflyer.new,
    ]

    loop do

      pair = "BTC_JPY"
      exchange_markets = [coincheck, zaif]

      p pair

      begin
        #TradeSupport.update_order_status(full_exchange_markets)
        #TradeSupport.refresh_balance(full_exchange_markets)

        Parallel.map(exchange_markets, in_threads: exchange_markets.size) do |market|
          market.update_board(pair)
        end

        #best_trade = TradeSupport.search_best_trade(exchange_markets, LIMIT[pair], LEAST_BENEFIT[pair], LEAST_BENEFIT_PERCENT[pair], pair)
        #if !best_trade.nil?
        #  p best_trade
        #end


        #unless best_trade.nil? || best_trade.empty?
        #  TradeSupport.trade(best_trade[:buy], best_trade[:sell], best_trade[:amount], pair)
        #end

        exchange_markets.each do |market|
          board = market.get_board(pair)
          next if board.nil?
          p "#{market.name} sells #{board.lowest_sell[:rate]} #{board.lowest_sell[:amount].round(3)}"
          p "#{market.name} buys  #{board.highest_buy[:rate]} #{board.highest_buy[:amount].round(3)}"
        end


        sleep(3) # depends on how frequently you call api

      rescue => e
        puts e.backtrace.join("\n")
        p e.message
        sleep(30)
      end

    end
  end
end

Trade.new.action


