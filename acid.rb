require 'json'
require 'fileutils'

class Acid

  class LoaderError < StandardError; end

  def initialize log_path, &block
    @methods = {}
    @read = lambda{|x| x}
    @show = lambda{|x| x}
    @init = lambda{ nil }
    @log_path = log_path

    self.instance_eval &block

    begin
      @state = load_log @log_path
    rescue Errno::ENOENT
      log_file = File.open(@log_path, 'w')
      @state = @init[]
      log_file.puts(JSON.generate({:checkpoint => @state}))
      log_file.close
    end

    @log_file = File.open(@log_path, 'a')
  end

  def init &block
    @init = block
  end

  def log_file path
    @log_path = path
  end

  def serialize &block
    @show = block
  end

  def deserialize &block
    @read = block
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

  def update name, &block
    define '_'+name.to_s do |state, *args|
      block[state, *args]
    end

    define name.to_s do |*args|
      @log_file.puts(JSON.generate([name] + args))
      @state, retval = block[@state, *args]
      retval
    end
  end

  def method_missing name, *args
    raise NoMethodError, name.to_s unless @methods[name.to_s]
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
        state = @read[JSON.parse(line0, :symbolize_names => true)[:checkpoint]]
      else
        log_file.close
        state = @init[]
        _checkpoint log_path, state
        return state
      end
    rescue JSON::ParserError, Acid::LoaderError
      raise LoaderError, "initial record in log file is busted"
    end

    log_file.lines do |line|
      begin
        name, *args = JSON.parse(line)
        state, retval = self.send('_'+name, state, *args)
      rescue JSON::ParserError
        STDERR.puts "*** WARNING: corrupt line in log, recovering o_O ***"
        log_file.close
        FileUtils.copy log_path, log_path+'.original'
        _checkpoint log_path, state
        return state
      rescue NoMethodError
        log_file.close
        raise LoaderError, "I don't have a way to use update method #{name.inspect}"
      end
    end
    log_file.close
    state
  end

  def _checkpoint log_path, state
    file = File.open(log_path+'.paranoid', 'w')
    image = JSON.generate({:checkpoint => @show[state]})
    file.puts(image)
    file.close
    File.rename(log_path+'.paranoid', log_path)
  end

end
