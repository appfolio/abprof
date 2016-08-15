#!/usr/bin/env ruby

require "abprof"

puts "ABProf example: sleep 0.1 seconds, manual return value"

ABProf::ABWorker.iteration_with_return_value do
  t1 = Time.now
  sleep 0.01
  (Time.now - t1)
end

ABProf::ABWorker.start
