module APNS
  require 'socket'
  require 'openssl'
  require 'json'

  @host = 'gateway.sandbox.push.apple.com'
  @port = 2195
  @feedback_port = 2196
  # openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts
  @pem = nil # this should be the path of the pem file not the contentes
  @pass = nil
  
  class << self
    attr_accessor :host, :pem, :port, :pass, :feedback_port
  end
  
  def self.send_notification(device_token, message)
    self.with_notification_connection do |conn|
      conn.write(self.packaged_notification(device_token, message))
    end
  end
  
  def self.send_notifications(notifications)
    self.with_notification_connection do |conn|
      notifications.each do |n|
        conn.write(n.packaged_notification)
      end
    end
  end
  
  def self.feedback
    apns_feedback = []
    self.with_feedback_connection do |conn|
      # Read buffers data from the OS, so it's probably not
      # too inefficient to do the small reads
      while data = conn.read(38)
        apns_feedback << self.parse_feedback_tuple(data)
      end
    end
    
    return apns_feedback
  end
  
  protected

  # Each tuple is in the following format:
  #
  #              timestamp | token_length (32) | token
  # bytes:  4 (big-endian)      2 (big-endian) | 32
  #
  # timestamp - seconds since the epoch, in UTC
  # token_length - Always 32 for now
  # token - 32 bytes of binary data specifying the device token
  #
  def self.parse_feedback_tuple(data)
    feedback = data.unpack('N1n1H64')
    {:feedback_at => Time.at(feedback[0]), :length => feedback[1], :device_token => feedback[2] }
  end

  def self.packaged_notification(device_token, message)
    pt = self.packaged_token(device_token)
    pm = self.packaged_message(message)
    [0, 0, 32, pt, 0, pm.size, pm].pack("ccca*cca*")
  end
  
  def self.packaged_token(device_token)
    [device_token.gsub(/[\s|<|>]/,'')].pack('H*')
  end
  
  def self.packaged_message(message)
    if message.is_a?(Hash)
      apns_from_hash(message)
    elsif message.is_a?(String)
      '{"aps":{"alert":"'+ message + '"}}'
    else
      raise "Message needs to be either a hash or string"
    end
  end
  
  def self.apns_from_hash(hash)
    other = hash.delete(:other)
    aps = {'aps'=> hash }
    aps.merge!(other) if other
    aps.to_json
  end
  
  def self.with_notification_connection(&block)
    self.with_connection(self.host, self.port, &block)
  end

  def self.with_feedback_connection(&block)
    fhost = self.host.gsub!('gateway','feedback')
    self.with_connection(fhost, self.feedback_port, &block)
  end
 
  private

  def self.with_connection(host, port, &block)
    raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)

    sock         = TCPSocket.new(host, port)
    ssl          = OpenSSL::SSL::SSLSocket.new(sock, context)
    ssl.connect

    yield ssl if block_given?

    ssl.close
    sock.close
  end
end
