# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_replicas/version'

Gem::Specification.new do |spec|
  spec.name    = "active_replicas"
  spec.version = ActiveReplicas::VERSION
  spec.authors = [ 'Dirk Gadsden' ]
  spec.email   = [ 'dirk@esherido.com' ]

  spec.summary     = %q{TODO: Write a short summary, because Rubygems requires one.}
  spec.description = %q{TODO: Write a longer description or delete this line.}
  spec.homepage    = "TODO: Put your gem's website or public repo URL here."

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.require_paths = [ 'lib' ]

  spec.add_dependency 'concurrent-ruby', '~> 1.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
