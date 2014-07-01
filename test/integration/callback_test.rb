require 'test_helper'

class CallbackTest < CouchRest::Changes::IntegrationTest

  def setup
    super
    @config.flags = ['--run-once']
    @changes = CouchRest::Changes.new 'records'
    File.write config.seq_file, @changes.last_sequence
  end

  def teardown
    delete
  end

  def test_triggers_created
    handler = mock 'handler'
    handler.expects(:callback).once
    @changes.created { |hash| handler.callback(hash) }
    create
    @changes.listen
  end

  def test_starts_from_scratch_on_invalid_sequence
    File.write config.seq_file, "invalid string"
    @changes = CouchRest::Changes.new 'records'
    handler = mock 'handler'
    handler.expects(:callback).at_least_once
    @changes.created { |hash| handler.callback(hash) }
    create
    @changes.listen
  end

end
