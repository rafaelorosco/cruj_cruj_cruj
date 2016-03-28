$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cruj_cruj_cruj/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cruj_cruj_cruj"
  s.version     = CrujCrujCruj::VERSION
  s.authors     = ["Victor Campos"]
  s.email       = ["victor.campos@visagio.com"]
  s.homepage    = "https://github.com/victorlcampos/cruj_cruj_cruj"
  s.summary     = "Crud Generator for Redmine"
  s.description = "Crud Generator for Redmine"
  s.license     = "MIT"

  s.files      = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "> 4.2"

  s.add_dependency "ransack"
  s.add_dependency "kaminari"

  s.add_dependency "roo"
  s.add_dependency "axlsx", '~> 2.0'

  s.add_development_dependency "sqlite3"
end
