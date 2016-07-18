#!/usr/bin/env ruby

require "abprof"

STDERR.puts "ABProf example: optcarrot with with-inlined-funcs Ruby dir"

ABProf::ABWorker.iteration do
  `cd ../inline_func_ruby && ./tool/runruby.rb ../optcarrot/bin/optcarrot --benchmark ../optcarrot/examples/Lan_Master.nes`
end

ABProf::ABWorker.start
