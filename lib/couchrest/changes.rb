require 'couchrest'
require 'fileutils'
require 'pathname'

require 'couchrest/changes/config'
require 'couchrest/changes/observer'

module CouchRest
  module Changes

    class << self
      def new(*opts)
        Observer.new(*opts)
      end
    end
  end
end
