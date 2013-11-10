require 'time'
require 'date'

module Cron

  class Spec

    class InvalidSpec < StandardError; end
    class NextIsOnLeapDay < StandardError; end

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

    # return the next time an event will occur according to this spec
    # returns nil if spec denotes an empty set of event times (Feb 31)
    def next now
      next_in_set = lambda do |v, set|
        ans = set.find{|x| v <= x}
        if ans
          [ans, 0]
        else
          [set.first, 1]
        end
      end

      second, carry = next_in_set[now.sec, @spec[:seconds]]
      minute, carry = next_in_set[now.min+carry, @spec[:minutes]]
      hour, carry = next_in_set[now.hour+carry, @spec[:hours]]
      month1, carry = next_in_set[now.month, @spec[:months]]
      year1 = now.year + carry
      if now.month==month1 && now.year==year1
        days1 = calc_days(month1, year1)
        day1, carry = next_in_set[now.day, days1]
        if carry == 1 # year1 month1 and day1 are invalid results try again
          month, carry = next_in_set[now.month+1, @spec[:months]]
          year = now.year + carry
          days = calc_days(month, year)
          day = days.first
        else
          year = year1
          month = month1
          day = day1
        end
      else
        year = year1
        month = month1
        days = calc_days(month, year)
        day = days.first
      end

      if day.nil? && @spec[:months].include?(2) && @spec[:days].include?(29)
        # then nil is not the correct response, there will be some leap day at some point
        day = 29
        leap_year = next_leap_year(year)
        s = "%d-%02d-%02d %02d:%02d:%02d" % [leap_year,month,day,hour,minute,second]
        Time.parse(s).to_i
      elsif day.nil?
        nil
      else
        s = "%d-%02d-%02d %02d:%02d:%02d" % [year,month,day,hour,minute,second]
        Time.parse(s).to_i
      end

    end

    def next_leap_year starting_year
      y = Date.new(starting_year)
      until y.leap?
        y = Date.new(y.year + 1)
      end
      y.year
    end

    def calc_days month, year
      all = []
      d = Date.parse("%d-%02d-01" % [year,month])
      while d.month == month
        all.push(d)
        d = d + 1
      end

      if month==2 && Date.new(year).leap?
        all.push(Date.parse("#{year}-02-29"))
      end

      days = @spec[:days]
      days_of_week = @spec[:days_of_week]
      set = if days_of_week && days.nil?
        all.select{|d| days_of_week.include?(d.wday)}
      elsif days_of_week.nil? && days
        all.select{|d| days.include?(d.day)}
      elsif days_of_week && days
        all.select{|d| days_of_week.include?(d.wday) || days.include?(d.day)}
      else
        all
      end
      set.map{|d| d.day}
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
