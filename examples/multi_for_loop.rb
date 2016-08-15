#!/usr/bin/env ruby

require "abprof"

puts "ABProf example: sleep 0.1 seconds (multiple measurements per trial)"

ABProf::ABWorker.n_iterations_with_return_value do |n|
  (1..n).map do
    t1 = Time.now
    100_000.times {}
    (Time.now - t1)  # Return array of measurements
  end
end

ABProf::ABWorker.start
