module Swiftcore

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

      def method_missing(meth, *args)
        while !empty?
          begin
            return last.send(meth, *args)
          rescue Exception
            # If we land here, something failed while trying to invoke a method on a successor.
            pop
          end
        end
        # TODO: If execution fell to here, all of the successors are gone. Now what?
      end

    end
  end
end

