# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stash/client/version'

Gem::Specification.new do |spec|
  spec.name          = "stash-client"
  spec.version       = Stash::Client::VERSION
  spec.authors       = ["Jari Bakken", "Josh Westmoreland"]
  spec.email         = ["jari.bakken@gmail.com", "joshua.westmoreland@theice.com"]
  spec.description   = %q{Stash Client Gem}
  spec.summary       = %q{Atlassian Stash Client for Ruby}
  spec.homepage      = "https://stash.intcx.net/projects/CM/repos/stash-client/browse"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.4", ">= 10.4.2"
  spec.add_development_dependency "rspec", "~> 3.2", ">= 3.2.0"
  spec.add_development_dependency "webmock", "~> 1.21", ">= 1.21.0"

  spec.add_dependency "faraday", "~> 0.9", ">= 0.9.1"
  spec.add_dependency "addressable", "~> 2.3", ">= 2.3.8"
end
