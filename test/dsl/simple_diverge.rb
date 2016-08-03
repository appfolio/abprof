require "abprof/benchmark_dsl"

ABProf.compare(:print_output => false, :no_print_summary => true) do
  warmup 1
  max_trials 5
  min_trials 3
  p_value 0.001
  iters_per_trial 2
  fail_on_divergence true  # For testing, usually
  bare true

  report do
    sleep 0.1
  end

  report do
    sleep 0.1
  end

end
