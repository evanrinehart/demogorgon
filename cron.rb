require 'time'

module Cron

# *
# 1, 3, 5
# 1-5
# */15

# e = *
#   | number
#   | number-number
#   | e,e,e,...
#   | */number

  class Spec

    def initialize raw
      @raw = raw
#FIXME parse raw
      @spec = {
        :seconds => [0],
        :minutes => [0],
        :hours => [15],
        :days => (1..31).to_a,
        :days_of_week => [0,1,2,3,4,5,6],
        :months => (1..12).to_a
      }
    end

    def first year
      month = @spec[:months].first
      day = @spec[:days].first
      hour = @spec[:hours].first
      minute = @spec[:minutes].first
      second = @spec[:seconds].first
      s = "%d-%02d-%02d %02d:%02d:%02d" % [year,month,day,hour,minute,second]
      Time.parse(s).to_i
    end

    def next now
      year = now.year
      # ? FIXME
      nil
    end

  end

  class Queue

    def initialize
      @queue = []
    end

    def insert! now, spec, payload
      t = spec.next(now)
      record = {
        :timestamp => t,
        :spec => spec,
        :payload => payload
      }

      if @queue.empty?
        @queue.push(record)
      else
        i=0
        while @queue[i] && @queue[i][:timestamp] < record[:timestamp]
          i += 1
        end
        @queue.insert(i, record)
      end
    end

    def dequeue! now
      if @queue.empty?
        nil
      else
        # compute spec next time
        # reinsert spec and payload
        # return payload
      end
    end

    def eta now
      if @queue.empty?
        nil
      else
        # return time of first thing - now
      end
    end

  end

end
