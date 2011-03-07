require 'test/unit'
require 'benchmark'
require 'swiftcore/chord'
require 'swiftcore/chord/fibrous_node'

class Client
  attr_accessor :cid

  @seq = 0

  def self.seq
    @seq += 1
  end

  def initialize
    @cid = Digest::SHA256.new
    @cid << Time.now.to_f.to_s
    @cid << rand.to_s
    @cid << rand.to_s
    @sequence = self.class.seq
  end

  def to_s
    @sequence
  end

end

class TestChord < Test::Unit::TestCase

  def test_chord
    chord = nil
    nodes = []

    assert_nothing_raised do
      chord = Swiftcore::Chord.new('a')
      nodes << chord.origin
    end

    assert_equal(chord.class, Swiftcore::Chord)

    assert_equal(chord.origin.class, Swiftcore::Chord::Node)

    assert_nothing_raised do
      node = Swiftcore::Chord::Node.new('b')
      nodes << node
      chord.join(node)
    end

    found_node = nil

    assert_nothing_raised do
      found_node = chord.query("ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48ba")
    end

    assert_same(nodes[0],found_node)

    assert_nothing_raised do
      found_node = chord.query("3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009c")
    end

    assert_same(nodes[1], found_node)
  end
  
  def add_node(klass = Swiftcore::Chord::Node, *args)
    @key = @key.succ
    args.unshift @key
    node = klass.new(*args)
    @nodes << node
    node.join(@chord.origin)
  end

  def test_node
    @key = 'a'
    @chord = Swiftcore::Chord.new(@key)
    @nodes = [@chord.origin]

    # Build a nominally functional ring
    6.times { add_node }

    sorted_nodes = @nodes.sort {|a,b| a.nodeid.to_i(16) <=> b.nodeid.to_i(16)}

    names_in_sorted_order = sorted_nodes.collect {|n| n.name}
    assert_equal(names_in_sorted_order, %w{d f c b e a g})

    # Throw some data into the chord.
    puts "\bBenchmarking insertion of 10000 random data items into the chord"
    Benchmark.bm {|bm| bm.report {10000.times {n = Client.new; sorted_nodes[0].find_successor(n.cid.to_s)[n.cid.to_s] = n} }}

    # Node#successor
    assert_equal(sorted_nodes[0].successor.class, Swiftcore::Chord::Node)
    assert_same(sorted_nodes[0].successor, sorted_nodes[1])
    assert_same(sorted_nodes[6].successor, sorted_nodes[0])

    # Node#successors
    assert_equal(sorted_nodes[0].successors.class, Swiftcore::Chord::SuccessorList)

    # Node#find_predecessor
    assert_equal(
      sorted_nodes[5].find_predecessor("ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48ba").name,
      sorted_nodes[2].find_predecessor("ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48ba").name)

    add_node
    
    sorted_nodes = @nodes.sort {|a,b| a.nodeid.to_i(16) <=> b.nodeid.to_i(16)}
    names_in_sorted_order = sorted_nodes.collect {|n| n.name}
    assert_equal(names_in_sorted_order, %w{d f c b e h a g})

    counts = []
    sorted_nodes = @nodes.sort {|a,b| a.nodeid.to_i(16) <=> b.nodeid.to_i(16)}
    sorted_nodes.each {|n| counts << n.data.count}; nil
    std_dev = standard_deviation(counts)
    puts "\nStandard deviation of data distribution between nodes before balancing: #{std_dev} (should be around 1350-1460)"
    assert((std_dev >= 1350 && std_dev <= 1460), "Hmmm. There seems to be more variation in the data distribution for the unbalanced chord than was expected.")

    1000.times {sorted_nodes[Integer(rand(sorted_nodes.length))].balance_workload}
    counts = []
    sorted_nodes.each {|n| counts << n.data.count}; nil
    std_dev = standard_deviation(counts)
    puts "Standard deviation of data distribution between nodes after balancing: #{std_dev} (should be less than about 12)"
    assert(std_dev <= 12, "Hmmm. There seems to be more variation in the data distribution for the unbalanced chord than was expected.")
  end

  def test_node_networked
    assert_raise(RuntimeError) do
      @chord = Swiftcore::Chord.new(Swiftcore::Chord::FibrousNode, 'emrpc://127.0.0.1:4002')
    end

    # Here is where it gets fun. Tests that need the EM reactor to run are tricksy.
    EventMachine.run do
      EventMachine::Timer.new(5) {EventMachine.stop_event_loop}
      @chord = Swiftcore::Chord.new(Swiftcore::Chord::FibrousNode, 'emrpc://127.0.0.1:0')
      EventMachine::Timer.new(2) do
        puts "origin: #{@chord.origin.uri} (#{Time.now})"
        node = Swiftcore::Chord::FibrousNode.new('emrpc://127.0.0.1:0')
        puts "origin: #{@chord.origin.uri} (#{Time.now})"
        node.join(@chord.origin.uri)
        EM::Timer.new(1) do
          puts "=====\n#{node.connections.inspect}\n*****"
          puts node.uuid
        end
      end
    end
  end

  def standard_deviation(values)
    total = 0
    values.each do |v|
      total += v
    end
    mean = total / values.length
    variance = 0
    values.each {|v| variance += (v - mean)**2}
    Math.sqrt(variance / values.length)
  end
end
