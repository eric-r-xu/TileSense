# Build a self-contained ingest binary, then run it on a tiny base image.
# Used by DO App Platform (Option B) or any container host.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/server.dart -o /app/ingest

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/ingest /usr/local/bin/ingest
COPY --from=build /runtime/ /
EXPOSE 8787
ENV PORT=8787
ENV BIND_ADDR=0.0.0.0
CMD ["/usr/local/bin/ingest"]
