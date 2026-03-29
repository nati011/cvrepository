# API + worker binaries (commands set in docker-compose)
FROM golang:1.22-alpine AS build
RUN apk add --no-cache git ca-certificates
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /out/api ./cmd/api && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /out/worker ./cmd/worker

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=build /out/api /app/api
COPY --from=build /out/worker /app/worker
