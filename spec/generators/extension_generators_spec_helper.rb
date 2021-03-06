ENV["RAILS_ENV"] = 'test'
RAILS_ENV = 'test'
BASE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '../../'))
require 'fileutils'
require 'tempfile'
require 'rspec'
require File.join(BASE_ROOT, 'spec/matchers/generator_matchers')
require File.join(BASE_ROOT, 'lib/string_extensions')

unless defined?(::GENERATOR_SUPPORT_LOADED) && ::GENERATOR_SUPPORT_LOADED
  # this is so we can require ActiveSupport
  $:.unshift File.join(BASE_ROOT, 'vendor/rails/activesupport/lib')
  # This is so the initializer and Rails::Generators is properly found
  $:.unshift File.join(BASE_ROOT, 'vendor/rails/railties/lib')
  require 'active_support'

  # Mock out what we need from AR::Base
  module ActiveRecord
    class Base
      class << self
        attr_accessor :pluralize_table_names, :timestamped_migrations
      end
      self.pluralize_table_names = true
      self.timestamped_migrations = true
    end

    module ConnectionAdapters
      class Column
        attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale

        def initialize(name, default, sql_type = nil)
          @name = name
          @default = default
          @type = @sql_type = sql_type
        end

        def human_name
          @name.humanize
        end
      end
    end
  end

  # Mock up necessities from ActionView
  module ActionView
    module Helpers
      module ActionRecordHelper; end
      class InstanceTag; end
    end
  end

  # Set RAILS_ROOT appropriately fixture generation
  tmp_dir = File.expand_path(File.join(Dir.tmpdir, 'radiant'))
  $stdout << "#{tmp_dir}\n\n"
  FileUtils.mkdir_p tmp_dir

  if defined? RADIANT_ROOT
    RADIANT_ROOT.replace tmp_dir.dup
  else
    RADIANT_ROOT = tmp_dir.dup
  end

  if defined? RAILS_ROOT
    RAILS_ROOT.replace tmp_dir.dup
  else
    RAILS_ROOT = tmp_dir.dup
  end

  # require 'initializer'

  # Mocks out the configuration
  module Rails
    def self.configuration
      Rails::Configuration.new
    end
  end

  # require 'rails_generator'

  module GeneratorSpecHelperMethods
    # Instantiates the Generator.
    def build_generator(name, params)
      Rails::Generators::Base.new(name, params)
    end

    # Runs the +create+ command (like the command line does).
    def run_generator(name, params)
      silence_generator do
        build_generator(name, params).command(:create).invoke!
      end
    end

    # Silences the logger temporarily and returns the output as a String.
    def silence_generator
      # logger_original = Rails::Generators::Base.logger
      # myout = StringIO.new
      # Rails::Generators::Base.logger = Rails::Generators::SimpleLogger.new(myout)
      yield if block_given?
      # Rails::Generators::Base.logger = logger_original
      # myout.string
    end

    # Run the block with RADIANT_ROOT replaced with BASE_ROOT
    def with_radiant_root_as_base_root
      prev_radiant_root = RADIANT_ROOT.dup
      RADIANT_ROOT.replace BASE_ROOT.dup
      begin
        yield
      ensure
        RADIANT_ROOT.replace prev_radiant_root
      end
    end

    # Run the block with $stdout suppressed
    def suppress_stdout
      original_stdout = $stdout
      $stdout = fake = StringIO.new
      begin
        yield
      ensure
        $stdout = original_stdout
      end
      fake.string
    end
  end

  shared_examples_for "all generators" do
    before(:all) do
      ActiveRecord::Base.pluralize_table_names = true

      FileUtils.mkdir_p "#{RADIANT_ROOT}/app"
      FileUtils.mkdir_p "#{RADIANT_ROOT}/config"
      FileUtils.mkdir_p "#{RADIANT_ROOT}/db"
      FileUtils.mkdir_p "#{RADIANT_ROOT}/vendor/generators"
      FileUtils.mkdir_p "#{RADIANT_ROOT}/vendor/extensions"

      File.open("#{RADIANT_ROOT}/config/routes.rb", 'w') do |f|
        f << "ActionController::Routing::Routes.draw do |map|\n\nend"
      end
    end

    after(:all) do
      %w(app db config vendor).each do |dir|
        FileUtils.rm_rf File.join(RADIANT_ROOT, dir)
      end
    end
  end

  shared_examples_for "all extension generators" do
    before(:all) do
      FileUtils.mkdir_p "#{RADIANT_ROOT}/vendor/extensions"
      FileUtils.cp_r File.join(BASE_ROOT, 'spec/fixtures/example_extension'), File.join(RADIANT_ROOT, 'vendor/extensions/example')
    end
  end

  GENERATOR_SUPPORT_LOADED = true
end

Git = Module.new unless defined?(::Git)

RSpec.configure do |config|
  config.include(Spec::Matchers::GeneratorMatchers)
end

