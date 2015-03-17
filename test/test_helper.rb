require 'rubygems'
gem 'minitest'
require 'minitest/autorun'

BASE_DIR = File.expand_path('../..', __FILE__)
$:.unshift File.expand_path('lib', BASE_DIR)
$:.unshift File.dirname(__FILE__)

require 'couchrest/changes'
require 'support/integration_helper'
require 'mocha/setup'
require 'setup_couchdb'

puts
puts "  SETTING UP COUCHDB FOR TESTS:"
puts
setup_couchdb()
puts
