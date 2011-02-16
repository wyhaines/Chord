require 'swiftcore/chord/node'
#require 'swiftcore/rpc' # Once the fork of emrpc is ready
require 'emrpc'
require 'swiftcore/chord/deferrable'
require 'uri'

module Swiftcore

  class Chord

    # This class adds RPC capabilities to a generic Node, taking the chord
    # out onto the network and allowing it to do useful work.
    # Each NetworkedNode is an independent entity that communicates with other
    # members of the chord via a given protocol (TCP or Unix sockets), and
    # socket identifier.
    class NetworkedNode < Node
      include EMRPC::Pid

      #####
      # Create a new, networked Chord Node.
      # Params:
      #   uri:
      #   scheme:
      #   host:
      #   port:
      def initialize(args = {:uri => 'emrpc://127.0.0.1:0'})
        # TODO: This is all broken for unix sockets. Fix that.
        if Hash === args
          args[:uri] = '' unless args.has_key?(:uri)
        else
          args = {:uri => args}
        end

        u = URI.parse(args[:uri])
        s = u.scheme
        h = u.host
        p = u.port
        @scheme = args[:scheme] || s || 'emrpc'
        @host = args[:host] || h || '127.0.0.1'
        @port = args[:port] || p || 0
        @uri = "#{@scheme}://#{@host}:#{@port}"

        if EventMachine.reactor_running?
          bind(@uri)
          _,actual_port = socket_information
          @uri.sub(/\d+$/,actual_port)
          super(@uri) # Calls Pid #initialize, which will call Node #initialize
        else
          raise "The EventMachine reactor was not running."
        end
      end

    end
  end
end