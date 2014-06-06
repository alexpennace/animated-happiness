class Writer
  def put(key); @file = File.open("key-#{key}", 'w'); end

  def add_data(data); @file.write data; end

  def finish_data(data); @file.close data; end

  def get(key)
    File.read("key-#{key}")
  rescue Errno::ENOENT
    nil
  end
end

class IO
  def write_it(string)
    unless $TRY2 and self != STDOUT
      return write_old(string)
    end

    if $TRY2_DIE
      if $TRY2_DIE == 0
        Thread.exit
      else
        $TRY2_DIE -= 1
      end
    end

    require 'debugger'; debugger
    $TRY2[@key] << string
  end

  def read_it
    unless $TRY2
      return read_old
    end

    $TRY2[@key]
  end

  def close_it
    unless $TRY2
      return close_old
    end
  end

  alias_method :read_old, :read
  alias_method :write_old, :write
  alias_method :close_old, :close
  alias_method :read, :read_it
  alias_method :write, :write_it
  alias_method :close, :close_it
end

class File
  def open_it(*args)
    puts "in open_it"
    unless $TRY2 and self != STDOUT
      return open_old(*args)
    end

    if $TRY2_DIE
      if $TRY2_DIE == 0
        Thread.exit
      else
        $TRY2_DIE -= 1
      end
    end

    require 'debugger'; debugger

    @key = args.first
    $TRY2[@key] = ''
  end

  alias_method :open_old, :open
  alias_method :open, :open_it
end

class Try2
  def simulate(&proc)
    @simulated = proc
  end

  def check(&proc)
    @check = proc
  end

  def work
    puts "in work"
    try = 4
    (1..10).each do |trial|
      puts "in trial #{trial}"
      $TRY2 = {}
      puts "did try2"
      $TRY2_DIE = try
      k = Thread.new { @simulated.call }.join
      @check.call
      try += 1
    end
  end

  def callit
    @simulated.call
  end
end

try2 = Try2.new

try2.simulate do
  puts "in simulate"
  f = File.open('wut', 'w')
  f.write '1'
  f.write '2'
  f.write '3'
  f.write '4'
  f.close
end

try2.check do
  puts "in check"
  f = File.open('wut', 'r')
  puts f.read
  f.close
end

try2.work

