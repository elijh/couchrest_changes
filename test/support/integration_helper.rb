module CouchRest::Changes

  class TestDatabase
    def initialize(url, db_name)
      @db = CouchRest.new(url).database(db_name)
      @record = nil
    end

    def create_record(fast = false)
      result = @db.save_doc :some => :content
      raise RuntimeError.new(result.inspect) unless result['ok']
      @record = {'_id' => result["id"], '_rev' => result["rev"]}
      sleep 0.25
    end

    def delete_record(fast = false)
      return if @record.nil? or @record['_deleted']
      result = @db.delete_doc @record
      raise RuntimeError.new(result.inspect) unless result['ok']
      @record['_deleted'] = true
    end
  end

  class IntegrationTest < MiniTest::Test
    def db_connect(db_name, config)
      yield TestDatabase.new(config.couch_host, config.complete_db_name(db_name))
    end
  end

end
