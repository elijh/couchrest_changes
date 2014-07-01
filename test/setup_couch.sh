#!/bin/bash

HOST="http://localhost:5984"
echo "couch version :"
curl -X GET $HOST
echo "creating unprivileged user :"
curl -HContent-Type:application/json -XPUT $HOST/_users/org.couchdb.user:me --data-binary '{"_id": "org.couchdb.user:me","name": "me","roles": [],"type": "user","password": "pwd"}'
echo "creating database to watch:"
curl -X PUT $HOST/couchrest_changes_test_records
echo "restricting database access :"
curl -X PUT $HOST/couchrest_changes_test_records/_security -Hcontent-type:application/json --data-binary '{"admins":{"names":[],"roles":[]},"members":{"names":["me"],"roles":[]}}'
echo "adding admin :"
curl -X PUT $HOST/_config/admins/anna -d '"secret"'
