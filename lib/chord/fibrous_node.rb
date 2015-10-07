require 'chord/node'
#require 'rpc' # Once the fork of emrpc is ready
require 'emrpc'
require 'chord/deferrable'
require 'uri'
require 'chord/uuid'
require 'fiber'

class Chord

  #####
  # A Chord::Node encapsulates all of the logic necessary to
  # manage a node within a chord.
  class FibrousNode < Node
    include EMRPC::Pid

    attr_accessor :uri

    #####
    # Create a new, networked Chord Node.
    # Params:
    #   uri:
    #   scheme:
    #   host:
    #   port:
    def initialize(args = {:uri => 'emrpc://127.0.0.1:0'})
      args = normalize_uri_args(args)
      @uri = create_full_uri(args)
      @uri_to_remote_pid_map = {}
      @invocation_callbacks = {}

      if EventMachine.reactor_running?
        bind(@uri)
        _,actual_port = socket_information
        @uri.sub(/\d+$/,actual_port)
        @uri = @name = create_full_uri({:uri => @uri, :port => socket_information[0] })
        super(@uri) # Calls Pid #initialize, which will call Node #initialize
      else
        raise "The EventMachine reactor was not running."
      end
    end

    def normalize_uri_args(args)
      # TODO: This is all broken for unix sockets. Fix that.
      if Hash === args
        args[:uri] = '' unless args.has_key?(:uri)
      elsif args.respond_to?(:uri)
        args = {:uri => args.uri}
      else
        args = {:uri => args}
      end
      args
    end

    def create_full_uri(args)
      u = URI.parse(args[:uri])
      s = u.scheme
      h = u.host
      p = u.port
      @scheme = args[:scheme] || s || 'emrpc'
      @host = args[:host] || h || '127.0.0.1'
      @port = args[:port] || p || 0
      "#{@scheme}://#{@host}:#{@port}"
    end

    def successors
      @successors
    end

    def successor
      # This is lame. It doesn't protect against the successor being
      # dead. If we are going to do it this way, there needs to be
      # some error handling in the code that depends on this. We could
      # check a successor's validity before returning it, but that creates
      # a race condition because a given successor may die in the midst of
      # an operation that utilizes it. So, error handling within the
      # methods below is probably the superior option.
      r = @successors.last
      r
    end

    # Given an ID, figure out which node should be the predecessor to that ID.
    def find_predecessor(id)
        if self == successor
          self
        else
          pred = self
          while !between_left_inclusive(id, invoke_on(pred, :nodeid), invoke_on(invoke_on(pred, :successor), :nodeid))
            pred = invoke_on(pred, :closest_preceding_node, id)
          end

          pred
        end
    end

    def closest_preceding_node(id)
      r = nil
      Fiber.new do
        (KeySpace-1).downto(0) do |i|
          next if @finger_table[i].nil?
          if (between_exclusive(invoke_on(@finger_table[i], :nodeid), @nodeid, id))
            r = @finger_table[i]
            break
          end
        end
      end.resume
      # Can't find anyone else, so it must be self?
      r ? r : self
    end

    def find_successor(id)
        # First determine if it is between this node and its successor.
        sn = successors.nodeid
        if between_right_inclusive(id, @nodeid, sn)
          # If it is, this node's successor is the successor of id
          successor
        else
          # If it is not, find the closest preceding node and repeat
          # the check, in a recursive fashion. This will tend to find
          # the correct node in O(log n) checks.
          # TODO: Change this to an iterative search? It's more ugly,
          # but iteration is more efficient that recursion in Ruby.
          np = closest_preceding_node(id)
          r = invoke_on(np, :find_successor, id)
          r
        end
    end

    def find(id)
      Fiber.yield(_find(Fiber.current,id))
    end

    def _find(cf,id)
      cf.resume(find_successor(id))
    end

    def acquire_successors(node)
        my_successors = SuccessorList.new(invoke_on(node, :successors))
        my_successors.shift if my_successors.length == @successor_queue_depth
        my_successors.push node
        @successors = my_successors
    end

    # Join the chord that the given node is already in by acquiring that node's
    # successors and merging it with them to be our successors. As soon as this
    # node stabilize()s for the first time, news of its existence will start to
    # propagate, and the node will become part of the Chord.
    def join(args)
      args = normalize_uri_args(args)
      uri  = create_full_uri(args)
      self.connect(uri) do |node|
        @uri_to_remote_pid_map[uri] = node

        Fiber.new do
          s = invoke_on(node, :find_predecessor, @nodeid)
          p = nil
          begin
            p = s
            s = invoke_on(p, :successor)
          end until between_left_inclusive(@nodeid, invoke_on(p, :nodeid), invoke_on(s, :nodeid))
          acquire_successors(s)
          @predecessor = p
          invoke_on(s, :receive_notification, self)
          invoke_on(p, :receive_notification, self) unless s == p
          initialize_finger_table(s)
          stabilize
          notify
          invoke_on(s, :reallocate_data, invoke_on(p, :nodeid), self)
        end.resume
      end
    end

    def receive_notification(node)
      Fiber.new do
        if between_exclusive(invoke_on(node, :nodeid), @nodeid, successors.nodeid)
          @finger_table[0] = node
          acquire_successors(node)
        end
        if @predecessor.nil? || between_exclusive(invoke_on(node, :nodeid), invoke_on(@predecessor, :nodeid), @nodeid)
          @predecessor = node
        end
        stabilize
      end.resume
    end

    # Find all nodes for which this node has become a finger in their finger table,
    # and notify them.
    # TODO: Doing this monolithically, all at once, seems expensive -- maybe this happens asynchronous, over time?
    def notify
      KeySpace.times do |position|
        do_notify(position)
      end
    end

    def do_notify(position)
        predecessor = find_predecessor(calculate_backwards_finger_position(@nodeid, position))
        invoke_on(predecessor, :update_finger_table, self, position)
    end

    # node is a valid finger at position, note it in the finger table.
    # Because the odds are high that for larger values of position, this
    # node will also be a finger at this position for the predecessor,
    # have it check, too.
    def update_finger_table(node,position)
        node_nodeid = invoke_on(node, :nodeid)
        if node != self && between_right_inclusive(node_nodeid,@nodeid,calculate_finger_position(node_nodeid,position))
          @finger_table[position] = node
        end
    end

    def stabilize
