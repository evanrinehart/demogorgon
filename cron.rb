require 'time'

module Cron

  class Spec

    class InvalidSpec < StandardError; end

    def parse_section min, max, raw
      all = (min .. max).to_a

      raw.split(',').map do |x|
        if x == '*'
          all
        else
          div = x[/^\*\/(\d+)$/, 1]
          if div
            all.select{|x| x % div.to_i == 0}
          else
            match = x.match /^(\d+)-(\d+)$/
            if match
              a = match[1].to_i
              b = match[2].to_i
              unless a>=min && a<=max && b>=min && b<=max
                raise InvalidSpec, "out of range"
              end
              (a .. b).to_a
            else
              match = x.match /^(\d+)$/
              if match
                a = match[1].to_i
                unless a>=min && a<=max
                  raise InvalidSpec, "out of range"
                end
                [a]
              else
                raise InvalidSpec, "unable to parse expression"
              end
            end
          end
        end
      end.reduce([], :|)

    end

    def initialize raw
      @raw = raw

      parts = raw.split(' ')
      raise InvalidSpec, "you must have six fields" if parts.length != 6

      days_of_week = parse_section(0,7,parts[5])
      months = parse_section(1, 12, parts[4])
      days = parse_section(1, 31, parts[3])
      hours = parse_section(0, 23, parts[2])
      minutes = parse_section(0, 59, parts[1])
      seconds = parse_section(0, 59, parts[0])

      if days_of_week.delete(7)
        days_of_week.delete(0)
        days_of_week.insert 0, 0
      end

      @spec = {
        :seconds => seconds,
        :minutes => minutes,
        :hours => hours,
        :days => days,
        :days_of_week => days_of_week,
        :months => months
      }
    end

    def spec
      @spec
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
