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
        Config.logger.error { "Database #{db_name} not found!" }
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

end