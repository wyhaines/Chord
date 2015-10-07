require 'fiber'

class Chord

  #####
  # A SuccessorList is an array for storing Node instances. When a node
  # instance method is called (and right now the class takes the cheap way
  # out by using method_missing), the class sends the method request to the
  # nearest successor (the last one in the array). If that method request
  # fails, then that successor is removed from the list, and it tries again.
  # The intention is that this simplifies the code in Node by allowing
  # superficially naive access to the accessor list, with all of the error
  # handling encapsulated.
  class SuccessorList < Array

    def initialize(*args)
      @invocation_callbacks = {}
      super
    end

    def method_missing(meth, *args)
      r = nil
        while !empty?
          begin
            l = last
            if l.instance_of?(Chord::Node)
              r = l.send(meth, *args)
            else
              r = invoke_on(l, meth, *args)
            end
          rescue Exception => e
            puts e, e.backtrace
            # If we land here, something failed while trying to invoke a method on a successor.
            # This is lame, and TODO: improve it.
            pop
          end
          break
        end
      r
      # TODO: If execution fell to here, all of the successors are gone. Now what?
    end

    # Call a method on another node, setting up a block
    # to receive the result of that method invocation.
    def invoke_on(node, meth, *args)
      signature = UUID.generate
      @invocation_callbacks[signature] = Fiber.current
      EM.next_tick do
        node.on_invocation(self, signature, meth, *args)
      end
      Fiber.yield
    end

    # This receives a method invocation from another node, calls it, and then
    # makes sure that the result gets sent back in such a way that the sender
    # can deal with it.
    def on_invocation(sender, signature, meth, *args)
      Fiber.new do
        result = self.__send__(meth, *args)
        sender.finish_invocation(signature, result)
      end.resume
    end

    # This receives the result of an invocation and calls the pending block.
    def finish_invocation(signature, result)
      @invocation_callbacks.delete(signature).transfer(result) if @invocation_callbacks.has_key?(signature)
    end

  end
end
