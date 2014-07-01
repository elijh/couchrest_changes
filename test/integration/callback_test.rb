require 'test_helper'

class CallbackTest < CouchRest::Changes::IntegrationTest

  def setup
    super
    @config.flags = ['--run-once']
    @changes = CouchRest::Changes.new 'records'
  end

  def teardown
    delete
  end

  def test_triggers_created
    handler = mock 'handler'
    handler.expects(:callback)
    @changes.created { |hash| handler.callback(hash) }
    create
    @changes.listen
  end


end
