@Mac

Install ruby 2.3.1 or later

$gem install bundler
(If you have “Unable to download data from https://rubygems.org/ - SSL_connect returned=1”: $gem source -a http://rubygems.org/)

# install dependancy
$bundle

Edit your password.yml and set your API key
(API key is issued in each exchanges. Log in the exchage site and check it.)

$bundle exec ruby trade.rb
then, board prices are printed.
"Coincheck  sells 136789 0.626"
"Coincheck  buys  136730 0.261"
"Zaif       sells 136755 0.79"
"Zaif       buys  136750 0.326"


If above works well, show your balances.
Uncomment
#TradeSupport.refresh_balance(full_exchange_markets)

and run the program
$bundle exec ruby trade.rb



