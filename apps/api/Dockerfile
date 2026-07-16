# --- Stage 1: build ---
FROM golang:1.26 AS builder
WORKDIR /src

# Dependencies first — cached unless go.mod/go.sum change
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -tags netgo -o /app .

# --- Stage 2: run ---
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
