#!/usr/bin/env ruby

require "abprof"

STDERR.puts "ABProf example: optcarrot with profiling Ruby dir"

ABProf::ABWorker.iteration do
  `cd ../inline_ruby_1800 && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes`
end

ABProf::ABWorker.start
