module CouchRest::Changes
  class Observer

    attr_writer :logger

    def initialize(db_name, options = {})
      db_name = Config.complete_db_name(db_name)
      info "Tracking #{db_name}"
      debug "Options: #{options.inspect}" if options.keys.any?
      @options = options
      unless @db = CouchRest.new(Config.couch_host).database(db_name)
        logger.error "Database #{db_name} not found!"
        raise RuntimeError "Database #{db_name} not found!"
      end
      read_seq(Config.seq_file) unless rerun?
      check_seq
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
      result = db.changes feed_options do |hash|
        @retry_count = 0
        callbacks(hash)
        store_seq(hash["seq"])
      end
      raise EOFError
    # appearently MultiJson has issues with the end of the couch stream.
    # So sometimes we get a MultiJson::LoadError instead...
    rescue MultiJson::LoadError, EOFError, RestClient::ServerBrokeConnection
      return if run_once?
      log_and_recover(result)
      retry
    end

    protected

    def feed_options
      if run_once?
        { :since => since }
      else
        { :feed => :continuous, :since => since, :heartbeat => 1000 }
      end.merge @options
    end

    def since
      @since ||= 0  # fetch_last_seq
    end

    def callbacks(hash)
      # let's not track design document changes
      return if hash['id'].start_with? '_design/'
      return unless changes = hash["changes"]
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

    def read_seq(filename)
      debug "Looking up sequence here: #{filename}"
      FileUtils.touch(filename)
      unless File.writable?(filename)
        raise StandardError.new("Can't write to sequence file #{filename}")
      end
      @since = File.read(filename)
    rescue Errno::ENOENT => e
      warn "No sequence file found. Starting from scratch"
    end

    def check_seq
      if @since == ''
        @since = nil
        debug "Found no sequence in the file."
      elsif @since
        debug "Found sequence: #{@since}"
      end
    end

    def store_seq(seq)
      File.write Config.seq_file, MultiJson.dump(seq)
    end

    def log_and_recover(result)
      info "Couch stream ended unexpectedly."
      recover_from(result) if result
      info "Will retry in 15 seconds."
      info "Retried #{retry_count} times so far."
      sleep 15
      @retry_count += 1
    end

    def recover_from(result)
      debug result.inspect
      return unless result.respond_to?(:keys) && reason = result["reason"]
      info reason
      if reason.include?('since')
        @since = nil
        info "Trying to start from scratch."
      end
    end

    #
    # UNUSED: this is useful for only following new sequences.
    # might also require .to_json to work on bigcouch.
    #
    def fetch_last_seq
      hash = db.changes :limit => 1, :descending => true
      return hash["last_seq"]
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

    def db
      @db
    end

  end
end
