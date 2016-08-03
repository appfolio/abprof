require "abprof/benchmark_dsl"

ABProf.compare do
  warmup 10
  max_trials 5
  min_trials 3
  p_value 0.01
  iters_per_trial 2
  bare true

  report do
    10_000.times {}
  end

  report do
    sleep 0.1
  end

end
