require "abprof/benchmark_dsl"

ABProf.compare do
  warmup 10
  max_trials 5
  min_trials 3
  p_value 0.01
  iters_per_trial 2

  report_command "ruby examples/for_loop_10k.rb"
  report_command "ruby examples/sleep.rb"

end
