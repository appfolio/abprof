# ABProf

ABProf attempts to use simple A/B test statistical logic and apply it
to the question, "which of these two programs is faster?"

Most commonly, you profile by running a program a certain number of
times ("okay, burn it into cache for 100 iterations, then run it 5000
times and divide the total time by 5000"). Then, you make changes to
your program and do the same thing again to compare.

Real statisticians inform us that there are a few problems with that
approach :-)

We use a [Welch's T Test](https://en.wikipedia.org/wiki/Welch%27s_t-test) on a
set of measured runtimes to determine how likely the two programs are
to be different from each other, and after the P value is low enough,
we give our current estimate of which is faster and by how much.

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

### Quick Start - Run Two Programs

The simplest way to use ABProf is the "abcompare" command. Give it two
commands, let it run them for you and measure the results. If your
command contains spaces, put it in quotes - standard shell
programming.

    $ abcompare "cd ../vanilla_ruby && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes >> /dev/null" \
      "cd ../alt_ruby && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes >> /dev/null"

This defaults to basic settings (10 iterations of burn-in before
measuring, P value of 0.05, etc.)  You can change them on the command
line. Running this way is simple, straightforward, and will take
a little longer to converge since it's paying the start-a-process tax every
time it takes a measurement.

Run "abcompare --help" if you want to see what command-line options
you can supply. For more control in the results, see below.

The abcompare command is identical to abprof except that it uses a raw
command, not harness code. See below for details.

### Quick Start - Test Harness

Loading and running a program is slow, and it adds a lot of variable
overhead. That can make it hard to sample the specific operations that
you want to measure. ABProf prefers to just do the operations you want
without restarting the worker processes constantly. That takes a bit
of harness code to do well.

In Ruby, there's an ABProf library you can use which will take care of
that interface. That's the easiest way to use it, especially since
you're running a benchmark anyway and would need some structure around
your code.

For a Ruby snippet to be profiled very simply, do this:

    require "abprof"

    ABProf::ABWorker.iteration do
      # Code to measure goes here
	  sleep 0.1
    end

    ABProf::ABWorker.start

With two such files, you can compare their speed.

Under the hood, ABProf's harness uses a simple communication protocol
over STDIN and STDOUT to allow the controlling process to tell the
workers to run iterations. Mostly that's great, but it means you'll
need to make sure your worker processes aren't using STDIN for
anything else.

See the examples directory for more. For instance:

    abprof examples/sleep.rb examples/sleep.rb

If abprof is just in the source directory and not installed as a gem,
you should add RUBYLIB="lib" before "abprof" above to get it to run.

### Quick Start - Benchmark DSL

Want to make a benchmark reproducible? Want better accuracy? ABProf
has a DSL (Domain-Specific Language) that can help here.

Here's a simple example:

    require "abprof/benchmark_dsl"

    ABProf.compare do
      warmup 10
      max_trials 5
      min_trials 3
      p_value 0.01
      iters_per_trial 2
      bare true

      report do
        10_000.times {}
      end

      report do
        sleep 0.1
      end

    end

Note that "warmup" is a synonym for "burnin" here -- iterations done
before ABProf starts measuring and comparing. The "report" blocks are
run for the sample. You can also have a "report_command", which takes
a string as an argument and uses that to take a measurement.

### A Digression - Bare and Harness

"Harness" refers to ABProf's internal testing protocol, used to allow
multiple processes to communicate. A "harness process" or "harness
worker" means a second process that is used to take measurements, and
can do so repeatedly without having to restart the process.

A "bare process" means one where the work is run directly. Either a
new process is spawned for each measurement (slow, inaccurate) or a
block is run in the same Ruby process (potential for inadvertent
cross-talk.)

In general, for a "harness" process you'll need to put together a .rb
file similar to examples/sleep.rb or examples/for\_loop_10k.rb.

You can use the DSL above for either bare or harness processes ("bare
true" or "bare false") without a problem. But if you tell it to use a
harness, the process in question should be reading ABProf commands
from STDIN and writing responses to STDOUT in ABProf protocol,
normally by using the Ruby Test Harness library.

### Don't Cross the Streams

Harness-enabled tests expect to run forever, fielding requests for
work.

Non-harness-enabled tests don't know how to do harness stuff.

If you run the wrong way (abcompare with a harness, abprof with no
harness,) you'll get either an immediate crash or running forever
without ever finishing burn-in, depending which way you did it.

Normally you'll handle this by just passing your command line directly
to abcompare rather than packaging it up into a separate Ruby script.

### Comparing Rubies

I'm AppFolio's Ruby fellow, so I'm writing this to compare two
different locally-built Ruby implementations for speed. The easiest
way to do that is to build them in multiple directories, then build a
wrapper that uses that directory to run the program in question.

You can see examples such as examples/alt\_ruby.rb and
examples/vanilla\_ruby.rb and so on in the examples directory of this
gem.

Those examples use a benchmark called "optcarrot" which can be quite
slow. So you'll need to decide whether to do a quick, rough check with
a few iterations or a more in-depth check which runs many times for
high certainty.

Here's a slow, very conservative check:

    abprof --burnin=10 --max-trials=50 --min-trials=50 --iters-per-trial=5 examples/vanilla_ruby.rb examples/inline_ruby_1800.rb

Note that since the minimum and maximum trials are both 50, it won't
stop at a particular certainty (P value.) It will just run for 50
trials of 5 iterations each. It takes awhile, but gives a pretty good
estimate of how fast one is compared to the other.

Here's a quicker, rougher check:

    abprof --burnin=5 --max-trials=10 --iters-per-trial=1 examples/vanilla_ruby.rb examples/inline_ruby_1800.rb

It may stop after only a few trials if the difference in speed is big
enough. By default, it uses a P value of 0.05, which is (very roughly)
a one in twenty chance of a false result.

If you want a very low chance of a false positive, consider adjusting
the P value downward, to more like 0.001 (0.1% chance) or 0.00001
(0.001% chance.) This may require a lot of time to run, especially if
the two programs are of very similar speed, or have a lot of
variability in the test results.

    abprof --burnin=5 --max-trials=50 --pvalue 0.001 --iters-per-trial=1 examples/sleep.rb examples/for_loop_10k.rb

### How Many Times Faster?

ABProf will try to give you an estimate of how much faster one option
is than the other. Be careful taking it at face value -- if you do a
series of trials and coincidentally get a really different-looking
run, that may give you an unexpected P value *and* an unexpected
number of times faster.

In other words, those false positives will tend to happen *together*,
not independently. If you want to actually check how much faster one
is than the other in a less-biased way, set the number of trials
and/or iterations very high, or manually run both yourself some large
number of times, rather than letting it converge to a P value and then
taking the result from the output.

See the first example under "Comparing Rubies" for one way to do
this. Setting the min and max trials equal is good practice for this
to reduce bias.

### Does This Just Take Forever?

It's easy to accidentally specify a very large number of iterations
per trial, or total trials, or otherwise make testing a slow program
take *forever*. Right now, you'll pretty much just need to notice that
it's happening and drop the iters-per-trial, the min-trials, or the P
value. When in doubt, try to start with just a very quick, rough test.

Of course, if your test is *really* slow, or you're trying to detect a
very small difference, it can just take a really long time. Like A/B
testing, this method has its pitfalls.

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

Note: this technique has some subtleties -- you're better off *not*
doing this to rapidly collect many, many samples of very small
performance differences, because transient conditions like background
processes can skew the results a *lot* when many T-test samples are
collected in a short time. You're much better off running the same
operation many times and returning the cumulative value in those
cases, or otherwise controlling for transient conditions that drift
over time.

In those cases, either set the iters-per-trial very low (likely to 1)
so that both processes are getting the benefit/penalty from transient
background conditions, or set the number of iterations per trial very
high so that each trial takes several seconds or longer, to allow
transient conditions to pass.

ABProf also runs the two processes' iterations in a random order by
default, starting from one process or the other based on a per-trial
random number. This helps a little, but only a little. If you *don't*
want ABProf to do that for some reason, turn on the static_order
option to get simple "process1 then process2" order for every trial.

## Development

After checking out the repo, run `bin/setup` to install
dependencies. Then, run `rake test` to run the tests. You can also run
`bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake
install`. To release a new version, update the version number in
`version.rb`, and then run `bundle exec rake release`, which will
create a git tag for the version, push git commits and tags, and push
the `.gem` file to [rubygems.org](https://rubygems.org).

## Credit Where Credit Is Due

I feel like I maybe saw this idea (use A/B test math for a profiler)
somewhere else before, but I can't tell if I really did or if I
misunderstood or hallucinated it. Either way, why isn't this a
standard approach that's built into most profiling tools?

After I started implementation I found out that optcarrot, used by the
Ruby core team for profiling, is already using this technique (!) -- I
am using it slightly differently, but I'm clearly not the first to
think of using a statistics test to verify which of two programs is faster.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/appfolio/abprof. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected
to adhere to the
[Contributor Covenant](http://contributor-covenant.org) code of
conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
