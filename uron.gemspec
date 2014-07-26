# coding: utf-8
# -*- Ruby -*-
require File.expand_path("bin/uron")

Gem::Specification.new do |spec|
  spec.name          = "uron"
  spec.version       = Uron::VERSION
  spec.authors       = ["U.Nakamura"]
  spec.email         = ["usa@garbagecollect.jp"]
  spec.description   = %q{uron is a mail delivery agent}
  spec.summary       = %q{uron is a mail delivery agent}
  spec.homepage      = "https://github.com/unak/uron"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test-unit"
end
