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

  def self.parse raw
    # split on ,
    # parse depending on if contains - / * or not
    # * means all
    # / means filter by divisibility
    # , means union
    # number is a single element list
    # a-b means inclusive range

    # * and validation depends on position 1 though 6

    {
      :seconds => [0],
      :minutes => [0],
      :hours => [15],
      :day => (1..31).to_a,
      :day_of_week => [0,1,2,3,4,5,6],
      :month => (1..12).to_a
    }
  end

  def self.compute_spec_next_time spec, now
    # now is either equal to, precedes one, or comes after all times in the spec
    # if equal try again with now+1 second
    # if preceding, the time it precedes is the answer
    # if after all, use use first time in spec (with next years year) as the answer
  end

  class Queue

    def initialize
      @queue = []
    end

    def insert now, spec, payload
      # get time with spec
      # find first element with time greater and insert before
    end

    def dequeue now
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
