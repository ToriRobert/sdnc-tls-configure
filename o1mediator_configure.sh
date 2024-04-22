#!/bin/bash
o1mediator_pod=`kubectl get pods -n ricplt|grep o1mediator|awk '{print $1}'`
copy_file_to_o1mediator(){
    kubectl cp "$1" "$o1mediator_pod:/root/$(basename $1)" -n ricplt
}
exec_command_in_o1mediator(){
    kubectl exec -it "$o1mediator_pod" -n ricplt -- /bin/bash -c "$1"
}
if [ ! -z "$o1mediator_pod" ]; then
    copy_file_to_o1mediator "keystore.xml"
    copy_file_to_o1mediator "truststore.xml"
    copy_file_to_o1mediator "netconf_server_tls.xml"    
    exec_command_in_o1mediator 'sysrepocfg --edit=/root/keystore.xml --format=xml --datastore=running --module=ietf-keystore -v3'
    exec_command_in_o1mediator 'sysrepocfg --edit=/root/truststore.xml --format=xml --datastore=running --module=ietf-truststore -v3'
    exec_command_in_o1mediator 'sysrepocfg --edit=/root/netconf_server_tls.xml --format=xml --datastore=running --module=ietf-netconf-server -v3'
    o1mediator_netconf_tls=`kubectl get svc -n ricplt|grep 'o1mediator-tls-netconf'`
    if [  -z "$o1mediator_netconf_tls" ]; then
        echo "Please add o1mediator netconf tls service to expose 6513 port!"
    else
        netconf_tls_ip=`echo "$o1mediator_netconf_tls"|awk '{print $3}'`
        netconf_tls_port=`echo "$o1mediator_netconf_tls"|awk '{print $5}'|cut -d ':' -f 1`
        echo "Netconf Server: $netconf_tls_ip:$netconf_tls_port"
    fi
fi