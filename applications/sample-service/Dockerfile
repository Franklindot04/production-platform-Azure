FROM golang:1.27.3-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/sample-service .

FROM scratch
COPY --from=build /out/sample-service /sample-service
USER 65532:65532
EXPOSE 8080 8081
ENTRYPOINT ["/sample-service"]
