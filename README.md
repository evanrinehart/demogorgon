```ruby
require "demogorgon"

Demogorgon.new do

  # do this for each line of standard input, nothing will happen at EOF
  stdin do |msg|
    puts "stdin: #{msg}"
  end

  # do this when something connects on port 12345, they are disconnected immediately
  # FIXME you need to be able to talk back before disconnecting
  on_connect 12345 do
    puts "connect"
  end

  # do this for the first line of each connection on port 12346
  # FIXME you need to talk back before disconnecting
  on_message 12346 do |msg|
    puts "message: #{msg}"
  end

  # do this in response to inotify filesystem events, such as a touch command
  monitor 'some/file', [:all_events] do |filename, events|
    puts "#{filename} #{events.inspect}"
  end

  # think of this as "tail -f", use it on a named pipe
  each_line_in_file 'bar-stream' do |msg|
    puts "tail: #{msg}"
  end

  # These INT and TERM signal callbacks will run before the program ends.
  # Warning, these may occur *in the middle of* some other operation, though
  # you can consider that operation to be cancelled at this point mid-way

  on_ctrl_c do
    puts "CTRL C PRESSED"
  end

  on_terminate do
    puts "I WAS KILLED"
  end

end
```
