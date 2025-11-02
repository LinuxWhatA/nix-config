openssl genrsa -out dev-sidecar.ca.key.pem 2048
openssl req -x509 -new -nodes -key dev-sidecar.ca.key.pem -sha256 -days 365 \
    -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=dev-sidecar/CN=DevSidecar" \
    -out dev-sidecar.ca.crt