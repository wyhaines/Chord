require 'chord/deferrable'

class Chord

  class SetCallbackFailed < Exception;
  end

  class ConditionalDeferrable
    include Chord::Deferrable

    def [](key)
      (@_data ||= {})[key]
    end

    def []=(key, val)
      (@_data ||= {})[key] = val
    end

    def has_key?(k)
      (@_data ||= {}).has_key?(k)
    end

    #####
    # This method will set a condition on this Deferrable. Conditions should
    # return :succeeded or true if the condition has been met.
    # If the condition has failed, it should return :failed, false, or nil.
    # If the state of the condition can not yet be determined, then it should
    # return :deferred.
    def condition &block
      return unless block

      case @deferred_status
        when :succeeded, :failed
          SetCallbackFailed.new
        else
          @conditions ||= []
          @conditions.unshift block
      end
    end

    def conditions
      (@conditions ||= []) && @conditions
    end

    #####
    # Check whether all of the conditions set on this object have been
    # met. A condition that is successful should return :succeded or
    # true. A condition that is unsuccessful should return :failed,
    # false, or nil. If the condition can not yet evaluate success or
    # failure, it should return :deferred.
    #
    # If any condition returns a :failed or a :deferred, then no
    # other conditions need to be evaluated; the status will be either
    # :failed or :unknown. If all conditions return :succeeded, then
    # the status will return :succeeded.
    def status?(*args)
      r = :unknown
      case @deferred_status
        when :succeeded, :failed
          r = @deferred_status
        else
          if @conditions
            @conditions.reverse_each do |cond|
              r = cond.call(self, *args)
              if r == true
                r = :succeeded
              elsif !r
                r = :failed
              end
              break if r == :failed or r == :deferred
            end
          else
            r = :succeeded
          end
      end
      @deferred_status = r
    end

  end
end
