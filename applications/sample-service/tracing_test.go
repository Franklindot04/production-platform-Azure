package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
)

// tracedServer returns a server that records its spans in memory.
func tracedServer(t *testing.T, latency time.Duration, rate float64) (*server, *tracetest.SpanRecorder) {
	t.Helper()
	s := testServer(t, latency, rate)
	rec := tracetest.NewSpanRecorder()
	tp := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(rec))
	t.Cleanup(func() { _ = tp.Shutdown(context.Background()) })
	s.tracer = tp.Tracer("test")
	return s, rec
}

func attr(span sdktrace.ReadOnlySpan, key string) (attribute.Value, bool) {
	for _, kv := range span.Attributes() {
		if string(kv.Key) == key {
			return kv.Value, true
		}
	}
	return attribute.Value{}, false
}

func TestTraceOneSpanPerWorkRequest(t *testing.T) {
	s, rec := tracedServer(t, 0, 0)
	do(s.apiHandler(), http.MethodGet, "/work", "")

	spans := rec.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d, want 1", len(spans))
	}
	span := spans[0]
	if span.Name() != "/work" {
		t.Errorf("name = %q", span.Name())
	}
	if span.SpanKind() != trace.SpanKindServer {
		t.Errorf("kind = %v", span.SpanKind())
	}
	if v, ok := attr(span, "http.request.method"); !ok || v.AsString() != "GET" {
		t.Errorf("http.request.method = %v", v)
	}
	if v, ok := attr(span, "http.route"); !ok || v.AsString() != "/work" {
		t.Errorf("http.route = %v", v)
	}
	if v, ok := attr(span, "http.response.status_code"); !ok || v.AsInt64() != 200 {
		t.Errorf("http.response.status_code = %v", v)
	}
	if span.Status().Code != codes.Unset {
		t.Errorf("status = %v, want unset", span.Status().Code)
	}
}

func TestTraceMarksServerErrors(t *testing.T) {
	s, rec := tracedServer(t, 0, 0.5)
	s.chance = func() float64 { return 0.1 }
	do(s.apiHandler(), http.MethodGet, "/work", "")

	spans := rec.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d, want 1", len(spans))
	}
	if v, _ := attr(spans[0], "http.response.status_code"); v.AsInt64() != 500 {
		t.Errorf("status code = %v", v)
	}
	if spans[0].Status().Code != codes.Error {
		t.Errorf("status = %v, want error", spans[0].Status().Code)
	}
}

func TestTraceSkipsProbes(t *testing.T) {
	s, rec := tracedServer(t, 0, 0)
	h := s.apiHandler()
	do(h, http.MethodGet, "/healthz", "")
	do(h, http.MethodGet, "/readyz", "")
	if n := len(rec.Ended()); n != 0 {
		t.Fatalf("spans = %d, want 0", n)
	}
	// Metrics still count the probes.
	body := scrape(t, s)
	if got := value(body, `http_requests_total{route="/healthz",code="200"}`); got != 1 {
		t.Errorf("healthz count = %v", got)
	}
}

func TestTraceAbandonedRequest(t *testing.T) {
	s, rec := tracedServer(t, time.Second, 0)
	ctx, cancel := context.WithCancel(context.Background())
	req := httptest.NewRequest(http.MethodGet, "/work", nil).WithContext(ctx)
	go func() {
		time.Sleep(10 * time.Millisecond)
		cancel()
	}()
	s.apiHandler().ServeHTTP(httptest.NewRecorder(), req)

	spans := rec.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d, want 1", len(spans))
	}
	if v, _ := attr(spans[0], "http.response.status_code"); v.AsInt64() != 499 {
		t.Errorf("status code = %v, want 499", v)
	}
	if spans[0].Status().Code == codes.Error {
		t.Error("an abandoned request must not be marked as an error")
	}
}

func TestTraceIncomingTraceparentIsTheParent(t *testing.T) {
	s, rec := tracedServer(t, 0, 0)
	req := httptest.NewRequest(http.MethodGet, "/work", nil)
	req.Header.Set("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ec3b6f8-01")
	s.apiHandler().ServeHTTP(httptest.NewRecorder(), req)

	spans := rec.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d, want 1", len(spans))
	}
	if got := spans[0].SpanContext().TraceID().String(); got != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Errorf("trace id = %s", got)
	}
	if got := spans[0].Parent().SpanID().String(); got != "00f067aa0ec3b6f8" {
		t.Errorf("parent span id = %s", got)
	}
}

func TestTraceSpanContextReachesTheHandler(t *testing.T) {
	s, _ := tracedServer(t, 0, 0)
	var valid bool
	h := s.traced("/work", func(w http.ResponseWriter, r *http.Request) {
		valid = trace.SpanFromContext(r.Context()).SpanContext().IsValid()
		w.WriteHeader(http.StatusOK)
	})
	do(h, http.MethodGet, "/work", "")
	if !valid {
		t.Fatal("the handler context has no valid span")
	}
}

func TestTracingIsOffWithoutEndpoint(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	before := otel.GetTracerProvider()

	shutdown, err := initTracing(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if shutdown == nil {
		t.Fatal("shutdown is nil")
	}
	if err := shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
	if otel.GetTracerProvider() != before {
		t.Error("a tracer provider was installed")
	}
}
