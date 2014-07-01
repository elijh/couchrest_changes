module CouchRest::Changes
  class IntegrationTest < MiniTest::Unit::TestCase

    attr_reader :config

    def setup
      @config ||= CouchRest::Changes::Config.load BASE_DIR,
        'test/config.yaml'
    end

    def create(fast = false)
      result = database.save_doc :some => :content
      raise RuntimeError.new(result.inspect) unless result['ok']
      @record = {'_id' => result["id"], '_rev' => result["rev"]}
      sleep 1
    end

    def delete(fast = false)
      return if @record.nil? or @record['_deleted']
      result = database.delete_doc @record
      raise RuntimeError.new(result.inspect) unless result['ok']
      @record['_deleted'] = true
      sleep 1
    end

    def database
      @database ||= host.database(database_name)
    end

    def database_name
      config.complete_db_name('records')
    end

    def host
      @host ||= CouchRest.new(config.couch_host)
    end

  end
end
