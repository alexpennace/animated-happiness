$:.unshift 'lib'

require 'stuff/init'
File.open('/dev/null') { |f| foo = f.read foo }

