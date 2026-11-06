package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// scrape returns the body of GET /metrics on the admin handler.
func scrape(t *testing.T, s *server) string {
	t.Helper()
	rec := do(s.adminHandler(), http.MethodGet, "/metrics", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("metrics = %d", rec.Code)
	}
	if got := rec.Header().Get("Content-Type"); got != "text/plain; version=0.0.4; charset=utf-8" {
		t.Fatalf("content type = %q", got)
	}
	return rec.Body.String()
}

// scrapeErr is like scrape for goroutines other than the test's. It reports
// with t.Errorf and returns, because FailNow must run on the test goroutine.
func scrapeErr(t *testing.T, s *server) {
	t.Helper()
	rec := do(s.adminHandler(), http.MethodGet, "/metrics", "")
	if rec.Code != http.StatusOK {
		t.Errorf("metrics = %d", rec.Code)
	}
}

// value returns the value of the line that starts with series, or -1.
func value(body, series string) float64 {
	for _, line := range strings.Split(body, "\n") {
		if strings.HasPrefix(line, series+" ") {
			v, err := strconv.ParseFloat(strings.TrimPrefix(line, series+" "), 64)
			if err != nil {
				return -2
			}
			return v
		}
	}
	return -1
}

func TestMetricsCountRequests(t *testing.T) {
	s := testServer(t, 0, 0.5)
	h := s.apiHandler()

	s.chance = func() float64 { return 0.9 }
	do(h, http.MethodGet, "/work", "")
	do(h, http.MethodGet, "/work", "")
	s.chance = func() float64 { return 0.1 }
	do(h, http.MethodGet, "/work", "")
	do(h, http.MethodGet, "/healthz", "")
	s.setReady(false)
	do(h, http.MethodGet, "/readyz", "")

	body := scrape(t, s)
	for series, want := range map[string]float64{
		`http_requests_total{route="/work",code="200"}`:      2,
		`http_requests_total{route="/work",code="500"}`:      1,
		`http_requests_total{route="/healthz",code="200"}`:   1,
		`http_requests_total{route="/readyz",code="503"}`:    1,
		`http_request_duration_seconds_count{route="/work"}`: 3,
	} {
		if got := value(body, series); got != want {
			t.Errorf("%s = %v, want %v", series, got, want)
		}
	}
}

func TestMetricsCountAbandonedWork(t *testing.T) {
	s := testServer(t, time.Second, 0)
	ctx, cancel := context.WithCancel(context.Background())
	req := httptest.NewRequest(http.MethodGet, "/work", nil).WithContext(ctx)
	go func() {
		time.Sleep(10 * time.Millisecond)
		cancel()
	}()
	s.apiHandler().ServeHTTP(httptest.NewRecorder(), req)

	body := scrape(t, s)
	if got := value(body, `http_requests_total{route="/work",code="499"}`); got != 1 {
		t.Fatalf("499 count = %v\n%s", got, body)
	}
	if got := value(body, `http_requests_total{route="/work",code="200"}`); got != -1 {
		t.Fatalf("abandoned request was also counted as 200")
	}
}

func TestMetricsHistogramIsCumulative(t *testing.T) {
	m := newMetrics()
	for _, d := range []time.Duration{
		2 * time.Millisecond, 7 * time.Millisecond, 30 * time.Millisecond, 3 * time.Second, 20 * time.Second,
	} {
		m.observe("/work", 200, d)
	}
	var sb strings.Builder
	if err := m.write(&sb); err != nil {
		t.Fatal(err)
	}
	body := sb.String()

	prev := -1.0
	for _, le := range []string{"0.005", "0.01", "0.025", "0.05", "0.1", "0.25", "0.5", "1", "2.5", "5", "10", "+Inf"} {
		got := value(body, `http_request_duration_seconds_bucket{route="/work",le="`+le+`"}`)
		if got < prev {
			t.Fatalf("bucket le=%s = %v after %v: not cumulative", le, got, prev)
		}
		prev = got
	}
	count := value(body, `http_request_duration_seconds_count{route="/work"}`)
	if inf := value(body, `http_request_duration_seconds_bucket{route="/work",le="+Inf"}`); inf != count || count != 5 {
		t.Fatalf("+Inf = %v, count = %v, want both 5", inf, count)
	}
	if got := value(body, `http_request_duration_seconds_bucket{route="/work",le="0.005"}`); got != 1 {
		t.Fatalf("le=0.005 = %v, want 1", got)
	}
	if got := value(body, `http_request_duration_seconds_bucket{route="/work",le="10"}`); got != 4 {
		t.Fatalf("le=10 = %v, want 4", got)
	}
}

