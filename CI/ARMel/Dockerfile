FROM balenalib/armv5e-debian:buster
COPY entrypoint.sh /entrypoint.sh
RUN apt-get update && apt-get install -y libgdk-pixbuf2.0-0
ENTRYPOINT ["/entrypoint.sh"]
