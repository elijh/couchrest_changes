#
# Setup CouchDB for testing.
#

TEST_DB_NAME = 'records'

def save_doc(db, record)
  id = record["_id"]
  db.save_doc(record)
  puts "    * created #{db.name}/#{id}"
rescue RestClient::Conflict
  puts "    * #{db.name}/#{id} already exists"
rescue RestClient::Exception => exc
  puts "    * Error saving #{db.name}/#{id}: #{exc}"
end

def super_host(config)
  config.couch_host(:username => 'superadmin', :password => 'secret')
end

# remove prior superadmin, if it happens to exist
def remove_super_admin(config)
  begin
    CouchRest.delete(super_host(config) + "/_config/admins/superadmin")
    puts "    * removed superadmin"
  rescue RestClient::ResourceNotFound
  rescue RestClient::Unauthorized
  rescue RestClient::Exception => exc
    puts "    * Unable to remove superadmin from CouchDB: #{exc}"
  end
end

# add superadmin to remove admin party
def create_super_admin(config)
  begin
    CouchRest.put(config.couch_host_no_auth + "/_config/admins/superadmin", 'secret')
    puts "    * created superadmin"
  rescue RestClient::ResourceNotFound
  rescue RestClient::Exception => exc
    puts "    * Unable to add superadmin from CouchDB: #{exc}"
  end
end

def setup_couchdb
  CouchRest::Changes::Config.load(BASE_DIR, 'test/config.yaml').tap do |config|
    remove_super_admin(config)
    create_super_admin(config)
    CouchRest.new(super_host(config)).database('_users').tap do |db|
      # create unprivileged user
      save_doc(db, {
        "_id" => "org.couchdb.user:me",
        "name" => "me",
        "roles" => ["normal"],
        "type" => "user",
        "password" => "password"
      })
      # create privileged user
      save_doc(db, {
        "_id" => "org.couchdb.user:anna",
        "name" => "anna",
        "roles" => ["admin"],
        "type" => "user",
        "password" => "secret"
      })
    end
    CouchRest.new(super_host(config)).database(config.complete_db_name(TEST_DB_NAME)).tap do |db|
      db.create!
      puts "    * created db #{db}"
      save_doc(db, {
        "_id" => "_security",
        "admins" => {
          "names" => ["anna"],
          "roles" => ["admin"]
        },
        "members" => {
          "names" => ["me"],
          "roles" => ["normal"]
        }
      })
    end
    Minitest.after_run do
      remove_super_admin(config)
    end
  end
end
