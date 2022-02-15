FROM alpine:3.14

WORKDIR /app
ADD . /app

RUN apk update \
    && apk add ruby ruby-dev ruby-full g++ make \
    && gem install bundler:1.17.2 \
    && bundle install \
    && apk del ruby-dev g++ make

ENV POST_SERVICE_HOST=post \
    POST_SERVICE_PORT=5000 \
    COMMENT_SERVICE_HOST=comment \
    COMMENT_SERVICE_PORT=9292

CMD ["puma"]
