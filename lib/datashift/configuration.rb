# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Feb 2015
# License::   MIT
#
# Details::   Read mappings and provide cache type services for source=>destination mappings
#
require 'erubis'

module DataShift

  class Configuration
    # When performing import, default is to ignore any columns that cannot be mapped  (via headers)
    # To raise an error set strict => true
    # Defaults to `false`. Set to `true` to cause exceptions to be thrown
    # The setting is ignored if routes are disabled.
    # @param [Boolean] value
    # @return [Boolean]
    attr_accessor :strict

    # Controls the amount of information written to the log
    # Defaults to `false`. Set to `true` to cause extensive progress messages to be logged
    # @param [Boolean] value
    # @return [Boolean]
    attr_accessor :verbose

    def self.rails_columns
      @rails_standard_columns ||= [:id, :created_at, :created_on, :updated_at, :updated_on]
    end

    def initialize
      @strict = false
      @verbose = false
    end

    # @return [DataShift::Configuration] DataShift's current configuration
    def self.configuration
      @configuration ||= Configuration.new
    end

    # Set DataShift's configuration
    # @param config [DataShift::Configuration]
    class << self
      attr_writer :configuration
    end

    # Modify DataShift's current configuration
    # @yieldparam [DataShift::Configuration] config current DataShift config
    # ```
    # DataShift::Configuration.configure do |config|
    #   config.verbose = false
    # end
    # ```
    def self.configure
      yield configuration
    end
  end

  class YamlConfiguration

    attr_accessor :datashift_defaults, :datashift_populators

    include DataShift::Logging

    # N.B @mappings is an OpenStruct data structure
    #
    attr_reader :key
    attr_accessor :yaml_data, :key_config

    def initialize( key = nil)
      @key = key

      @config = OpenStruct.new
    end

    def read( file, key = nil )

      unless File.exist?(file)
        logger.error "Cannot open configuration file - #{file} - file does not exist."
        raise FileNotFound.new("Cannot open mapping file - #{file}")
      end

      begin
        # Load application configuration
        set_mapping( file )

        set_key_config!( key ) if key
      rescue => e
        logger.error e.inspect
        logger.error "Failed to parse config file #{map_file_name} - bad YAML ?"
        raise e
      end
    end

    # OpenStruct not a hash .. supports form ... config.path, config.full_name etc
    def method_missing(method, *_args, &_block)
      @config.send(method)
    end

    # Config file can contain sets of entries, identified with a key.
    # e.g
    #     A:
    #       log_level: 1
    #     B:
    #       log_level: 2
    #
    # Restrict searches/config entries to single set via key e.g 'A'
    #
    def set_key_config!( key )
      raise MissingConfigOptionError.new("No config entry found for key [#{key}]") unless yaml_data && yaml_data[key].is_a?(Hash)
      @key_config = OpenStruct.new( yaml_config[key] ) # Argument HAS to be a hash
    end

    # Merge another YAML section (identified by key) into @key_config
    def merge_key_config!( key )
      raise Beeline::MissingConfigOptionError.new("No config entry found for key [#{key}]") unless yaml_data && yaml_data[key].is_a?(Hash)

      temp = yaml_data[key].merge(@key_config.instance_variable_get('@table') || {})

      key_config = OpenStruct.new(temp)
    end

    def set( key, value)
      key_config.instance_variable_get('@table')[key] = value
    end

    private

    def set_mapping( file )

      erb = begin
        Erubis::Eruby.new( File.read(file )).result
      rescue => e
        logger.error "Failed to parse erb template #{file} error: #{e.inspect}"
        raise e
      end

      begin
        yaml_data = YAML.load(erb)

        logger.info "Loaded YAML config from [#{file}]"

      rescue => e
        logger.error "YAML parse error: #{e.inspect}"
        raise e
      end

      @config = OpenStruct.new(yaml_data)
    end

  end

end
