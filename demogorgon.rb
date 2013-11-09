require 'rb-inotify'
require 'socket'

require './cron'

class Demogorgon

  class UnknownFdClass < StandardError; end

  def initialize &block
    @notifier = INotify::Notifier.new
    @on_connect = {}
    @on_message = {}
    @tail_handlers = {}
    @stdin_handler = nil
    @cron = Cron::Queue.new
    @int_handler = nil
    @connections = {}

    Signal.trap('INT') do
      @int_handler.call() if @int_handler
      exit
    end

    self.instance_eval &block

    fds = [
      [STDIN],
      @on_connect.keys,
      @on_message.keys,
      @tail_handlers.keys,
      [@notifier.to_io]
    ].flatten(1)

    now = Time.now

    loop do
      ready_set = IO.select(fds, [], [], @cron.eta(now))
      now = Time.now
      if ready_set.nil?
        event = @cron.dequeue!(now)
        event.call() if event
      else
        ready_set[0].each do |io|
          case fd_class(io)
            when :stdin then @stdin_handler[io.gets || ''] if @stdin_handler
            when :connect_for_message
              s = io.accept
              @connections[s] = @on_message[io]
              fds.push(s)
            when :message
              msg = io.gets || ''
              @connections[io][msg, lambda{|x| s.write(x) rescue nil}]
              @connections.delete(io)
              io.close
              fds.delete(io)
            when :connect
              s = io.accept
              s.close
              @on_connect[io].call()
            when :monitor then @notifier.process
            when :tail
              msg = io.gets
              if msg.nil?
                io.close
                @tail_handlers.delete(io)
                fds.delete(io)
              else
                @tail_handlers[io][msg]
              end
          end
        end
      end
    end
  end

  def fd_class io
    return :stdin if io == STDIN
    return :connect if @on_connect[io]
    return :connect_for_message if @on_message[io]
    return :tail if @tail_handlers[io]
    return :monitor if @notifier.to_io == io
    return :message if @connections.include?(io)
    raise UnknownFdClass
  end

  def monitor path, events, &block
    @notifier.watch(path, *events) do |event|
      block.call(event.absolute_name, event.flags)
    end
  end

  def on_connect port, &block
    server = TCPServer.new port
    @on_connect[server] = block
  end

  def on_message port, &block
    server = TCPServer.new port
    @on_message[server] = block
  end

  def stdin &block
    @stdin_handler = block
  end

  def each_line_in_file path, &block
    f = File.open(path, 'r')
    @tail_handlers[f] = block
  end

  def on_ctrl_c &block
    @int_handler = block
  end

end
