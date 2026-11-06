package main

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func testServer(t *testing.T, latency time.Duration, rate float64) *server {
	t.Helper()
	s, err := newServer(latency, rate, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func do(h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestHealthAndReady(t *testing.T) {
	s := testServer(t, 0, 0)
	h := s.apiHandler()

	if got := do(h, http.MethodGet, "/healthz", "").Code; got != http.StatusOK {
		t.Fatalf("healthz = %d", got)
	}
	if got := do(h, http.MethodGet, "/readyz", "").Code; got != http.StatusOK {
		t.Fatalf("readyz = %d", got)
	}
	s.setReady(false)
	if got := do(h, http.MethodGet, "/readyz", "").Code; got != http.StatusServiceUnavailable {
		t.Fatalf("readyz when not ready = %d", got)
	}
	if got := do(h, http.MethodGet, "/healthz", "").Code; got != http.StatusOK {
		t.Fatalf("healthz when not ready = %d", got)
	}
}

func TestWorkSucceedsWithoutErrors(t *testing.T) {
	h := testServer(t, 0, 0).apiHandler()
	rec := do(h, http.MethodGet, "/work", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("work = %d", rec.Code)
	}
}

func TestWorkErrorRate(t *testing.T) {
	s := testServer(t, 0, 0.5)

	s.chance = func() float64 { return 0.49 }
	if got := do(s.apiHandler(), http.MethodGet, "/work", "").Code; got != http.StatusInternalServerError {
		t.Fatalf("below the rate: %d", got)
	}
	s.chance = func() float64 { return 0.5 }
	if got := do(s.apiHandler(), http.MethodGet, "/work", "").Code; got != http.StatusOK {
		t.Fatalf("at the rate: %d", got)
	}

	always := testServer(t, 0, 1)
	always.chance = func() float64 { return 0.999999 }
	if got := do(always.apiHandler(), http.MethodGet, "/work", "").Code; got != http.StatusInternalServerError {
		t.Fatalf("rate 1: %d", got)
	}
}

func TestWorkLatency(t *testing.T) {
	h := testServer(t, 50*time.Millisecond, 0).apiHandler()
	start := time.Now()
	rec := do(h, http.MethodGet, "/work", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("work = %d", rec.Code)
	}
	if elapsed := time.Since(start); elapsed < 50*time.Millisecond {
		t.Fatalf("returned after %s, want at least 50ms", elapsed)
	}
}

func TestAdminConfigChangesWork(t *testing.T) {
	s := testServer(t, 0, 0)
	s.chance = func() float64 { return 0 }
	admin := s.adminHandler()
	api := s.apiHandler()

	rec := do(admin, http.MethodPut, "/admin/config", `{"latency":"1ms","error_rate":1}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("put = %d: %s", rec.Code, rec.Body.String())
	}
	if got := do(api, http.MethodGet, "/work", "").Code; got != http.StatusInternalServerError {
		t.Fatalf("work after setting the rate = %d", got)
	}
	if body := do(admin, http.MethodGet, "/admin/config", "").Body.String(); !strings.Contains(body, `"error_rate":1`) {
		t.Fatalf("get = %s", body)
	}

	// A body with only one field leaves the other as it was.
	do(admin, http.MethodPut, "/admin/config", `{"error_rate":0}`)
	if got := s.settings(); got.ErrorRate != 0 || got.Latency != time.Millisecond {
		t.Fatalf("settings = %+v", got)
	}
}

func TestAdminConfigRejectsBadInput(t *testing.T) {
	s := testServer(t, 0, 0.1)
	admin := s.adminHandler()
	cases := map[string]string{
		"latency above the cap": `{"latency":"6s"}`,
		"negative latency":      `{"latency":"-1s"}`,
		"not a duration":        `{"latency":"fast"}`,
		"rate above 1":          `{"error_rate":1.5}`,
		"negative rate":         `{"error_rate":-0.1}`,
		"unknown field":         `{"speed":1}`,
		"not json":              `latency=1s`,
	}
	for name, body := range cases {
		if got := do(admin, http.MethodPut, "/admin/config", body).Code; got != http.StatusBadRequest {
			t.Errorf("%s: status %d, want 400", name, got)
		}
	}
	if got := s.settings(); got.ErrorRate != 0.1 || got.Latency != 0 {
		t.Fatalf("settings changed by a rejected request: %+v", got)
	}
}

func TestNewServerRejectsBadStartingValues(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	if _, err := newServer(10*time.Second, 0, logger); err == nil {
		t.Error("latency above the cap was accepted")
	}
	if _, err := newServer(0, 2, logger); err == nil {
		t.Error("error rate above 1 was accepted")
	}
	nan := 0.0
	nan = nan / nan
	if _, err := newServer(0, nan, logger); err == nil {
		t.Error("NaN error rate was accepted")
	}
}

func TestAPIDoesNotServeAdmin(t *testing.T) {
	s := testServer(t, 0, 0)
	if got := do(s.apiHandler(), http.MethodPut, "/admin/config", `{"error_rate":1}`).Code; got != http.StatusNotFound && got != http.StatusMethodNotAllowed {
		t.Fatalf("admin path on the API handler = %d", got)
	}
	if got := s.settings().ErrorRate; got != 0 {
		t.Fatalf("error rate changed through the API handler: %v", got)
	}
}

func TestMethodsAreRestricted(t *testing.T) {
	h := testServer(t, 0, 0).apiHandler()
	if got := do(h, http.MethodPost, "/work", "").Code; got != http.StatusMethodNotAllowed {
		t.Fatalf("POST /work = %d", got)
	}
}
