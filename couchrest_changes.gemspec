$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "couchrest/changes/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "couchrest_changes"
  s.version     = CouchRest::Changes::VERSION
  s.authors     = ["Azul"]
  s.email       = ["azul@leap.se"]
  s.homepage    = "https://leap.se"
  s.summary     = "CouchRest::Changes - Observe a couch database for changes and react upon them"
  s.description = "Watches the couch database for changes and triggers callbacks defined for creation, deletes and updates."

  s.files = Dir["{lib}/**/*"] + ["Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "couchrest", "~> 1.1.3"
  s.add_dependency "yajl-ruby"
  s.add_dependency "syslog_logger", "~> 2.0.0"
  s.add_development_dependency "minitest", "~> 3.2.0"
  s.add_development_dependency "mocha"
  s.add_development_dependency "rake"
  s.add_development_dependency "highline"
end
