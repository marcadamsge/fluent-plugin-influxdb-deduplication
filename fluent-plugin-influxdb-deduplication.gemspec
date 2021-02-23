# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name = "fluent-plugin-influxdb-deduplication"
  gem.description = "Filter plugin for deduplicating records for influxdb"
  gem.summary = gem.description
  gem.version = File.read("VERSION").strip
  gem.authors = ["Marc Adams"]
  gem.email = "marc.adams.ge@gmail.com"
  #gem.platform    = Gem::Platform::RUBY
  gem.license = 'MIT'
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", [">= 1.0", "< 2"]
  gem.add_development_dependency "rake", ">= 0.9.2"
  gem.add_development_dependency("test-unit", ["~> 3.1.4"])
end
