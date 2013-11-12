class Acid
  def log_file path
    @log_path = path
  end

  def init &block
    define_method '_init', &block
  end

  def serialize &block
    define_method '_serialize', &block
  end

  def deserialize &block
    define_method '_deserialize', &block
  end

  def checkpoint
    file = File.open(@log_path+'.paranoid', 'w')
    file.puts(self._serialize)
    file.close
    File.move(@log_path+'.paranoid', @log_path)
  end

  def initialize &block
    self.instance_eval &block
    log_file = File.open(@log_path, 'r')
    @state = replay_log log_file
    log_file.close
    @log_file = File.open(@log_path, 'a')
  end

  def view name, &block
    define_method name do |*args|
      yield @state, *args
    end
  end

  def method name, &block
    define_method '_'+name do |*args|
      @state = block[@state, *args]
    end

    define_method name do |*args|
      @log_file.puts(JSON.encode([name] + args))
      @state = block[@state, *args]
    end
  end

  def replay_log log_file
    state = _init
    log_file.lines do |line|
      empty = false
      name, *args = JSON.decode(line)
      state = self.send('_'+name, state, *args)
    end
    state
  end
  
end
