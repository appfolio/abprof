require "abprof"
require "statsample"

module ABProf
  class BenchmarkInstance
    attr_reader :reports

    ABProf::PROPERTIES.each do |prop|
      define_method(prop) do |*args|
        raise "Wrong number of arguments to #{prop.inspect}!" unless args.size < 2
        instance_variable_set("@#{prop}", args[0]) if args.size == 1
        instance_variable_get "@#{prop}"
      end
    end

    def initialize
      @pvalue = 0.05
      @burnin = 10
      @min_trials = 1
      @max_trials = 20
      @iters_per_trial = 10
      @bare = false

      @state = {
        :samples => [[], []],
        :p_tests => [],
        :iter => 0,
      }
    end

    # Aliases
    alias_method :warmup, :burnin
    alias_method :p_value, :pvalue

    def report_command(cmd)
      @reports ||= []
      @reports.push cmd
    end

    def report(&block)
      @reports ||= []
      @reports.push block
    end

    def run_burnin(opts = {})
      return unless @burnin > 0

      @process1.run_iters @burnin
      @process2.run_iters @burnin
    end

    def run_one_iteration(pts = {})
      @state[:samples][0] += @process1.run_iters @iters_per_trial
      @state[:samples][1] += @process2.run_iters @iters_per_trial
      @state[:iter] += 1
    end

    def run_sampling(opts = {})
      process_type = @bare ? ABProf::ABBareProcess : ABProf::ABHarnessProcess
      command1 = @reports[0]
      command2 = @reports[1]

      @process1 = process_type.new command1, :debug => @debug
      @process2 = process_type.new command2, :debug => @debug

      puts "Beginning #{@burnin} iterations of burn-in for each process." if opts[:print_output]
      run_burnin opts

      puts "Beginning sampling from processes." if opts[:print_output]

      # Sampling
      p_val = 1.0
      @max_trials.times do
        run_one_iteration opts

        # No t-test without 3+ samples
        if @state[:samples][0].size > 2
          # Evaluate the Welch's t-test
          t = Statsample::Test.t_two_samples_independent(@state[:samples][0].to_vector, @state[:samples][1].to_vector)
          p_val = t.probability_not_equal_variance
          @state[:p_tests].push p_val
          puts "Trial #{@state[:iter]}, Welch's T-test p value: #{p_val.inspect}" if opts[:print_output]
        end

        # Just finished trial number i+1. So we can exit only if i+1 was at least
        # the minimum number of trials.
        break if p_val < @pvalue && (@state[:iter] + 1 >= @min_trials)
      end

      # Clean up processes
      @process1.kill
      @process2.kill

      print_summary opts unless opts[:no_print_summary]

      p_val = @state[:p_tests][-1]
      if p_val >= @pvalue && @fail_on_divergence
        STDERR.puts "Measured P value of #{p_val.inspect} is higher than allowable P value of #{@pvalue.inspect}!"
        exit 2
      end

      @state
    end

    def print_summary(opts = {})
      p_val = @state[:p_tests][-1]
      diverged = false
      if p_val < @pvalue
        puts "Based on measured P value #{p_val}, we believe there is a speed difference."
        puts "As of end of run, p value is #{p_val}. Now run more times to check, or with lower p."

        summary11 = ABProf.summarize("mean", @state[:samples][0])
        summary12 = ABProf.summarize("median", @state[:samples][0])
        summary21 = ABProf.summarize("mean", @state[:samples][1])
        summary22 = ABProf.summarize("median", @state[:samples][1])

        fastest = "1"
        command = @reports[0]
        mean_times = summary21 / summary11
        median_times = summary22 / summary12
        if summary11 > summary21
          fastest = "2"
          command = @reports[1]
          mean_times = summary11 / summary21
          median_times = summary12 / summary22
        end

        puts "Lower (faster?) process is #{fastest}, command line: #{command.inspect}"
        puts "Lower command is (very) roughly #{median_times} times lower (faster?) -- assuming linear sampling."

        print "\n"
        puts "Process 1 mean result: #{summary11}"
        puts "Process 1 median result: #{summary12}"
        puts "Process 2 mean result: #{summary21}"
        puts "Process 2 median result: #{summary22}"
      else
        puts "Based on measured P value #{p_val} and threshold #{@pvalue}, we believe there is"
        puts "no significant difference detectable with this set of trials."
        puts "If you believe there is a small difference that wasn't detected, try raising the number"
        puts "of iterations per trial, or the maximum number of trials."
        diverged = true
      end
    end
  end

  def self.compare(opts = {}, &block)
    c = ABProf::BenchmarkInstance.new
    c.instance_eval &block

    raise "A DSL file must declare exactly two reports!" unless c.reports.size == 2

    unless opts[:no_at_exit]
      at_exit do
        puts "Exit handler" if opts[:print_output]
        c.run_sampling opts
      end
    end

    c
  end

end
