FROM alpine:3.19 AS builder
RUN apk add --no-cache --update shards crystal make openssl-libs-static libxml2-dev zlib-dev openssl-dev \
     xz-dev xz-static libxml2-static zlib-static
WORKDIR /crog
COPY .. /crog
RUN make

FROM alpine:3.19 AS runner
COPY --from=builder /crog/bin/crog /bin/crog
COPY --from=builder /crog/entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh
ENTRYPOINT [ "/bin/entrypoint.sh" ]
