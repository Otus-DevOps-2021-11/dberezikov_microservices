FROM alpine:3.14

WORKDIR /app
ADD . /app

RUN apk update \
    && apk add ruby ruby-dev ruby-full g++ make \
    && gem install bundler:1.17.2 \
    && bundle install \
    && apk del ruby-dev g++ make

ENV COMMENT_DATABASE_HOST=comment_db \
    COMMENT_DATABASE=comments

CMD ["puma"]
