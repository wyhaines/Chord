module Swiftcore
  class Chord
    # ConditionalDeferrable objects are placed into this queue. Periodically
    # the queue will be executed, and each deferrable object will have its
    # conditions evaluated. If the conditions all succeed, then the callback(s)
    # on it will execute. Those callbacks are able to queue additional future
    # work. If any of the conditions fail, then the errback(s) on the object
    # are called. If the deferrable state is unknown, it will be requeued for
    # evaluation at a later date.
    # TODO: Make this queue a two layer queue. Items which are repeatedly
    # TODO: requeued fall into the second layer, and are evaluated less often.
    # TODO: This would let slow stuff consume fewer resources during their
    # TODO: condition checks.
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
