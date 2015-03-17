require 'yaml'

module CouchRest
  module Changes
    module Config
      extend self

      attr_writer :app_name
      attr_accessor :connection
      attr_accessor :seq_dir
      attr_accessor :log_file
      attr_writer :log_level
      attr_accessor :logger
      attr_accessor :options
      attr_accessor :flags

      def load(base_dir, *configs)
        @base_dir = Pathname.new(base_dir)
        loaded = configs.collect do |file_path|
          file = find_file(file_path)
          load_config(file)
        end
        unless loaded.compact.any?
          raise ArgumentError.new("Could not find config file")
        end
        self.flags ||= []
        init_logger
        log_loaded_configs(loaded.compact)
        logger.info "Observing #{couch_host_without_password}"
        return self
      end

      def couch_host(options = nil)
        if options
          conf = connection.merge(options)
        else
          conf = connection
        end
        userinfo = [conf[:username], conf[:password]].compact.join(':')
        userinfo += '@' unless userinfo.empty?
        "#{conf[:protocol]}://#{userinfo}#{conf[:host]}:#{conf[:port]}"
      end

      def couch_host_no_auth
        couch_host connection.merge({:password => nil, :username => nil})
      end

      def couch_host_without_password
        couch_host connection.merge({:password => nil})
      end

      def complete_db_name(db_name)
        [connection[:prefix], db_name, connection[:suffix]].
         compact.
         reject{|part| part == ""}.
         join('_')
      end

      def app_name
        @app_name ||= Pathname.new($0).basename.to_s
      end

      private

      def init_logger
        if log_file
          require 'logger'
          @logger = Logger.new(log_file)
        else
          require 'syslog/logger'
          @logger = Syslog::Logger.new(app_name)
        end
        @logger.level = Logger.const_get(log_level.upcase)
      end

      def load_config(file_path)
        return nil unless file_path
        load_settings YAML.load(File.read(file_path)), file_path
        return file_path
      end

      def load_settings(hash, file_path)
        return unless hash
        hash.each do |key, value|
          begin
            apply_setting(key, value)
          rescue NoMethodError => exc
            # log might not have been configured yet correctly
            # so better also print this
            STDERR.puts "Error in file #{file_path}"
            STDERR.puts "'#{key}' is not a valid option"
            init_logger
            logger.warn "Error in file #{file_path}"
            logger.warn "'#{key}' is not a valid option"
            logger.debug exc
          end
        end
      end

      def apply_setting(key, value)
        if value.is_a? Hash
          value = symbolize_keys(value)
        end
        self.send("#{key}=", value)
      end

      def self.symbolize_keys(hsh)
        newhsh = {}
        hsh.keys.each do |key|
          newhsh[key.to_sym] = hsh[key]
        end
        newhsh
      end

      def find_file(file_path)
        return unless file_path
        filenames = [Pathname.new(file_path), @base_dir + file_path]
        filenames.find{|f| f.file?}
      end

      def log_loaded_configs(files)
        files.each do |file|
          logger.info "Loaded config from #{file} ."
        end
      end

      def log_level
        @log_level || 'info'
      end
    end
  end
end
