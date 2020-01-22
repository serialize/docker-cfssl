FROM golang:alpine as build-env

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        gcc \
        git \
        libtool \
        sqlite-dev \
    && apk add --no-cache \
        curl \
        python \
    && mkdir -p /cfssl-bin

RUN git clone --depth=1 "https://github.com/cloudflare/cfssl.git" "${GOPATH}/src/github.com/cloudflare/cfssl" \
    && cd "${GOPATH}/src/github.com/cloudflare/cfssl" \
    && go get github.com/GeertJohan/go.rice/rice && rice embed-go -i=./cli/serve \
	&& go build -o /cfssl-bin/cfssl ./cmd/cfssl \
	&& go build -o /cfssl-bin/cfssljson ./cmd/cfssljson \
	&& go build -o /cfssl-bin/mkbundle ./cmd/mkbundle \
	&& go build -o /cfssl-bin/multirootca ./cmd/multirootca \
	&& apk del .build-deps \
	&& rm -rf "${GOPATH}/src"

VOLUME /cfssl-bin


FROM alpine:3.10

COPY --from=build-env /cfssl-bin /usr/bin

RUN apk add --no-cache bash curl sqlite \
    && addgroup -S cfssl -g 500 \
    && adduser -S -g cfssl --uid 500 cfssl \
	&& mkdir -p /etc/cfssl /etc/pki \
    && chown -R cfssl:cfssl \
                /etc/cfssl /etc/pki \
                /usr/bin/cfssl \
                /usr/bin/cfssljson \
                /usr/bin/mkbundle \
                /usr/bin/multirootca \
    && chmod -R 770 \
                /etc/cfssl /etc/pki \
                /usr/bin/cfssl \
                /usr/bin/cfssljson \
                /usr/bin/mkbundle \
                /usr/bin/multirootca 

USER cfssl

WORKDIR /etc/cfssl

VOLUME [ "/etc/cfssl" ]

ENV CFSSL_CA_CRT ca.pem
ENV CFSSL_CA_KEY ca-key.pem
ENV CFSSL_TLS_CRT tls.pem
ENV CFSSL_TLS_KEY tls-key.pem
ENV CFSSL_CONFIG config.json
ENV CFSSL_DB_CONFIG db-config.json

ENTRYPOINT [ "cfssl" ]

CMD [ "--help" ]
