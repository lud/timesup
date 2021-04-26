# ---- Build Stage ----
FROM bitwalker/alpine-elixir-phoenix:latest AS builder

WORKDIR /home/app

# Set exposed ports
ENV MIX_ENV=prod

# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

# Same with npm deps
COPY assets/package.json assets/
COPY assets/package-lock.json assets/
RUN cd assets && \
    npm install

COPY config config
COPY lib lib
COPY mix.exs mix.exs
COPY mix.lock mix.lock
COPY priv priv

COPY assets/.babelrc assets/
COPY assets/css assets/css
COPY assets/js assets/js
COPY assets/static assets/static
COPY assets/webpack.config.js assets/

# Run frontend build, compile, and digest assets
RUN cd assets/ && \
    npm run deploy && \
    cd - && \
    mix do compile, phx.digest, release

# ---- Build Stage ----
FROM alpine:3.10 AS app

# Install openssl
RUN apk add --no-cache openssl zlib ncurses-libs ca-certificates

# Copy over the build artifact from the previous step and create a
# non-root user
RUN adduser -D app
WORKDIR /home/app
COPY --from=builder /home/app/_build/prod/rel/timesup .
RUN chown -R app: .
USER app

# Run the release
CMD ["./bin/timesup", "start"]