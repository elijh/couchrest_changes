module CouchRest::Changes

  #
  # CouchRest uses curl for 'streaming' requests
  # (requests with a block passed to the db).
  #
  # Unfortunately, this leaks the username and password in the process list.
  # We don't want to do this. So, we create two separate CouchRest::Database
  # instances: one that is for normal requests and one that is used for
  # streaming requests. The streaming one we hack to use netrc file in order
  # to keep authentication info out of the process list.
  #
  # If no netrc file is configure, then this DatabaseProxy just uses the
  # regular db.
  #
  class DatabaseProxy
    def initialize(db_name)
      @db = CouchRest.new(Config.couch_host).database(db_name)
      unless @db
        Config.logger.error "Database #{db_name} not found!"
        raise RuntimeError "Database #{db_name} not found!"
      end
      if Config.connection[:netrc] && !Config.connection[:netrc].empty?
        @db_stream = CouchRest.new(Config.couch_host_no_auth).database(db_name)
        streamer = @db_stream.instance_variable_get('@streamer') # cheating, not exposed.
        streamer.default_curl_opts += " --netrc-file \"#{Config.connection[:netrc]}\""
      else
        @db_stream = @db
      end
    end

    def changes(*args, &block)
      if block
        @db_stream.changes(*args, &block)
      else
        @db.changes(*args)
      end
    end
  end

  class Observer

    attr_writer :logger
    attr_reader :since

    def initialize(db_name, options = {})
      @db_name = Config.complete_db_name(db_name)
      info "Tracking #{db_name}"
      debug "Options: #{options.inspect}" if options.keys.any?
      @options = options
      @db = DatabaseProxy.new(@db_name)
      setup_sequence_file(@db_name)
      unless rerun?
        @since = read_seq(@db_name)
      else
        @since = 0
      end
    end

    # triggered when a document was newly created
    def created(hash = {}, &block)
      run_or_define_hook :created, hash, &block
    end

    # triggered when a document was deleted
    def deleted(hash = {}, &block)
      run_or_define_hook :deleted, hash, &block
    end

    # triggered when an existing document was updated
    def updated(hash = {}, &block)
      run_or_define_hook :updated, hash, &block
    end

    # triggered whenever a document was changed
    def changed(hash = {}, &block)
      run_or_define_hook :changed, hash, &block
    end

    def listen
      info "listening..."
      debug "Starting at sequence #{since}"
      last = nil
      result = @db.changes(feed_options) do |hash|
        last = hash
        @retry_count = 0
        callbacks(hash) if hash_for_change?(hash)
        store_seq(@db_name, hash["seq"])
      end
      raise EOFError
    # appearently MultiJson has issues with the end of the couch stream.
    # So sometimes we get a MultiJson::LoadError instead...
    rescue MultiJson::LoadError, EOFError, RestClient::ServerBrokeConnection => exc
      error "Couch stream ended - #{exc.class}"
      debug result.inspect if result
      debug last.inspect if last
      retry if retry_without_sequence?(result, last) || retry_later?
    end

    def last_sequence
      hash = @db.changes :limit => 1, :descending => true
      return hash["last_seq"]
    end

    protected

    def feed_options
      if run_once?
        { :since => since }
      else
        { :feed => :continuous, :since => since, :heartbeat => 1000 }
      end.merge @options
    end

    def callbacks(hash)
      # let's not track design document changes
      return if hash['id'].start_with? '_design/'
      changes = hash["changes"]
      changed(hash)
      return deleted(hash) if hash["deleted"]
      return created(hash) if changes[0]["rev"].start_with?('1-')
      updated(hash)
    end

    def run_or_define_hook(event, hash = {}, &block)
      @callbacks ||= {}
      if block_given?
        @callbacks[event] = block
      else
        @callbacks[event] && @callbacks[event].call(hash)
      end
    end

    #
    # ensure the sequence file exists
    #
    def setup_sequence_file(db_name)
      filename = sequence_file_name(db_name)
      unless Dir.exists?(Config.seq_dir)
        FileUtils.mkdir_p(Config.seq_dir)
        unless Dir.exists?(Config.seq_dir)
          raise StandardError.new("Can't create sequence directory #{Config.seq_dir}")
        end
      end
      unless File.exists?(filename)
        FileUtils.touch(filename)
        unless File.writable?(filename)
          raise StandardError.new("Can't write to sequence file #{filename}")
        end
      end
    end

    #
    # reads the sequence file, e.g. (/var/run/tapicero/users.seq), returning
    # the sequence number or zero if the sequence number could not be
    # determined.
    #
    def read_seq(db_name)
      filename = sequence_file_name(db_name)
      debug "Looking up sequence here: #{filename}"
      result = File.read(filename)
      if result.empty?
        debug "Found no sequence in the file."
        return 0
      else
        debug "Found sequence: #{result}"
        return result.to_i
      end
    rescue Errno::ENOENT => e
      warn "No sequence file found. Starting from scratch"
      return 0
    end

    def store_seq(db_name, seq)
      File.write sequence_file_name(db_name), seq.to_i
    end

    def sequence_file_name(db_name)
      File.join(Config.seq_dir, db_name + '.seq')
    end

    def retry_without_sequence?(result, last_hash)
      if malformated_sequence?(result) || malformated_sequence?(last_hash)
        @since = 0
        info "Trying to start from scratch."
      end
    end

    def malformated_sequence?(result)
      reason = result && result.respond_to?(:keys) && result["reason"]
      reason && ( reason.include?('since') || reason == 'badarg' )
    end

    def hash_for_change?(hash)
      hash["id"] && hash["changes"]
    end

    def retry_later?
      return unless rerun?
      info "Will retry in 15 seconds."
      info "Retried #{retry_count} times so far."
      sleep 15
      @retry_count += 1
    end

    def rerun?
      Config.flags.include?('--rerun')
    end

    def run_once?
      Config.flags.include?('--run-once')
    end

    def info(message)
      return unless log_attempt?
      logger.info message
    end

    def debug(message)
      return unless log_attempt?
      logger.debug message
    end

    def warn(message)
      return unless log_attempt?
      logger.warn message
    end

    def error(message)
      return unless log_attempt?
      logger.error message
    end

    # let's not clutter the logs if couch is down for a longer time.
    def log_attempt?
      [0, 1, 2, 4, 8, 20, 40, 120].include?(retry_count) ||
        retry_count % 240 == 0
    end

    def retry_count
      @retry_count ||= 0
    end

    def logger
      logger ||= Config.logger
    end

  end
end