func TestMetricsLatencyLandsInTheRightBucket(t *testing.T) {
	s := testServer(t, 30*time.Millisecond, 0)
	do(s.apiHandler(), http.MethodGet, "/work", "")

	body := scrape(t, s)
	if got := value(body, `http_request_duration_seconds_bucket{route="/work",le="0.025"}`); got != 0 {
		t.Errorf("le=0.025 = %v, want 0", got)
	}
	if got := value(body, `http_request_duration_seconds_bucket{route="/work",le="+Inf"}`); got != 1 {
		t.Errorf("+Inf = %v, want 1", got)
	}
	if got := value(body, `http_request_duration_seconds_sum{route="/work"}`); got < 0.03 {
		t.Errorf("sum = %v, want at least 0.03", got)
	}
}

func TestMetricsFormat(t *testing.T) {
	s := testServer(t, 0, 0)
	do(s.apiHandler(), http.MethodGet, "/work", "")
	body := scrape(t, s)

	for _, want := range []string{
		"# HELP http_requests_total ",
		"# TYPE http_requests_total counter",
		"# HELP http_request_duration_seconds ",
		"# TYPE http_request_duration_seconds histogram",
	} {
		if !strings.Contains(body, want) {
			t.Errorf("output lacks %q", want)
		}
	}
	if !strings.HasSuffix(body, "\n") {
		t.Error("output does not end with a newline")
	}
	if scrape(t, s) != body {
		t.Error("output order is not fixed")
	}
}

func TestAPIDoesNotServeMetrics(t *testing.T) {
	s := testServer(t, 0, 0)
	if got := do(s.apiHandler(), http.MethodGet, "/metrics", "").Code; got != http.StatusNotFound {
		t.Fatalf("API /metrics = %d, want 404", got)
	}
}

func TestMetricsRoutesAreFixed(t *testing.T) {
	s := testServer(t, 0, 0)
	h := s.apiHandler()
	for _, path := range []string{"/work", "/healthz", "/readyz", "/work?x=1", "/unknown/1", "/metrics", "/healthz/extra"} {
		do(h, http.MethodGet, path, "")
	}
	allowed := map[string]bool{"/healthz": true, "/readyz": true, "/work": true}
	re := regexp.MustCompile(`route="([^"]*)"`)
	matches := re.FindAllStringSubmatch(scrape(t, s), -1)
	if len(matches) == 0 {
		t.Fatal("no route label found")
	}
	for _, m := range matches {
		if !allowed[m[1]] {
			t.Errorf("unexpected route label %q", m[1])
		}
	}
}

func TestMetricsConcurrentRequests(t *testing.T) {
	s := testServer(t, 0, 0)
	h := s.apiHandler()
	const workers, each = 8, 50

	var wg sync.WaitGroup
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range each {
				do(h, http.MethodGet, "/work", "")
				scrapeErr(t, s)
			}
		}()
	}
	wg.Wait()

	body := scrape(t, s)
	want := float64(workers * each)
	if got := value(body, `http_requests_total{route="/work",code="200"}`); got != want {
		t.Fatalf("count = %v, want %v", got, want)
	}
	if got := value(body, `http_request_duration_seconds_bucket{route="/work",le="+Inf"}`); got != want {
		t.Fatalf("+Inf = %v, want %v", got, want)
	}
}
