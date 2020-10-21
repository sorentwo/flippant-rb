lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "flippant/version"

Gem::Specification.new do |spec|
  spec.name = "flippant"
  spec.version = Flippant::VERSION
  spec.authors = ["Parker Selbert"]
  spec.email = ["parker@sorentwo.com"]

  spec.summary = "Fast feature toggling for applications"
  spec.description = "Fast feature toggling for applications"
  spec.homepage = "https://github.com/sorentwo/flippant-rb"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^spec/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "activerecord", "~> 6.0"
  spec.add_development_dependency "benchmark-ips"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "pg", "~> 1.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "redis", "~> 4.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
