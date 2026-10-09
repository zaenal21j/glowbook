# syntax=docker/dockerfile:1

# Keep this in sync with .ruby-version.
ARG RUBY_VERSION=3.4.7
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y curl libpq5 libvips \
    && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

FROM base AS build

RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN sed -i 's/\r$//' Gemfile Gemfile.lock \
    && bundle install \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN chmod +x bin/rails bin/rake bin/jobs bin/docker-entrypoint \
    && bundle exec bootsnap precompile -j 1 --gemfile \
    && bundle exec bootsnap precompile -j 1 app/ lib/ \
    && SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

RUN groupadd --system --gid 1000 rails \
    && useradd --system --uid 1000 --gid 1000 --create-home --shell /bin/bash rails \
    && mkdir -p /rails/storage /rails/tmp/pids /rails/log \
    && chown -R rails:rails /rails/storage /rails/tmp /rails/log

COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails

RUN chmod +x /rails/bin/jobs /rails/bin/docker-entrypoint

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server"]
