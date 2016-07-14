require "abprof/version"

# Protocol:
#   Controller sends "ITERS [integer]\n"
#   Controller sends "QUIT\n" when done
#   Test process responds "OK\n" or "NOT OK\n" or crashes; QUIT requires no response.

module ABProf
  # This class is used by programs that are *being* profiled.
  # It's necessarily a singleton since it needs to control STDIN.
  class ABWorker
    def self.iteration(&block)
      @iter_block = block
    end

    def self.run_n(n)
      STDERR.puts "WORKER #{Process.pid}: running #{n} times"
      n.times do
        @iter_block.call
      end
    end

    def self.read_loop
      STDERR.puts "WORKER #{Process.pid}: read loop"
      @input ||= ""
      @input += STDIN.gets
      STDERR.puts "WORKER #{Process.pid}: Input #{@input.inspect}"
      if @input["\n"]
        command, @input = @input.split("\n", 2)
        STDERR.puts "WORKER #{Process.pid}: command: #{command.inspect}"
        if command == "QUIT"
          exit 0
        elsif command["ITERS"]
          iters = command[5..-1].to_i
          run_n iters
          STDOUT.write "OK\n"
        else
          STDERR.puts "Unrecognized ABProf command: #{command.inspect}!"
          exit -1
        end
      end
    end

    def self.start
      read_loop
    end
  end

  class ABProcess
    attr_reader :last_run
    attr_reader :last_iters

    def initialize command_line, opts = {}
      STDERR.puts "Controller of nobody yet: SPAWN"
      @in_reader, @in_writer = IO.pipe
      @out_reader, @out_writer = IO.pipe
      @in_writer.sync = true
      @out_writer.sync = true

      @pid = fork do
        STDOUT.reopen(@out_writer)
        STDIN.reopen(@in_reader)
        @out_reader.close
        @in_writer.close
        exec command_line
      end
      @out_writer.close
      @out_writer = nil
      @in_reader.close
      @in_reader = nil

      @debug = opts[:debug]
      STDERR.puts "Controller spawned #{@pid} (debug: #{@debug.inspect})"
      # Sleep briefly to allow process startup. How does this usually get fixed?
      sleep 0.5
    end

    def quit
      STDERR.puts "Controller of #{@pid}: QUIT"
      @in_writer.write "QUIT\n"
    end

    def kill
      STDERR.puts "Controller of #{@pid}: DIE"
      ::Process.detach @pid
      ::Process.kill @pid
    end

    def run_iters(n)
      t_start = Time.now
      STDERR.puts "Controller of #{@pid}: #{n} ITERS"
      @in_writer.write "ITERS #{n.to_i}\n"

      ignored_out = 0
      state = :failed
      loop do
        # Read and block
        output = @out_reader.gets
        ignored_out += output.length
        puts "Process #{@pid} out: #{output.inspect}" if @debug
        if output =~ /^OK$/   # These anchors match newlines, too
          state = :succeeded
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
      if state != :succeeded
        self.kill
        STDERR.puts "Killing process #{@pid} after failed iterations, error code #{state.inspect}"
      end
      t_end = Time.now
      @last_run = (t_end - t_start).to_f
      @last_iters = n

      @last_run
    end

  end
end
