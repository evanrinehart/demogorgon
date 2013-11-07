class Demogorgon

  def initialize &block
    Signal.trap('INT') do
      exit
    end

    s = self
    s.instance_eval &block

    sleep 10
  end

  def barf
    puts "barf"
  end

end
