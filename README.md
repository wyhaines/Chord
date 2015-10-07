# Chord

This is an implementation of the Chord protocol, a description of which
can be found here:
  http://pdos.csail.mit.edu/chord/papers/chord.pdf
  http://pdos.csail.mit.edu/chord/papers/paper-ton.pdf
  http://en.wikipedia.org/wiki/Chord_%28peer-to-peer%29

The implementation is based on the psuedocode and implementation suggestions
in the MIT papers, but it has some modifications.

As it stands currently, nodes can balance their workload with their
successor. It currently does this by comparing its workload to the load
of the successor. If the successor has a sufficiently larger load, as
determined by the Swiftcore::Chord::Node#calculate_allowable_difference
method, then the node will advance its ID, and thus, the keyspace that it
is responsible for, towards that of its successor. It then tells its
successor to reallocate data that lies in the new keyspace to it.

By only moving towards a successor, without ever changing relative
positions, changing a node's id/keyspace coverage doesn't harm the ability
of the the chord to find the data in any given node, and the balancing
algorithm will eventually result in well distributed nodes, even as data
changes and nodes are added or removed from the chord.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chord'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chord

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wyhaines/chord. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

