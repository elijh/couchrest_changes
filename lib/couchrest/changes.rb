require 'couchrest'
require 'fileutils'
require 'pathname'

require 'couchrest/changes/config'

module CouchRest
  class Changes

    attr_writer :logger

    def initialize(db_name)
      db_name = Config.complete_db_name(db_name)
      logger.info "Tracking #{db_name}"
      @db = CouchRest.new(Config.couch_host).database(db_name)
      read_seq(Config.seq_file) unless Config.flags.include?('--rerun')
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
      logger.info "listening..."
      logger.debug "Starting at sequence #{since}"
      result = db.changes :feed => :continuous, :since => since, :heartbeat => 1000 do |hash|
        callbacks(hash)
        store_seq(hash["seq"])
      end
      logger.info "couch stream ended unexpectedly."
      logger.debug result.inspect
    end

    protected

    def logger
      logger ||= Config.logger
    end

    def db
      @db
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
      logger.debug "Looking up sequence here: #{filename}"
      FileUtils.touch(filename)
      unless File.writable?(filename)
        raise StandardError.new("Can't write to sequence file #{filename}")
      end
      @since = File.read(filename)
    rescue Errno::ENOENT => e
      logger.warn "No sequence file found. Starting from scratch"
    end

    def check_seq
      if @since == ''
        @since = nil
        logger.debug "Found no sequence in the file."
      elsif @since
        logger.debug "Found sequence: #{@since}"
      end
    end

    def store_seq(seq)
      File.write Config.seq_file, MultiJson.dump(seq)
    end

    #
    # UNUSED: this is useful for only following new sequences.
    # might also require .to_json to work on bigcouch.
    #
    def fetch_last_seq
      hash = db.changes :limit => 1, :descending => true
      logger.info "starting at seq: " + hash["last_seq"]
      return hash["last_seq"]
    end

  end
end
