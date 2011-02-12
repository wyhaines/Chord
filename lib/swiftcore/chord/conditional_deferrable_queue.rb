module Swiftcore
  class Chord
    class ConditionalDeferrableQueue
      def initialize
        @queue = []
      end

      def << (conditional_deferrable)
        @queue << conditional_deferrable
      end

      def clear
        @queue = []
      end

      def execute
        endpoint = @queue.length - 1

        @queue[0..endpoint].each do |conditional_deferrable|
          next unless conditional_deferrable && conditional_deferrable.respond_to?(:deferred_status?)
          ds = conditional_deferrable.status?
          case ds
            when :succeeded
              # Call the deferrable's callbacks.
              conditional_deferrable.succeed(conditional_deferrable)
            when :failed
              # Call the deferrable's errbacks.
              conditional_deferrable.fail(conditional_deferrable)
            else
              # State is unknown, so requeue this one to check it again later.
              @queue << conditional_deferrable
          end
        end

        @queue = (@queue.length > (endpoint + 1)) ? @queue[(endpoint + 1)..-1] : []
      end

      def first
        @queue.first
      end

      def size
        @queue.size
      end
    end
  end
end
