rm -f server.key server.csr server.pem server.crt keystore.xml truststore.xml netconf_server_tls.xml
git reset -- rootCA.*
git checkout -- rootCA.*
rm -f sdnr/certs/*
git reset -- sdnr/keys0
git checkout -- sdnr/keys0