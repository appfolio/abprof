#!/usr/bin/env ruby

require "abprof"

puts "ABProf example: sleep 0.1 seconds"

ABProf::ABWorker.iteration do
  sleep 0.001
end

ABProf::ABWorker.start
