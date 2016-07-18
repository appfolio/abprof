# Abprof

ABProf attempts to use simple A/B test statistical logic and apply it
to the question, "which of these two programs is faster?"

Most commonly, you profile by running a program a certain number of
times ("okay, burn it into cache for 100 iterations, then run it 5000
times and divide the total time by 5000"). Then, you make changes to
your program and do the same thing again to compare.

Real statisticians inform us that there are a few problems with that
approach :-)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'abprof'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install abprof

## Usage

Loading and running a program is slow, and it adds a lot of variable
overhead which can make it hard to sample the specific operations that
you want to measure. So ABProf prefers to run both programs and then
just sample them on demand. That requires a bit of an interface for
the programs you're running.

In Ruby, there's an ABProf library you can use which will take care of
that interface. That's the easiest way to use it, especially since
you're running a benchmark anyway and would need some structure around
your code.

In the future there may also be a "just run the program, even though
that's slow" mode.

For a Ruby snippet to be profiled, do this:

    require "abprof"

    ABProf::ABWorker.iteration do
      # Code to measure goes here
	  sleep 0.1
    end

    ABProf::ABWorker.start

With two such snippets, you can compare their speed.

Under the hood, ABProf uses a simple communication protocol over STDIN
and STDOUT to allow the controlling process to tell the workers to run
iterations. Mostly that's great, but it means you'll need to make sure
your worker processes aren't using STDIN for anything else.

### Quick Start

Want to have fun with something that already works? I usually do. See
the examples directory. For instance:

    abprof examples/sleep.rb examples/sleep.rb

If abprof is just in the source directory and not installed as a gem,
you should add RUBYLIB="lib" before "abprof" above to get it to run.

### More Control

Would you like to explicitly return the value(s) to compare? You can
replace the "iteration" block above with "iteration\_with\_return\_value"
or "n\_iterations\_with\_return\_value". In the former case, return a
single number at then end of the block, which is the measured value
specifically for that time through the loop. In the latter case, your
block will take a single parameter N for the number of iterations -
run the code that many times and return either a single measured speed
or time, or an array of speeds or times, which will be your samples.

This can be useful when running N iterations doesn't necessarily
generate exactly N results, or when the time the whole chunk of code
takes to run isn't the most representative number for performance. The
statistical test will help filter out random test-setup noise
somewhat, but sometimes it's best to not count the noise in your
measurement at all, for many good reasons.

### Comparing Rubies

I'm AppFolio's Ruby fellow, so I'm writing this to compare two
different locally-built Ruby implementations for speed. Here's the
easiest way to do that:

### How Many Times Faster?

ABProf will try to give you an estimate of how much faster one option
is than the other. Be careful taking it at face value -- if you do a
series of trials and coincidentally get a really different-looking
run, that may give you an unexpected P value *and* an unexpected
number of times faster/better/different.

In other words, those false positives will tend to happen *together*,
not independently. If you want to actually check how much faster one
is than the other in a less-biased way, set the number of trials
and/or iterations very high, or manually run both yourself some large
number of times, rather than letting it converge to a P value and then
taking the result from the output.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Credit Where Credit Is Due

I feel like I maybe saw this idea (use A/B test math for a profiler)
somewhere else before, but I can't tell if I really did or if I
misunderstood or hallucinated it. Either way, why isn't this a
standard approach that's built into most profiling tools?

After I started implementation I found out that optcarrot, used by the
Ruby core team for profiling, is already using this technique (!) -- I
stole a few tricks from their implementation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/appfolio/abprof. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

