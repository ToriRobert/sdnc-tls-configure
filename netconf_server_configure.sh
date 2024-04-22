#!/bin/bash
current_folder="$(dirname -- "$0")"
sdnc_controller="https://ntust-sdnc.ddns.net"
basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
SDNR_PATH="$current_folder/sdnr"
key_name="keys0"
key_folder="$SDNR_PATH/$key_name"
key_folder_exist="1"
if [ ! -e "$key_folder" ]; then
    key_folder_exist=""
fi
import_type="edit"
datastore_type="running"
check_cert_not_exist_in_file(){
    if [ -z "$1" ] || [ -z "$2" ] || [ ! -e "$1" ] || [ ! -e "$2" ] ; then
        false;
        return;
    fi
    file_to_contain="$1";
    file_to_match="$2";
    diff "$file_to_contain" "$file_to_match"|grep -qE '[0-9]+(b|c|d)[0-9]+';
    if [ $? -eq 0 ]; then
          true; # file_to_contain's Cert Not Exist in file_to_match!
          return;
    else
        false; # file_to_contain's Cert Exist in file_to_match!
        return;
    fi
}
add_trusted_certificates(){
    rsa_server_crt_64=`cat "$1" |sed '/^-----.*/d'`
    rsa_server_crt_64="${rsa_server_crt_64//$'\n'/\\n}"
    server_node_name="$2"
    tmp_file="/tmp/tmp-$2.crt"
    echo "$1" > "$tmp_file"
    has_added_trusted=`curl -s -u "$basicAuth" "$sdnc_controller/restconf/config/netconf-keystore:keystore"|jq '.keystore."trusted-certificate"| to_entries[]| select(.value.name == "'$server_node_name'")| select(.value.certificate == "'$rsa_server_crt_64'")'`
    if [ -z "$has_added_trusted" ]; then #Cert not in trust certificates
        # Check node $server_node_name exist in netconf topology
        topology_list=`curl -s -u $basicAuth "$sdnc_controller/restconf/config/network-topology:network-topology/topology/topology-netconf"`
        node_exist_in_topology=`echo $topology_list|jq '.topology| to_entries[]| select(.value."topology-id" == "topology-netconf")| .value.node| to_entries[]| select(.value."node-id" == "'$server_node_name'")' 2>/dev/null`
        if [ -z "$node_exist_in_topology" ]; then
            curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "PUT" "$sdnc_controller/restconf/config/network-topology:network-topology/topology/topology-netconf/node/$server_node_name" --data '{"node": [{"node-id": "'$server_node_name'"}]}'
            echo "Node $server_node_name added!"
        else
            echo "Node $server_node_name detected!"
        fi
        old_cert=`curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "GET" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name"|jq '."netconf-keystore:trusted-certificate"| to_entries[]| .value.certificate' 2>/dev/null`
        if [ ! -z "$old_cert" ]; then
            old_cert="${old_cert:1:-1}"
            echo 'old cert found!'
            curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "DELETE" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name"
            if [ "$key_folder_exist" -eq "1" ]; then
                matched_line_nums=$(grep -wn "${old_cert//\\n/$'\n'}" "$key_folder/trustedCertificates.crt"|cut -d ':' -f 1|xargs)
                if [ ! -z "$matched_line_nums" ]; then
                    old_cert_line_start=`echo "${matched_line_nums// /$'\n'}"|head -n1`;
                    old_cert_line_end=`echo "${matched_line_nums// /$'\n'}"|tail -n1`;
                    trustedCertificates_contents=`cat "$key_folder/trustedCertificates.crt" | awk '{if (NR<'$((old_cert_line_start - 1))' || NR >'$((old_cert_line_end + 1))') print}'`;
                    echo "$trustedCertificates_contents" > "$key_folder/trustedCertificates.crt";
                fi
            fi
        fi
        #Add trust certificate by using restapi of ODL
        curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "POST" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name" --data "{'certificate': '$rsa_server_crt_64'}"
        if [ "$key_folder_exist" -eq "1" ]; then
            if check_cert_not_exist_in_file "$tmp_file.crt" "$key_folder/trustedCertificates.crt"; then
                x=$(tail -c 1 "$key_folder/trustedCertificates.crt")
                if [ "$x" != "" ]; then
                    echo "" >> "$key_folder/trustedCertificates.crt"; #Add newline if last character exist
                fi
                cat "$server_filename.crt" >> "$key_folder/trustedCertificates.crt";
                rewrite_key_zip;
            fi
        fi
        echo "Trust Certificate for $server_node_name added!"
    else
        echo "Trust Certificate for $server_node_name detected!"    
    fi
}
if [ ! -z "$(which sysrepocfg)" ]; then
    add_trusted_certificates "server.crt" "odu-high"
    sysrepocfg --$import_type=keystore.xml --format=xml --datastore=$datastore_type --module=ietf-keystore -v3
    sysrepocfg --$import_type=truststore.xml --format=xml --datastore=$datastore_type --module=ietf-truststore -v3
    sysrepocfg --$import_type=netconf_server_tls.xml --format=xml --datastore=$datastore_type --module=ietf-netconf-server -v3
    sysrepocfg --copy-from=running --datastore=startup
fi
if [ ! -z "$(which docker)" ]; then
    docker_sim_list="ntsim-ng-topology-server ntsim-ng-o-du-1122 ntsim-ng-o-ru-fh-11221 ntsim-ng-o-ru-fh-11222 ntsim-ng-o-ru-fh-11223"
    for container in $docker_sim_list; do
        # docker cp 'keystore.xml' "$container:/root/keystore.xml"
        docker cp 'truststore.xml' "$container:/root/truststore.xml"
        # docker cp 'netconf_server_tls.xml' "$container:/root/netconf_server_tls.xml"
        # docker exec -it "$container" bash -c "sysrepocfg --$import_type=/root/keystore.xml --format=xml --datastore=$datastore_type --module=ietf-keystore -v3"
        docker exec -it "$container" bash -c "sysrepocfg --$import_type=/root/truststore.xml --format=xml --datastore=$datastore_type --module=ietf-truststore -v3"
        # docker exec -it "$container" bash -c "sysrepocfg --$import_type=/root/netconf_server_tls.xml --format=xml --datastore=$datastore_type --module=ietf-netconf-server -v3"
        docker exec -it "$container" bash -c "sysrepocfg --copy-from=running --datastore=startup"
    done
fi