# Copyright (c) 2009 James Pozdena, 2010 Justin.tv
#  
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#  
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#  
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
 
require 'apns/core'

# high5
#device_token = '074ee796765d8f215d1500fed44cdeb1c860d901da202f48a24fd33ce33ffe87'

# long tall sally
device_token = '45dfe351cda3462cb14906e7d9bbc9d1d5ed0b143800a817f951a82c4f36207f'

# yukon ipad
#device_token = '4633f3e8f02d821b0a5c63f974b5864f29e4ea29190c2342e059d1ecf78a80b1'

# mini
#device_token = 'a7c56a89a0135c9afc88c01dd1514d5178c3df9ee8aac27ab36482f16935d059'

# ipad
#device_token = '85814bd59d2cac383db2271eb367e1baca2c751a647d1735933a2d2143095b91'

APNS.pem  = '/Users/robsiwek/Documents/Certificates/cert.pem'
APNS.send_notification(device_token, :uri => 'soundcloud:tracks:2342',
									 :alert =>'One of your sounds has been reposted...',
									 :badge => 1,
									 :sound => 'default')
