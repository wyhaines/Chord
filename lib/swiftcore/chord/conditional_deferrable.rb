# Copyright 2008, Engine Yard, Inc.
#
# This file is part of Vertebra.
#
# Vertebra is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Vertebra is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Vertebra.  If not, see <http://www.gnu.org/licenses/>.

# This file is a reimplementation of xmpp4r's rexmladdons. As such, it depends
# on some parts of REXML.

require 'swiftcore/chord/deferrable'

module Swiftcore
  class Chord

    class SetCallbackFailed < Exception;
    end

    class ConditionalDeferrable
      include Swiftcore::Chord::Deferrable

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
end
