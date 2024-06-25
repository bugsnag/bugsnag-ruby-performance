ARG RUBY_TEST_VERSION
FROM ruby:$RUBY_TEST_VERSION

WORKDIR /bugsnag-performance
COPY temp-bugsnag-performance ./

WORKDIR /usr/src/app
COPY app/ /usr/src/app
RUN bundle install
