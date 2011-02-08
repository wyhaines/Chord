require "digest/sha2"
require 'swiftcore/chord/node'

module Swiftcore

  #####
  #
  # Swiftcore::Chord
  #
  # This is an implementation of the Chord protocol, descriptions of which
  # can be found here:
  #   http://pdos.csail.mit.edu/chord/papers/chord.pdf
  #   http://pdos.csail.mit.edu/chord/papers/paper-ton.pdf
  #   http://en.wikipedia.org/wiki/Chord_%28peer-to-peer%29
  #
  # The implementation is based closely on the pseudocode found in those
  # papers, with some modifications for both functionality and resiliency.
  #
  # As it stands currently, nodes can balance their workload with their
  # successor. It currently does this by comparing its workload to the load
  # of the successor. If the successor has a sufficiently larger load, as
  # determined by the Swiftcore::Chord::Node#calculate_allowable_difference
  # method, then the node will advance its ID, and thus, the keyspace that it
  # is responsible for, towards that of its successor. It then tells its
  # successor to reallocate data that lies in the new keyspace to it.
  #
  # By only moving towards a successor, without ever changing relative
  # positions, changing a node's id/keyspace coverage doesn't harm the ability
  # of the the chord to find the data in any given node, and the balancing
  # algorithm will eventually result in well distributed nodes, even as data
  # changes and nodes are added or removed from the chord.
  #
  #####

  #####
  # This class is intended to represent the interface to an entire chord.
  # It can be used to join nodes to the chord, or to send queries into the
  # chord.
  class Chord
    KeySpace = 256
    MaximumKeyLength = (KeySpace / 4) - 1
    KeyBitMask = (1 << KeySpace) - 1 # Bit shifting FTW when doing powers of 2

    attr_reader :origin

    def initialize(*args)
      @origin = Node.new(*args)
    end

    # Joins the given node to the chord.
    def join(node)
      node.join(@origin)
    end

    def query(id)
      @origin.find_successor(id)
    end

  end
end
