require 'rubygems'
require 'minitest/autorun'

BASE_DIR = File.expand_path('../..', __FILE__)
$:.unshift File.expand_path('lib', BASE_DIR)

require 'couchrest/changes'
require 'support/integration_test'

require 'mocha/setup'

