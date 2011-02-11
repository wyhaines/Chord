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
      include Pid

      #####
      # Create a new, networked Chord Node.
      # Params:
      #   uri:
      #   scheme:
      #   host:
      #   port:
      def initialize(args = {:uri => 'emrpc://127.0.0.1:0'})
        args[:uri] = '' unless args.has_key?(:uri)
        u = URI.parse(args[:uri])
        s = URI.scheme
        h = URI.host
        p = URI.port
        @scheme = args[:scheme] || s || 'emrpc'
        @host = args[:host] || h || '127.0.0.1'
        @port = args[:port] || p || 0
        @uri = "#{@scheme}://#{@host}:#{@port}"
        super(@uri)
      end

    end
  end
end