#        Fiber.new do
        x = predecessor
        if x
          x = invoke_on(x, :successor)
          if between_exclusive(invoke_on(x, :nodeid), invoke_on(predecessor, :nodeid), @nodeid)
            @predecessor = x
            invoke_on(@predecessor, :receive_notification, self)
          end
        end

        x = successors.predecessor
        if (!x.nil? && between_exclusive(invoke_on(x, :nodeid), @nodeid, successors.nodeid))
          acquire_successors(x)
          successors.receive_notification(self)
        end
#       end.resume
    end

    # This gets called periodically to help keep the finger table updated.
    # If something goes away unexpectedly, without any notification, this will
    # figure it out eventually.
    def fix_fingers
      @finger_table_index += 1
      @finger_table_index = 1 if @finger_table_index > KeySpace
      @finger_table[@finger_table_index] = find_successor(calculate_finger_position(@nodeid,@finger_table_index))

      @finger_table_index
    end

    def initialize_finger_table(node)
        KeySpace.times {|n| @finger_table[n] = invoke_on(node, :find_successor, calculate_finger_position(@nodeid, n)) if @finger_table[n].nil?}
    end

    def heartbeat
      1
    end

    # In a real networked version of this, check_predecessor needs to be
    # overridden to perform a simple call. If it gets a response from the
    # heartbeat, then the node is still alive. Otherwise, it has died.
    def check_predecessor
      Fiber.new do
        @predecessor = nil if !(@predecessor == nil || invoke_on(@predecessor, :heartbeat) != 1)
      end.resume
    end

    # This retrieves the workload of our successor.
    def check_workload
      successors.get_workload
    end

    # Returns an array containing the nodeid of the node and the count of its
    # current workload. This is typically called by the node's predecessor as
    # part of the automatic workload balancing algorithm.
    def workload
      [@nodeid,@data.count]
    end

    # This is called periodically to balance this node's workload with that of
    # its successor.
    def balance_workload
      successor_id, successor_workload = successors.workload
      shared_workload = workload.last + successor_workload
      if shared_workload > 10 && (workload.last + calculate_allowable_difference(shared_workload)) < successor_workload
        old_nodeid = @nodeid
        @nodeid = calculate_target_id(@nodeid, workload.last, successor_id, successor_workload)
        successors.reallocate_data(old_nodeid, self)
      end
    end

    # An algorithm to describe the magnitude of variation between the
    # quantity of data that is allowed between any two neighboring nodes.
    # This current algorithm permits the absolute amount of variation to
    # increase slightly as the quantity of data increases, but the change
    # is logarithmic in scale.
    def calculate_allowable_difference(n)
      # Todo: Does this give a decent behavior, or is there an intelligent
      # refinement to make here?
      Math.sqrt( (n / (Math.log(n) ** 2)) ).to_i
    end

    # Take two ids (positions), and the workloads held by each node, and
    # calculate how far to advance the position of the left node so that,
    # given equally distributed keys, the nodes end up with approximately
    # balanced workloads.
    def calculate_target_id(left_id, left_weight, right_id, right_weight)
      left_id_int = Integer("0x#{left_id}")
      right_id_int = Integer("0x#{right_id}")
      if right_id > left_id
        difference = right_id_int - left_id_int
      else
        difference = KeyBitMask - left_id_int + right_id_int
      end
      portion = difference / right_weight
      ((left_id_int + (portion * ((right_weight - left_weight) / 2))) % KeyBitMask).to_s(16)
    end

    # Add the given key and value to this node's data store.
    def accept_data(key,value)
      @data[key] = value
    end

    def []=(key, value)
      @data[key] = value
    end

    def [](key)
      @data[key]
    end

    # This will send any of our data that sits between oldnodeid and
    # node.nodeid over to node.
    # TODO: Moving keys should be fast and cheap. Moving data could be
    # TODO: expensive. Maybe it wold be reasonable to just move keys,
    # TODO: with a pointer to where the data really is, and then allow
    # TODO: the data to migrate a little at a time?
    def reallocate_data(oldnodeid, node)
      Fiber.new do
      data_to_remove = []
      node_nodeid = invoke_on(node, :nodeid)
      @data.each do |key, value|
          if between_right_inclusive(key, oldnodeid, node_nodeid)
          node.accept_data(key, value)
          data_to_remove << key
        end
      end
      data_to_remove.each {|key| @data.delete(key)}
      end.resume

    end

  end
end
