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

  @cache_connections = false
  @connections = {}
  
  class << self
    attr_accessor :host, :pem, :port, :pass, :feedback_port, :cache_connections
  end
  
  def self.send_notification(device_token, message)
    self.with_notification_connection do |conn|
      conn.write(self.packaged_notification(device_token, message))
      conn.flush
    end
  end
  
  def self.send_notifications(notifications)
    self.with_notification_connection do |conn|
      notifications.each do |n|
        conn.write(self.packaged_notification(n[0], n[1]))
      end
      conn.flush
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
    hash.to_json
  end
  
  def self.with_notification_connection(&block)
    self.with_connection(self.host, self.port, &block)
  end

  def self.with_feedback_connection(&block)
    # Explicitly disable the connection cache for feedback
    cache_temp = @cache_connections
    @cache_connections = false

    fhost = self.host.gsub!('gateway','feedback')
    self.with_connection(fhost, self.feedback_port, &block)

    @cache_connections = cache_temp
  end
 
  private

  def self.open_connection(host, port)
    raise "The path to your pem file is not set. (APNS.pem = /path/to/cert.pem)" unless self.pem
    raise "The path to your pem file does not exist!" unless File.exist?(self.pem)
    
    context      = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read(self.pem))
    context.key  = OpenSSL::PKey::RSA.new(File.read(self.pem), self.pass)

    retries = 0
    begin
      sock         = TCPSocket.new(host, port)
      ssl          = OpenSSL::SSL::SSLSocket.new(sock, context)
      ssl.connect
      return ssl, sock
    rescue Errno::ECONNREFUSED
      if retries += 1 < 5
        sleep 1
        retry
      else
        # Too many retries, re-raise this exception
        raise
      end
    end
  end

  def self.has_connection(host, port)
    @connections.has_key?([host,port])
  end

  def self.create_connection(host, port)
    @connections[[host, port]] = self.open_connection(host, port)
  end

  def self.find_connection(host, port)
    @connections[[host, port]]
  end

  def self.remove_connection(host, port)
    if self.has_connection(host, port)
      ssl, sock = @connections.delete([host, port])
      ssl.close
      sock.close
    end
  end

  def self.reconnect_connection(host, port)
    self.remove_connection(host, port)
    self.create_connection(host, port)
  end

  def self.get_connection(host, port)
    if @cache_connections
      # Create a new connection if we don't have one
      unless self.has_connection(host, port)
        self.create_connection(host, port)
      end

      ssl, sock = self.find_connection(host, port)
      # If we're closed, reconnect
      if ssl.closed?
        self.reconnect_connection(host, port)
        self.find_connection(host, port)
      else
        return [ssl, sock]
      end
    else
      self.open_connection(host, port)
    end
  end

  def self.with_connection(host, port, &block)

    retries = 0
    begin
      ssl, sock = self.get_connection(host, port)
      yield ssl if block_given?

      unless @cache_connections
        ssl.close
        sock.close
      end
    rescue Errno::ECONNABORTED
      if retries += 1 < 5
        self.remove_connection(host, port)
        retry
      else
        # too-many retries, re-raise
        raise
      end
    end
  end
end
