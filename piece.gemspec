# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'piece/version'

Gem::Specification.new do |spec|
  spec.name          = "piece"
  spec.version       = Piece::VERSION
  spec.authors       = ["Xiao Li"]
  spec.email         = ["swing1979@gmail.com"]

  spec.summary       = %q{User privileges and feature toggle}
  spec.description   = %q{It's time to make user privileges and feature toggle simpler}
  spec.homepage      = "https://github.com/ThoughtWorksStudios/piece"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "racc", "~> 1.4"
end
