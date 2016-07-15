#!/usr/bin/env ruby

require "abprof"

STDERR.puts "ABProf example: optcarrot with alt Ruby dir"

ABProf::ABWorker.iteration do
  `cd ../alt_build && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes`
end

ABProf::ABWorker.start
