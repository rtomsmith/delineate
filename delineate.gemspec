# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: delineate 0.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "delineate"
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Tom Smith"]
  s.date = "2014-02-22"
  s.description = "ActiveRecord serializer DSL for mapping model attributes and associations. Similar to  ActiveModel Serializers with many enhancements including bi-directional support, i.e. deserialization."
  s.email = "tsmith@landfall.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "delineate.gemspec",
    "lib/class_inheritable_attributes.rb",
    "lib/core_extensions.rb",
    "lib/delineate.rb",
    "lib/delineate/attribute_map/attribute_map.rb",
    "lib/delineate/attribute_map/csv_serializer.rb",
    "lib/delineate/attribute_map/json_serializer.rb",
    "lib/delineate/attribute_map/map_serializer.rb",
    "lib/delineate/attribute_map/xml_serializer.rb",
    "lib/delineate/map_attributes.rb",
    "spec/database.yml",
    "spec/delineate_spec.rb",
    "spec/spec_helper.rb",
    "spec/support/models.rb",
    "spec/support/schema.rb"
  ]
  s.homepage = "http://github.com/rtomsmith/delineate"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "ActiveRecord serializer DSL for mapping model attributes and associations"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, ["~> 3.2"])
      s.add_runtime_dependency(%q<activesupport>, ["~> 3.2"])
      s.add_development_dependency(%q<rspec>, ["~> 2.14"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, ["~> 1"])
      s.add_development_dependency(%q<jeweler>, ["~> 2.0"])
      s.add_development_dependency(%q<simplecov>, ["~> 0"])
      s.add_development_dependency(%q<sqlite3>, ["~> 1"])
    else
      s.add_dependency(%q<activerecord>, ["~> 3.2"])
      s.add_dependency(%q<activesupport>, ["~> 3.2"])
      s.add_dependency(%q<rspec>, ["~> 2.14"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, ["~> 1"])
      s.add_dependency(%q<jeweler>, ["~> 2.0"])
      s.add_dependency(%q<simplecov>, ["~> 0"])
      s.add_dependency(%q<sqlite3>, ["~> 1"])
    end
  else
    s.add_dependency(%q<activerecord>, ["~> 3.2"])
    s.add_dependency(%q<activesupport>, ["~> 3.2"])
    s.add_dependency(%q<rspec>, ["~> 2.14"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, ["~> 1"])
    s.add_dependency(%q<jeweler>, ["~> 2.0"])
    s.add_dependency(%q<simplecov>, ["~> 0"])
    s.add_dependency(%q<sqlite3>, ["~> 1"])
  end
end

