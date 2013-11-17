require 'time'
require 'date'

module Cron

  class Spec

    class InvalidSpec < StandardError; end
    class DontUseThis < StandardError; end
    class Busted < StandardError; end

    def parse_section min, max, raw, special_case=nil
      all = (min .. max).to_a

      if raw == '*'
        return special_case ? nil : all
      end

      raw.split(',').map do |x|
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
      end.reduce([], :|)

    end

    def initialize raw
      @raw = raw

      parts = raw.split(' ')
      raise InvalidSpec, "you must have six fields" if parts.length != 6

      days_of_week = parse_section(0,7,parts[5], :special_case)
      months = parse_section(1, 12, parts[4])
      days = parse_section(1, 31, parts[3], :special_case)
      hours = parse_section(0, 23, parts[2])
      minutes = parse_section(0, 59, parts[1])
      seconds = parse_section(0, 59, parts[0])

      if days_of_week && days_of_week.delete(7)
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

      @empty = check_for_inconsistent_dates months, days
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

    def check_for_inconsistent_dates months, days
      return false if days.nil?

      impossibles = [
        [2, 30],
        [2, 31],
        [4, 31],
        [6, 31],
        [9, 31],
        [11, 31]
      ]

      months.each do |month|
        days.each do |day|
          if impossibles.include? [month, day]
            return true
          end
        end
      end

      return false
    end

    def next_date start_date
      raise DontUseThis, "empty spec has no next date" if @empty

      d = start_date
      while !day_in_spec(d)
        d += 1
      end
      d
    end

    def next_time start_time
      h1 = start_time.hour
      m1 = start_time.min
      s1 = start_time.sec
      t1 = h1*3600 + m1*60 + s1
      h2, m2, s2 = last_time
      t2 = h2*3600 + m2*60 + s2
      return nil if t1 > t2
      h3 = set_search @spec[:hours], h1
      if h3 > h1
        m3 = @spec[:minutes].first
        s3 = @spec[:seconds].first
      else
        m3 = set_search @spec[:minutes], m1
        if m3.nil?
          h3 = set_search @spec[:hours], h1+1
          m3 = @spec[:minutes].first
          s3 = @spec[:seconds].first
        elsif m3 > m1
          s3 = @spec[:seconds].first
        else
          s3 = set_search @spec[:seconds], s1
          if s3.nil?
            m3 = set_search @spec[:minutes], m1+1
            if m3.nil?
              h3 = set_search @spec[:hours], h1+1
              m3 = @spec[:minutes].first
              s3 = @spec[:seconds].first
            elsif m3 > m1
              s3 = @spec[:seconds].first
            else
              raise Busted # m3 can't be equal to m1 at this point
            end
          else
            # end of algorithm
          end
        end
      end
      [h3, m3, s3]
    end

    def set_search set, start_value
      set.find{|x| start_value <= x}
    end

    def first_time
      [@spec[:hours].first, @spec[:minutes].first, @spec[:seconds].first]
    end

    def last_time
      [@spec[:hours].last, @spec[:minutes].last, @spec[:seconds].last]
    end

    def day_in_spec date
      if !@spec[:months].include?(date.month)
        false
      else
        if @spec[:days].nil? && @spec[:days_of_week].nil?
          true
        elsif @spec[:days_of_week].nil? #days are specified
          @spec[:days].include?(date.day)
        elsif @spec[:days].nil? # days of week specified
          @spec[:days_of_week].include?(date.wday)
        else # both specified
          @spec[:days].include?(date.day) || @spec[:days_of_week].include?(date.wday)
        end
      end
    end

    # return the next time an event will occur according to this spec
    # returns nil if spec denotes an empty set of event times (Feb 31)
    def next now
      return nil if @empty

      today = Date.parse(now.to_s)
      tomorrow = today + 1
      d = next_date today
      if d == today
        hour, minute, second = next_time now
        if hour.nil?
          d = next_date tomorrow
          hour, minute, second = first_time
        end
      else
        hour, minute, second = first_time
      end

      s = "%d-%02d-%02d %02d:%02d:%02d" % [
        d.year, d.month, d.day,
        hour, minute, second
      ]
      return Time.parse(s).to_i
    end

  end

  class Queue

    def initialize
      @queue = []
    end

    def insert! now, spec, payload
      t = spec.next(now)

      return if t.nil? # impossible spec, event never occurs

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
      elsif @queue.first[:timestamp] > now.to_i
        nil
      else
        record = @queue.delete_at(0)
        spec = record[:spec]
        payload = record[:payload]
        insert! now+1, spec, payload
        payload
      end
    end

    def eta now
      if @queue.empty?
        nil
      else
        [0, @queue.first[:timestamp] - now.to_i].max
      end
    end

  end

end
