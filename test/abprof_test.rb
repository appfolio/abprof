require 'test_helper'

THIS_DIR = __dir__
ROOT_DIR = File.expand_path File.join(THIS_DIR, "..")

class AbprofTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Abprof::VERSION
  end

  # Test basic invocation of abprof on divergence
  def test_likely_divergence
    system "cd #{ROOT_DIR} && RUBYLIB=lib ./exe/abprof --fail-on-divergence --pvalue=0.0001 --min-trials=5 --max-trials=5 --iters-per-trial=1 examples/sleep.rb examples/sleep.rb 2>&1 >> /dev/null"
    assert_equal 2, $?.exitstatus
  end

  # Test basic invocation of abprof on convergence
  def test_likely_convergence
    system "cd #{ROOT_DIR} && RUBYLIB=lib ./exe/abprof --fail-on-divergence --pvalue=0.05 --min-trials=2 --max-trials=10 examples/for_loop_10k.rb examples/sleep.rb 2>&1 >> /dev/null"
    assert $?.success?
  end

  # Test basic invocation of abcompare on divergence
  def test_abcompare_divergence
    system "cd #{ROOT_DIR} && RUBYLIB=lib ./exe/abcompare --fail-on-divergence --pvalue=0.0001 --min-trials=20 --max-trials=20 --iters-per-trial=10 'echo bob' 'echo bob' 2>&1 >> /dev/null"
    assert_equal 2, $?.exitstatus
  end

  # Test basic invocation of abcompare on convergence
  def test_abcompare_convergence
    system "cd #{ROOT_DIR} && RUBYLIB=lib ./exe/abcompare --fail-on-divergence --pvalue=0.05 --min-trials=20 --max-trials=20 --iters-per-trial=1 'echo bob' 'sleep 0.1' 2>&1 >> /dev/null"
    assert $?.success?
  end

  def test_dsl_with_blocks
    system "cd #{ROOT_DIR} && RUBYLIB=lib ruby test/dsl/simple_diverge.rb"
    assert_equal 2, $?.exitstatus
  end

  def test_dsl_with_commands
    system "cd #{ROOT_DIR} && RUBYLIB=lib ruby test/dsl/simple_converge.rb"
    assert $?.success?
  end
end
