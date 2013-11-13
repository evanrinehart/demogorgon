The following program waits for various events to occur, then executes the
callback blocks specified for each one.

```ruby
require "demogorgon"

Demogorgon.new do

  # do this for each line of standard input, nothing will happen at EOF
  stdin do |msg|
    puts "stdin: #{msg}"
  end

  # do this for the first line of each connection on port 12346, then disconnect them
  # use the tell action to send data to them before disconnecting
  on_message 12346 do |msg, tell|
    puts "message: #{msg}"
    tell["yeah I heard\n"]
  end

  # same as on_message but don't wait for any input, disconnect immediately afterward
  on_connect 12345 do |tell|
    puts "connect"
    tell["hello world\n"]
  end

  # do this in response to inotify filesystem events, such as a touch command
  monitor 'some/file', [:all_events] do |filename, events|
    puts "#{filename} #{events.inspect}"
  end

  # do on a cron-like schedule (sec, min, hour, month, day, day-of-week)
  on_schedule "0 */15 * * * *" do |now|
    puts "BING BONG"
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

Demogorgon can be equipped with an ACID memory which will survive crashes and
restarts.

```ruby
require "demogorgon"
require "acid"

acid = Acid.new do

  log_file "state"

  init do
    0
  end

  view :show do |s|
    s.to_s
  end

  method :bump! do |s|
    s + 1
  end

end

Demogorgon.new do

  on_connect 12345 do |tell|
    tell[acid.show + "\n"]
    acid.bump!
  end

end
```


