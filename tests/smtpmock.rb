require "net/smtp"

class SMTPMock
  attr_reader :host
  attr_reader :port
  attr_reader :helo
  attr_reader :src
  attr_reader :from
  attr_reader :to

  def self.instance
    @@instance
  end

  def initialize(host, port = 25)
    @@instance = self

    @host = host
    @port = port
  end

  def start(helo, account, password, auth, &block)
    @helo = helo
    block.call(self) if block
  end

  def send_mail(src, from, *to)
    @src = src
    @from = from
    @to = to
  end
end

class Net::SMTP
  def self.new(*args)
    SMTPMock.new(*args)
  end
end
