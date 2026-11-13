# Captura: build Docker (verificación RPM fail-closed)
$ sudo docker build -t aws-emulator:local .
  → ADD aws-emulator-x86_64.rpm + .sig + current.asc
  → rpmkeys --import current.asc
  → rpm -K aws-emulator.rpm
/tmp/orig.rpm: digests signatures OK

# Captura: health check
$ curl -s --cacert ~/.aws/emulator/9297/ca.pem https://127.0.0.1:9297/__admin/health
ok
