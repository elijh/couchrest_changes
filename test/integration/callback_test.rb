require_relative '../test_helper'

class CallbackTest < CouchRest::Changes::IntegrationTest

  def setup
    super
    @config = CouchRest::Changes::Config
    @config.load BASE_DIR, 'test/config.yaml'
    @config.flags = ['--run-once']
  end

  def teardown
  end

  def test_triggers_created
    handler = mock 'handler'
    handler.expects(:callback).once

    changes = CouchRest::Changes.new 'records'
    changes.created { handler.callback }
    File.write @config.seq_file, changes.last_sequence

    db_connect('records', @config) do |db|
      db.create_record
      changes.listen
      db.delete_record
    end
  end

  #
  # CouchRest::Changes.new will apply whatever values are in
  # the current Config.
  #
  def test_netrc
    db_connect('records', @config) do |db|
      #
      # test with a bad netrc.
      #
      # I wish we could test for RestClient::Unauthorized
      # but CouchRest just silently eats Couch's
      # {"error"=>"unauthorized"} response and returns as
      # if there was no problem. Grrr.
      #
      handler = mock 'handler'
      handler.expects(:callback).never
      @config.connection[:netrc] = "error"
      changes = CouchRest::Changes.new 'records'
      changes.created {handler.callback}
      db.create_record
      changes.listen
      db.delete_record

      #
      # now test with a good netrc.
      #
      handler = mock 'handler'
      handler.expects(:callback).once
      @config.connection[:netrc] = File.expand_path("../../test.netrc", __FILE__)
      changes = CouchRest::Changes.new 'records'
      changes.created { handler.callback}
      File.write @config.seq_file, changes.last_sequence
      db.create_record
      changes.listen
      db.delete_record
    end
  end

  def test_starts_from_scratch_on_invalid_sequence
    handler = mock 'handler'
    handler.expects(:callback).at_least_once

    File.write @config.seq_file, "invalid string"
    changes = CouchRest::Changes.new 'records'
    changes.created { |hash| handler.callback(hash) }

    db_connect('records', @config) do |db|
      db.create_record
      changes.listen
      db.delete_record
    end
  end

end
