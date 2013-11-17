INOTIFY_SUPPORT = false

require 'rb-inotify' if INOTIFY_SUPPORT
require 'socket'

require './cron'

class Demogorgon

  class Bug < StandardError; end
  class InotifyNotSupported < StandardError; end

  def initialize &block
    @notifier = INotify::Notifier.new if INOTIFY_SUPPORT
    @on_connect = {}
    @on_message = {}
    @tail_handlers = {}
    @stdin_handler = nil
    @cron = Cron::Queue.new
    @int_handler = nil
    @term_handler = nil
    @boot_action = lambda{}
    @connections = {}
    @dialog_servers = {}
    @dialogs = {}
    @adhoc_events = AdhocQueue.new

    Signal.trap('INT') do
      @int_handler.call() if @int_handler
      exit
    end

    Signal.trap('TERM') do
      @term_handler.call() if @term_handler
      exit(1)
    end

    at = lambda do |time, &block|
     ts = time.utc
     @adhoc_events.insert time, block
    end

    self.instance_exec at, &block

    fds = [
      [STDIN],
      @on_connect.keys,
      @on_message.keys,
      @tail_handlers.keys,
      @dialog_servers.keys,
      INOTIFY_SUPPORT ? [@notifier.to_io] : []
    ].flatten(1)

    now = Time.now

    @boot_action.call

    loop do
      eta1 = @cron.eta(now)
      eta2 = @adhoc_events.eta(now)

      eta = if eta1 && eta2
        eta1 < eta2 ? eta1 : eta2
      elsif eta1
        eta1
      elsif eta2
        eta2
      else
        nil
      end

      ready_set = IO.select(fds, [], [], eta)
      now = Time.now
      if ready_set.nil?
        event = @cron.dequeue!(now)
        if event
          event.call()
        else
          etime, event = @adhoc_events.dequeue!(now)
          if event
            event.call(etime)
          end
        end
      else
        ready_set[0].each do |io|
          case fd_class(io)
            when :stdin
              msg = io.gets
              @stdin_handler[msg.chomp] if msg && @stdin_handler
            when :connect_for_message
              s = io.accept
              @connections[s] = @on_message[io]
              fds.push(s)
            when :message
              msg = io.gets || ''
              @connections[io][msg.chomp, lambda{|x| io.write(x) rescue nil}]
              @connections.delete(io)
              io.close
              fds.delete(io)
            when :connect
              s = io.accept
              @on_connect[io].call(lambda{|x| s.write(x) rescue nil})
              s.close
            when :dialog_connect
              s = io.accept
              fds.push(s)
              @dialogs[s] = @dialog_servers[io]
              @dialogs[s][:connect][
                s.to_i,
                lambda{|msg| s.write(msg) rescue nil},
                lambda{ s.shutdown }
              ]
            when :dialog
              msg = io.gets
              if msg.nil?
                @dialogs[io][:disconnect][io.to_i]
                @dialogs.delete(io)
                fds.delete(io)
                io.close
              else
                @dialogs[io][:message][io.to_i, msg.chomp]
              end
            when :monitor then @notifier.process
            when :tail
              msg = io.gets
              if msg.nil?
                io.close
                @tail_handlers.delete(io)
                fds.delete(io)
              else
                @tail_handlers[io][msg.chomp]
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
    return :monitor if INOTIFY_SUPPORT && @notifier.to_io == io
    return :message if @connections.include?(io)
    return :dialog_connect if @dialog_servers.include?(io)
    return :dialog if @dialogs.include?(io)
    raise Bug, "unknown fd class"
  end

  def monitor path, events, &block
    raise InotifyNotSupported unless INOTIFY_SUPPORT
    @notifier.watch(path, *events) do |event|
      block.call(event.absolute_name, event.flags)
    end
  end

  def on_boot &block
    @boot_action = block
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

  def on_terminate &block
    @term_handler = block
  end

  def on_schedule raw_spec, &block
    spec = Cron::Spec.new raw_spec
    now = Time.now
    @cron.insert! now, spec, block
  end

  def dialog port, handlers
    server = TCPServer.new port
    @dialog_servers[server] = handlers
  end

  class AdhocQueue
    def initialize
      @queue = []
    end

    def insert time, payload
      rec = {
        :time => time,
        :payload => payload
      }

      pred = @queue.index{|x| x[:time] > time}
      if pred.nil?
        @queue.push rec
      else
        @queue.insert pred, rec
      end
    end

    def dequeue! now
      if @queue.empty?
        nil
      elsif now < @queue.first[:time]
        nil
      else
        rec = @queue.delete_at(0)
        [rec[:time], rec[:payload]]
      end
    end

    def eta now
      if @queue.empty?
        nil
      elsif @queue.first[:time] < now
        0
      else
        @queue.first[:time] - now
      end
    end
  end

end
