module Nonce

  def create_nonce

    return @nonce = issue_mil_nonce if @nonce.nil?

    nonce_try = issue_mil_nonce

    while(@nonce == nonce_try)
      sleep(1)
      nonce_try = issue_mil_nonce
    end

    @nonce = nonce_try
  end

  private

  def issue_mil_nonce
    #本来13桁だが, Zaifが10桁までしかうけつけられないのでそこで切る
    # 0..12 => 13桁
    @nonce_length ||= 13

    nonce_length = @nonce_length
    Time.now.instance_eval { (self.to_i * 1000 + (usec/1000)).to_s[0..(nonce_length - 1)] }
  end

end

