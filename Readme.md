@Mac

Install ruby 2.3.1 or later

#### Install gem library and dependancy　　
$gem install bundler
(If you have “Unable to download data from https://rubygems.org/ - SSL_connect returned=1”: $gem source -a http://rubygems.org/)  

$bundle

#### Set API key
$cp password_example.yml password.yml  
#Edit your password.yml and set your API key  
#(API key is issued in each exchanges. Log in the exchage site and check it.)  

#### Show price
$bundle exec ruby trade.rb  
then, board prices are printed.  
example  
Coincheck  sells 136789 0.626　　
Coincheck  buys  136730 0.261　　
Zaif       sells 136755 0.79　　
Zaif       buys  136750 0.326　　

#### Show balance
If above works well, show your balances.  
Uncomment  
#TradeSupport.refresh_balance(full_exchange_markets)  

and run the program  
$bundle exec ruby trade.rb  

#### Show arbitrage
If above works well, try to find arbitrage opportunity  
Uncomment  
#best_trade = TradeSupport.search_best_trade(exchange_markets, LIMIT[pair], LEAST_BENEFIT[pair], LEAST_BENEFIT_PERCENT[pair], pair)  
#if !best_trade.nil?  
  #p best_trade  
#end  

#### and your program...
