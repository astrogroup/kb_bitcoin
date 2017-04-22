require_relative './nonce'
require 'net/http'

class Com

  def rescue_wrap
    begin
      yield
    rescue => e
      puts e.backtrace.join("\n")
      p e.message
      nil
    end
  end

  def available_pair?(pair)
    !@pair_param[pair].nil?
  end

end

