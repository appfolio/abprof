#!/usr/bin/env ruby

require "abprof"

STDERR.puts "ABProf example: 10,000 empty iterations"

ABProf::ABWorker.iteration do
  10_000.times {}
end

ABProf::ABWorker.start
