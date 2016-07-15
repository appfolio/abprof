#!/usr/bin/env ruby

require "abprof"

STDERR.puts "ABProf example: optcarrot with vanilla Ruby dir"

ABProf::ABWorker.iteration do
  `cd ../vanilla_build && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes`
end

ABProf::ABWorker.start
