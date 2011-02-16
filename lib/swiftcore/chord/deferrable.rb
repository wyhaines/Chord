require 'em/deferrable'

# Subclass the default EM Deferrable to permit set_deferred_status to return
# the result of the callback(s) or errback(s).

module Swiftcore
  class Chord
    class Deferrable
      include EventMachine::Deferrable

      def callbacks
        (@callbacks ||= []) && @callbacks
      end

      def errbacks
        (@errbacks ||= []) && @errbacks
      end

      def set_deferred_status status, *args
        r = nil
        cancel_timeout
        @errbacks        ||= nil
        @callbacks       ||= nil
        @deferred_status = status
        @deferred_args   = args
        case @deferred_status
          when :succeeded
            r = @callbacks.pop.call(*@deferred_args) while
                @callbacks && @callbacks.length > 0

            @errbacks.clear if @errbacks
          when :failed
            r = @errbacks.pop.call(*@deferred_args) while
                @errbacks && @errbacks.length > 0

            @callbacks.clear if @callbacks
        end
        r
      end

    end
  end
end