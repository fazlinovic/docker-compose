#!/bin/bash

while getopts h:u:p:b:s:a: flag
do
    case "${flag}" in
        h) HOSTNAME=${OPTARG};;
        u) ADMIN_USER=${OPTARG};;
        p) ADMIN_PASSWORD=${OPTARG};;
        b) COUCHBASE_BUCKET=${OPTARG};;
        s) COUCHBASE_DB_USERNAME=${OPTARG};;
        a) COUCHBASE_DB_PASSWORD=${OPTARG};;
    esac
done

if [ -z "$HOSTNAME" ]
then
        echo "Hostname (-h) not supplied"
        exit 1;
fi

if [ -z "$ADMIN_USER" ]
then
        echo "Admin username (-u) not supplied"
        exit 1;
fi

if [ -z "$ADMIN_PASSWORD" ]
then
        echo "Admin password (-p) not supplied"
        exit 1;
fi

if [ -z "$COUCHBASE_BUCKET" ]
then
        echo "Couchbase bucket (-b) not supplied"
        exit 1;
fi

if [ -z "$COUCHBASE_DB_USERNAME" ]
then
        echo "Couchbase username (-s) not supplied"
        exit 1;
fi

if [ -z "$COUCHBASE_DB_PASSWORD" ]
then
        echo "Couchbase password (-a) not supplied"
        exit 1;
fi

# Exit if cluster is already initialized
if /opt/couchbase/bin/couchbase-cli bucket-list -c $HOSTNAME:8091 --username=$ADMIN_USER --password=$ADMIN_PASSWORD; then
        echo "Cluster already initialized"
        exit 0;
fi

echo "Cluster not initialized. Initializing..."
# Install couchbase cluster + bucket
/opt/couchbase/bin/couchbase-cli cluster-init -c $HOSTNAME:8091 --cluster-username=$ADMIN_USER --cluster-password=$ADMIN_PASSWORD --cluster-port=8091 --cluster-index-ramsize=256 --cluster-fts-ramsize=256 --cluster-ramsize=2048 --services=data,index,query,fts
sleep 5

# Create bucket
/opt/couchbase/bin/couchbase-cli bucket-create -c $HOSTNAME:8091 -u $ADMIN_USER -p $ADMIN_PASSWORD --wait --bucket=$COUCHBASE_BUCKET --bucket-type=couchbase --bucket-ramsize=256  --bucket-replica=0
sleep 5

# Create user
/opt/couchbase/bin/couchbase-cli user-manage -c $HOSTNAME:8091 -u $ADMIN_USER -p $ADMIN_PASSWORD --set --rbac-username $COUCHBASE_DB_USERNAME --rbac-$ADMIN_PASSWORD $COUCHBASE_DB_PASSWORD --roles bucket_full_access[$COUCHBASE_BUCKET] --auth-domain local

# Build primary and secondary indices
/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE PRIMARY INDEX ON \`"$COUCHBASE_BUCKET"\` USING GSI;"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_creator_index\` ON \`"$COUCHBASE_BUCKET"\`(\`creator\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_composite_index\` ON \`"$COUCHBASE_BUCKET"\`(\`eloquent_type\`,\`team_id\`,\`deleted_at\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_deleted_at_index\` ON \`"$COUCHBASE_BUCKET"\`(\`deleted_at\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_inspection_id_index\` ON \`"$COUCHBASE_BUCKET"\`(\`inspection_id\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_team_id_index\` ON \`"$COUCHBASE_BUCKET"\`(\`team_id\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_document_type_index\` ON \`"$COUCHBASE_BUCKET"\`(\`document_type\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_eloquent_type_index\` ON \`"$COUCHBASE_BUCKET"\`(\`eloquent_type\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_type_index\` ON \`"$COUCHBASE_BUCKET"\`(\`type\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_city_index\` ON \`"$COUCHBASE_BUCKET"\`(\`city\`);"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_inspection_signature_index\` ON \`"$COUCHBASE_BUCKET"\`(\`signature_inspector\`,\`signature_customer\`) WHERE (\`eloquent_type\` = \"inspections\");"

/opt/couchbase/bin/cbq -e $HOSTNAME:8093 -u $ADMIN_USER -p $ADMIN_PASSWORD --script "CREATE INDEX \`def_inventory_item_id_index\` ON \`"$COUCHBASE_BUCKET"\`(\`inventory_item_id\`);"
