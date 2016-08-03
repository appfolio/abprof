require "abprof/version"

require "multi_json"

# Protocol:
#   Controller sends "ITERS [integer]\n"
#   Controller sends "QUIT\n" when done
#   Test process responds with "NOT OK\n" or crashes for bad results
#   Test process responds with "VALUE 27.23432" to explicitly return a single value
#   Test process responds with "VALUES [1.4, 2.714, 39.4, -71.4]" to explicitly return many values
#     QUIT requires no response.

module ABProf
  def self.debug
    @debug
  end
  def self.debug=(new_val)
    @debug = new_val
  end

  # These are primarily for DSL use.
  PROPERTIES = [ :debug, :pvalue, :iters_per_trial, :min_trials, :max_trials, :burnin, :bare, :fail_on_divergence ]

  # This class is used by programs that are *being* profiled.
  # It's necessarily a singleton since it needs to control STDIN.
  # The bare mode can do without it, but it's needed for harness
  # processes.
  class ABWorker
    def debug string
      STDERR.puts(string) if ABProf.debug
    end
    def self.debug string
      STDERR.puts(string) if ABProf.debug
    end

    def self.iteration(&block)
      @iter_block = block
      @return = :none
    end

    def self.iteration_with_return_value(&block)
      @iter_block = block
      @return = :per_iteration
    end

    def self.n_interations_with_return_value(&block)
      @iter_block = block
      @return = :per_n_iterations
    end

    def self.run_n(n)
      debug "WORKER #{Process.pid}: running #{n} times"

      case @return
      when :none
        n.times do
          @iter_block.call
        end
        STDOUT.write "OK\n"
      when :per_iteration
        values = (0..(n-1)).map { |i| @iter_block.call.to_f }
        STDOUT.write "VALUES #{values.inspect}"
      when :per_n_iterations
        value = @iter_block.call(n)
        if value.respond_to?(:each)
          # Return array of numbers
          STDOUT.write "VALUES #{value.to_a.inspect}"
        else
          # Return single number
          STDOUT.write "VALUE #{value.to_f}"
        end
      else
        raise "Unknown @return value #{@return.inspect} inside abprof!"
      end
    end

    def self.read_once
      debug "WORKER #{Process.pid}: read loop"
      @input ||= ""
      @input += (STDIN.gets || "")
      debug "WORKER #{Process.pid}: Input #{@input.inspect}"
      if @input["\n"]
        command, @input = @input.split("\n", 2)
        debug "WORKER #{Process.pid}: command: #{command.inspect}"
        if command == "QUIT"
          exit 0
        elsif command["ITERS"]
          iters = command[5..-1].to_i
          values = run_n iters
          STDOUT.flush  # Why does this synchronous file descriptor not flush when given a string with a newline? Ugh!
          debug "WORKER #{Process.pid}: finished command ITERS: OK"
        else
          STDERR.puts "Unrecognized ABProf command: #{command.inspect}!"
          exit -1
        end
      end
    end

    def self.start
      loop do
        read_once
      end
    end
  end

  SUMMARY_TYPES = {
    "mean" => proc { |samples|
      samples.inject(0.0, &:+) / samples.size
    },
    "median" => proc { |samples|
      sz = samples.size
      sorted = samples.sort
      if sz % 2 == 1
        # For odd-length, take middle element
        sorted[ samples.size / 2 ]
      else
        # For even length, mean of two middle elements
        (sorted[ sz / 2 ] + sorted[ sz / 2 + 1 ]) / 2.0
      end
    },
  }
  SUMMARY_METHODS = SUMMARY_TYPES.keys
  def self.summarize(method, samples)
    raise "Unknown summary method #{method.inspect}!" unless SUMMARY_METHODS.include?(method.to_s)
    method_proc = SUMMARY_TYPES[method.to_s]
    method_proc.call(samples)
  end

  class ABBareProcess
    attr_reader :last_run
    attr_reader :last_iters

    def debug string
      STDERR.puts(string) if @debug && ABProf.debug
    end

    def initialize command_line, opts = {}
      @command = command_line
      @debug = opts[:debug]
    end

    def quit
      # No-op
    end

    def kill
      # No-op
    end

    def run_iters(n)
      t_start = t_end = nil
      debug "Controller of #{@pid}: #{n} ITERS"

      state = :succeeded
      n.times do
        if @command.respond_to?(:call)
          t_start = Time.now
          @command.call
          t_end = Time.now
        elsif @command.respond_to?(:to_s)
          t_start = Time.now
          system(@command.to_s)
          t_end = Time.now
          unless $?.success?
            STDERR.puts "Failing process #{@pid} after failed iteration(s), error code #{state.inspect}"
            # How to handle error with no self.kill?
            raise "Failure from command #{@command.inspect}, dying!"
          end
        else
          raise "Don't know how to execute bare object: #{@command.inspect}!"
        end
      end
      @last_run = [(t_end - t_start).to_f]
      @last_iters = n

      @last_run
    end
  end

  class ABHarnessProcess
    attr_reader :last_run
    attr_reader :last_iters

    def debug string
      STDERR.puts(string) if @debug && ABProf.debug
    end

    def initialize command_line, opts = {}
      debug "Controller of nobody yet: SPAWN"
      @in_reader, @in_writer = IO.pipe
      @out_reader, @out_writer = IO.pipe
      @in_writer.sync = true
      @out_writer.sync = true

      @pid = fork do
        STDOUT.reopen(@out_writer)
        STDIN.reopen(@in_reader)
        @out_reader.close
        @in_writer.close
        if command_line.respond_to?(:call)
          puts "Caution! An ABProf Harness process (non-bare) is being used with a block. This is almost never what you want!"
          command_line.call
        elsif command_line.respond_to?(:to_s)
          exec command_line.to_s
        else
          raise "Don't know how to execute benchmark code: #{command_line.inspect}!"
        end
        exit! 0
      end
      @out_writer.close
      @in_reader.close

      @debug = opts[:debug]
      debug "Controller spawned #{@pid} (debug: #{@debug.inspect})"
    end

    def quit
      debug "Controller of #{@pid}: QUIT"
      @in_writer.write "QUIT\n"
    end

    def kill
      debug "Controller of #{@pid}: DIE"
      ::Process.detach @pid
      ::Process.kill "TERM", @pid
    end

    def run_iters(n)
      debug "Controller of #{@pid}: #{n} ITERS"
      @in_writer.write "ITERS #{n.to_i}\n"

      ignored_out = 0
      state = :failed
      t_start = Time.now
      loop do
        # Read and block
        output = @out_reader.gets
        ignored_out += output.length
        puts "Controller of #{@pid} out: #{output.inspect}" if @debug
        debug "Controller of #{@pid} out: #{output.inspect}"
        if output =~ /^VALUES/ # These anchors match newlines, too
          state = :succeeded
          vals = MultiJson.load output[7..-1]
          raise "Must return an array value from iterations!" unless vals.is_a?(Array)
          raise "Must return an array of numbers from iterations!" unless vals[0].is_a?(Numeric)
          @last_run = vals
        elsif output =~ /^VALUE/ # These anchors match newlines, too
          state = :succeeded
          val = output[6..-1].to_f
          raise "Must return a number from iterations!" unless val.is_a?(Numeric)
          @last_run = [ val ]
        elsif output =~ /^OK$/   # These anchors match newlines, too
          state = :succeeded_get_time
          break
        end
        if output =~ /^NOT OK$/ # These anchors match newlines, too
          # Failed, break
          state = :explicit_not_ok
          break
        end
        if ignored_out > 10_000
          # 10k of output and no OK? Bail with failed state.
          state = :too_much_output_without_status
          break
        end
      end
      t_end = Time.now
      unless [:succeeded, :succeeded_get_time].include?(state)
        self.kill
        STDERR.puts "Killing process #{@pid} after failed iterations, error code #{state.inspect}"
      end

      @last_run = [ (t_end - t_start).to_f ] if state == :succeeded_get_time
      @last_iters = n

      @last_run
    end

  end
end
