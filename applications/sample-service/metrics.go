package main

import (
	"bufio"
	"io"
	"net/http"
	"sort"
	"strconv"
	"sync"
	"time"
)

// metricsContentType is the Prometheus text format, version 0.0.4.
const metricsContentType = "text/plain; version=0.0.4; charset=utf-8"

// statusClientClosed is counted for a request that the client abandons
// before the response is written. It is not an HTTP status the service sends.
const statusClientClosed = 499

// durationBuckets are the upper bounds of the latency histogram, in seconds.
var durationBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}

type counterKey struct {
	route string
	code  string
}

type histogram struct {
	buckets []uint64 // per bucket, not cumulative. The last entry is +Inf.
	sum     float64
	count   uint64
}

// metrics holds one counter and one histogram. It is safe for concurrent use.
// Route labels are fixed strings set where a handler is registered, so the
// number of series stays small.
type metrics struct {
	mu       sync.Mutex
	requests map[counterKey]uint64
	duration map[string]*histogram
}

func newMetrics() *metrics {
	return &metrics{
		requests: map[counterKey]uint64{},
		duration: map[string]*histogram{},
	}
}

func (m *metrics) observe(route string, status int, d time.Duration) {
	secs := d.Seconds()
	idx := sort.SearchFloat64s(durationBuckets, secs) // first bucket with bound >= secs
	m.mu.Lock()
	defer m.mu.Unlock()
	m.requests[counterKey{route, strconv.Itoa(status)}]++
	h := m.duration[route]
	if h == nil {
		h = &histogram{buckets: make([]uint64, len(durationBuckets)+1)}
		m.duration[route] = h
	}
	h.buckets[idx]++
	h.sum += secs
	h.count++
}

// write renders the metrics in the Prometheus text format. Series are sorted
// by route, then by code, so the output order is fixed.
func (m *metrics) write(w io.Writer) error {
	m.mu.Lock()
	keys := make([]counterKey, 0, len(m.requests))
	counts := make(map[counterKey]uint64, len(m.requests))
	for k, v := range m.requests {
		keys = append(keys, k)
		counts[k] = v
	}
	routes := make([]string, 0, len(m.duration))
	hists := make(map[string]histogram, len(m.duration))
	for r, h := range m.duration {
		routes = append(routes, r)
		hists[r] = histogram{buckets: append([]uint64(nil), h.buckets...), sum: h.sum, count: h.count}
	}
	m.mu.Unlock()

	sort.Slice(keys, func(i, j int) bool {
		if keys[i].route != keys[j].route {
			return keys[i].route < keys[j].route
		}
		return keys[i].code < keys[j].code
	})
	sort.Strings(routes)

	bw := bufio.NewWriter(w)
	_, _ = bw.WriteString("# HELP http_requests_total Number of HTTP requests by route and status code.\n")
	_, _ = bw.WriteString("# TYPE http_requests_total counter\n")
	for _, k := range keys {
		_, _ = bw.WriteString(`http_requests_total{route="` + k.route + `",code="` + k.code + `"} ` +
			strconv.FormatUint(counts[k], 10) + "\n")
	}
	_, _ = bw.WriteString("# HELP http_request_duration_seconds Time to answer an HTTP request, by route.\n")
	_, _ = bw.WriteString("# TYPE http_request_duration_seconds histogram\n")
	for _, r := range routes {
		h := hists[r]
		var cum uint64
		for i, bound := range durationBuckets {
			cum += h.buckets[i]
			_, _ = bw.WriteString(`http_request_duration_seconds_bucket{route="` + r + `",le="` + formatFloat(bound) + `"} ` +
				strconv.FormatUint(cum, 10) + "\n")
		}
		cum += h.buckets[len(durationBuckets)]
		_, _ = bw.WriteString(`http_request_duration_seconds_bucket{route="` + r + `",le="+Inf"} ` +
			strconv.FormatUint(cum, 10) + "\n")
		_, _ = bw.WriteString(`http_request_duration_seconds_sum{route="` + r + `"} ` + formatFloat(h.sum) + "\n")
		_, _ = bw.WriteString(`http_request_duration_seconds_count{route="` + r + `"} ` +
			strconv.FormatUint(h.count, 10) + "\n")
	}
	return bw.Flush()
}

func formatFloat(v float64) string { return strconv.FormatFloat(v, 'g', -1, 64) }

// statusWriter remembers the status code that a handler wrote.
type statusWriter struct {
	http.ResponseWriter
	code  int
	wrote bool
}

func (w *statusWriter) WriteHeader(code int) {
	if !w.wrote {
		w.code = code
		w.wrote = true
	}
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Write(b []byte) (int, error) {
	if !w.wrote {
		w.code = http.StatusOK
		w.wrote = true
	}
	return w.ResponseWriter.Write(b)
}

// status returns the status code of the response. A handler that wrote nothing
// because the client left is reported as 499. Otherwise it is 200.
func (w *statusWriter) status(r *http.Request) int {
	if w.wrote {
		return w.code
	}
	if r.Context().Err() != nil {
		return statusClientClosed
	}
	return http.StatusOK
}

// instrument counts and times a handler. The route is a fixed string given
// where the handler is registered. It is never taken from the request URL.
func (m *metrics) instrument(route string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w}
		next(sw, r)
		code := sw.status(r)
		m.observe(route, code, time.Since(start))
	}
}

func (m *metrics) handler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", metricsContentType)
	_ = m.write(w)
}
