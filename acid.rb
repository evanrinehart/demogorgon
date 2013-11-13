require 'json'
require 'fileutils'

class Acid

  class LoaderError < StandardError; end

  def initialize &block
    @methods = {}

    self.instance_eval &block

    begin
      @state = load_log @log_path
    rescue Errno::ENOENT
      log_file = File.open(@log_path, 'w')
      @state = self._init
      log_file.puts(JSON.generate({'checkpoint' => @state}))
      log_file.close
    end

    @log_file = File.open(@log_path, 'a')
  end

  def log_file path
    @log_path = path
  end

  def init &block
    define '_init', &block
  end

  def checkpoint
    @log_file.close
    _checkpoint @log_path, @state
    @log_file = File.open(@log_path, 'a')
  end

  def view name, &block
    define name do |*args|
      yield @state, *args
    end
  end

  def method name, &block
    define '_'+name.to_s do |state, *args|
      block[state, *args]
    end

    define name.to_s do |*args|
      @log_file.puts(JSON.generate([name] + args))
      @state = block[@state, *args]
    end
  end

  def method_missing name, *args
    raise NoMethodError, name unless @methods[name.to_s]
    @methods[name.to_s][*args]
  end

  private

  def define name, &block
    @methods[name.to_s] = block
  end

  def load_log log_path
    log_file = File.open(log_path)
    line0 = log_file.gets

    begin
      if line0
        state = JSON.parse(line0)['checkpoint']
      else
        state = _init
      end
    rescue JSON::ParserError
      raise LoaderError, "initial record in log file is busted"
    end

    log_file.lines do |line|
      begin
        name, *args = JSON.parse(line)
        state = self.send('_'+name, state, *args)
      rescue JSON::ParserError
        STDERR.puts "*** WARNING: corrupt line in log, recovering o_O ***"
        log_file.close
        FileUtils.copy log_path, log_path+'.original'
        _checkpoint log_path, state
        return state
      rescue NoMethodError
        raise LoaderError, "I don't have a way to use update method #{name.inspect}"
      end
    end
    state
  end

  def _checkpoint log_path, state
    file = File.open(log_path+'.paranoid', 'w')
    file.puts(JSON.generate({'checkpoint' => state}))
    file.close
    File.rename(log_path+'.paranoid', log_path)
  end

end
