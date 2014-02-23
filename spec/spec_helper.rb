$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'

require 'simplecov'
SimpleCov.start

ENV['RAILS_ENV'] = 'test'

require 'active_support'
require 'active_support/core_ext/logger'
require 'active_record'

require 'rspec'

require 'delineate'


# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
#Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
end

# a little sugar for checking results of a section of code
alias :running :lambda


# Set the DB var if testing with other than sqlite
ENV['DB'] ||= 'sqlite3'

database_yml = File.expand_path('../database.yml', __FILE__)
if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)[ENV['DB']]

  ActiveRecord::Base.establish_connection(active_record_configuration)
  ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "test.log"))
  #ActiveRecord::Base.logger = Logger.new(STDOUT)

  ActiveRecord::Base.silence do
    ActiveRecord::Migration.verbose = false

    load(File.dirname(__FILE__) + '/support/schema.rb')
    create_schema!

    load(File.dirname(__FILE__) + '/support/models.rb')
    clean_database!
  end
else
  raise "Create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
end
