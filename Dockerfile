# === Builder Stage ===
# Use an official hexpm image matching your mix.exs Elixir/OTP versions
# Check https://github.com/hexpm/bob/blob/main/elixir-otp-builds.csv
# From your mix.exs: elixir: "~> 1.14" - let's use 1.14 and a recent OTP like 26 on Alpine
ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=26.2.5
ARG ALPINE_VERSION=3.20
ARG BUILDER_IMAGE=hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}
ARG RUNNER_IMAGE=alpine:3.20

FROM elixir:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm python3

# Set environment for building
ENV MIX_ENV=prod
WORKDIR /app

# Copy dependency definition files
COPY mix.exs mix.lock ./

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Fetch and compile dependencies (cached layer)
RUN mix deps.get --only $MIX_ENV


# Copy configuration files needed at compile time
COPY . .

RUN mix deps.compile

# Compile the application including assets if needed
# RUN mix assets.deploy # Uncomment if you add assets later
RUN mix compile

# Build the release
# The release task copies the custom script from rel/overlays/bin
RUN mix phx.gen.release

# === Runner Stage ===
FROM alpine:3.21 AS app

# Install runtime dependencies
# openssl for crypto, ncurses for observer/debugger, libstdc++ often needed by NIFs
# busybox-extras provides 'nc' (netcat) used in the entrypoint script
RUN apk add --no-cache libstdc++ ncurses openssl

# Set default ENV variables for the runner stage
ENV LANG=C.UTF-8 \
  SHELL=/bin/sh \
  MIX_ENV=prod \
  PORT=4000 \
  ERL_MAX_PORTS=65536 \
  ERL_AFLAGS="+S 12:12"

WORKDIR /app
# Ensure the appuser owns the files
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/fmsystem ./

# Copy the custom entrypoint script
COPY migrate_and_start.sh /app/migrate_and_start.sh
# Ensure the script is executable
RUN chmod +x /app/migrate_and_start.sh
# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy the compiled release from the builder stage

# Switch to the non-root user
USER appuser

# Expose the port the application listens on (matches ENV PORT)
EXPOSE ${PORT}

# Set the entrypoint to our custom script that handles migrations
ENTRYPOINT ["/app/migrate_and_start.sh"]