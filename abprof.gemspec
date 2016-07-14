# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'abprof/version'

Gem::Specification.new do |spec|
  spec.name          = "abprof"
  spec.version       = Abprof::VERSION
  spec.authors       = ["Noah Gibbs"]
  spec.email         = ["noah.gibbs@appfolio.com"]

  spec.summary       = %q{Determine which of two programs is faster, statistically.}
  spec.description   = %q{Determine which of two program variants is faster, using A/B-Testing-style statistical techniques.}
  spec.homepage      = "https://github.com/appfolio/abprof"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_runtime_dependency "trollop"
end
