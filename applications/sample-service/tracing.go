package main

import (
	"context"
	"net/http"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

// tracerName is the name of the instrumentation scope.
const tracerName = "sample-service"

// initTracing installs a tracer provider that sends spans over OTLP/HTTP. The
// exporter reads its endpoint from OTEL_EXPORTER_OTLP_ENDPOINT. If that
// variable is unset, tracing is off: nothing is installed and the returned
// shutdown function does nothing. The sampler is the SDK default, which is
// parent-based and samples every root span.
func initTracing(ctx context.Context) (func(context.Context) error, error) {
	noop := func(context.Context) error { return nil }
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		return noop, nil
	}

	exp, err := otlptracehttp.New(ctx)
	if err != nil {
		return noop, err
	}
	name := os.Getenv("OTEL_SERVICE_NAME")
	if name == "" {
		name = "sample-service"
	}
	res, err := resource.Merge(resource.Default(),
		resource.NewSchemaless(attribute.String("service.name", name)))
	if err != nil {
		return noop, err
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return tp.Shutdown, nil
}

// traced creates one server span for a handler. The span name is the fixed
// route. An incoming W3C traceparent header becomes the parent. The span
// context is passed to the handler through the request context. Only /work is
// wrapped, so probes do not produce spans.
func (s *server) traced(route string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := propagation.TraceContext{}.Extract(r.Context(), propagation.HeaderCarrier(r.Header))
		ctx, span := s.tracer.Start(ctx, route,
			trace.WithSpanKind(trace.SpanKindServer),
			trace.WithAttributes(
				attribute.String("http.request.method", r.Method),
				attribute.String("http.route", route),
			))
		defer span.End()

		sw := &statusWriter{ResponseWriter: w}
		r = r.WithContext(ctx)
		next(sw, r)

		code := sw.status(r)
		span.SetAttributes(attribute.Int("http.response.status_code", code))
		// A request that the client abandoned (499) is not a server error.
		if code >= http.StatusInternalServerError {
			span.SetStatus(codes.Error, "")
		}
	}
}
