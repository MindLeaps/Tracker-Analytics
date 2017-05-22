$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mindleaps_analytics/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mindleaps_analytics"
  s.version     = MindleapsAnalytics::VERSION
  s.authors     = ["MindLeaps"]
  s.email       = ["it@mindleaps.org"]
  s.homepage    = "https://mindleaps.org"
  s.summary     = "Summary summary"
  s.description = "Description  Here"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.1.1"
end
