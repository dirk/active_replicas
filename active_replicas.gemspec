# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_replicas/version'

Gem::Specification.new do |spec|
  spec.name    = 'active_replicas'
  spec.version = ActiveReplicas::VERSION
  spec.authors = [ 'Dirk Gadsden' ]
  spec.email   = [ 'dirk@esherido.com' ]

  spec.summary     = 'Smart read replicas in ActiveRecord.'
  spec.description = 'Hooks into ActiveRecord to automatically sends reads to read replicas and writes to primary database.'
  spec.homepage    = 'https://github.com/dirk/active_replicas'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

  spec.require_paths = [ 'lib' ]

  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'rails', '~> 4.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
