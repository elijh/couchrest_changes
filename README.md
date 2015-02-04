CouchRest::Changes - keeping track of changes to your couch
------------------------------------------------------------

``CouchRest::Changes`` let's you observe a couch database for changes and react
upon them.

Following the changes of a couch is as easy as
```ruby
users = CouchRest::Changes.new('users')
```

Callbacks can be defined in blocks:
```ruby
users.created do |hash|
  puts "A new user was created with the id: #{hash[:id]}"
end
```

To start listening just call
```ruby
users.listen
```

This program is written in Ruby and is distributed under the same license as
CouchRest (Apache License, Version 2.0 http://www.apache.org/licenses/).

Installation
---------------------

Just add couchrest_changes to your Gemfile.

Configuration
---------------------

``couchrest_changes`` can be configured through ``CouchRest::Changes::Config``

The default options are similar to the ones used by CouchRest::Model:


```yaml
# couch connection configuration
connection:
  protocol: "http"
  host: "localhost"
  port: 5984
  username: ~
  password: ~
  prefix: ""
  suffix: ""
  netrc: ""

# file to store the last processed user record in so we can resume after
# a restart:
seq_file: "/var/log/couch_changes_users.seq"

# Configure log_file like this if you want to log to a file instead of syslog:
# log_file: "/var/log/couch_changes.log"
log_level: debug

options:
  your_own_options: "go here"
```

Normally, CouchRest leaks the CouchDB authentication credentials in the process list. If present, the ``netrc`` configuration value will allow CouchRest::Changes to use the netrc file and keep the credentials out of the process list.

Examples
------------------------

See [tapicero](https://github.com/leapcode/tapicero) for a daemon that uses CouchRest::Changes. Historically CouchRest::Changes was extracted from tapicero.

Known Issues
-------------

* CouchRest will miss the first change in a continuous feed.
  https://github.com/couchrest/couchrest/pull/104 has a fix.
  You might want to monkeypatch it.
