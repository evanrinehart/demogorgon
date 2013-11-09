require 'rb-inotify'

class Demogorgon

  def initialize &block
    @notifier = INotify::Notifier.new
    @servers = []

    Signal.trap('INT') do
      exit
    end

    s = self
    s.instance_eval &block

    loop do
      IO.select([@notifier.to_io].....
    end
  end

  def barf
    puts "barf"
  end

  def monitor path, events, &block
    @notifier.watch(path, *events, &block)
  end

  def listen port, pattern, &block
    # listen on port
    # add handler to set for port
    # handler matches pattern on message and passes params to block
    # handler accepts a new client socket, hidden
  end

  def stdin pattern, &block
    # add handler to set for stdin
  end

  def pipe path, pattern, &block
    # add pipe to select set and assign handler
  end

end
