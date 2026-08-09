openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=dev-sidecar/CN=DevSidecar" \
    -keyout dev-sidecar.ca.key.pem -out dev-sidecar.ca.crt
