package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"math/rand/v2"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

// MaxLatency is the largest latency that can be set.
const MaxLatency = 5 * time.Second

type settings struct {
	Latency   time.Duration
	ErrorRate float64
}

func (s settings) validate() error {
	if s.Latency < 0 || s.Latency > MaxLatency {
		return fmt.Errorf("latency must be between 0 and %s", MaxLatency)
	}
	if math.IsNaN(s.ErrorRate) || s.ErrorRate < 0 || s.ErrorRate > 1 {
		return fmt.Errorf("error_rate must be between 0 and 1")
	}
	return nil
}

type server struct {
	mu     sync.RWMutex
	cur    settings
	ready  atomic.Bool
	chance func() float64
	logger *slog.Logger
}

func newServer(latency time.Duration, errorRate float64, logger *slog.Logger) (*server, error) {
	cur := settings{Latency: latency, ErrorRate: errorRate}
	if err := cur.validate(); err != nil {
		return nil, err
	}
	s := &server{cur: cur, chance: rand.Float64, logger: logger}
	s.ready.Store(true)
	return s, nil
}

func (s *server) setReady(v bool) { s.ready.Store(v) }

func (s *server) settings() settings {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.cur
}

// apiHandler serves the endpoints that the ingress and the probes reach.
func (s *server) apiHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if !s.ready.Load() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready\n"))
	})
	mux.HandleFunc("GET /work", s.work)
	return mux
}

// adminHandler serves the settings. It listens on its own port, which the
// Service does not expose.
func (s *server) adminHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /admin/config", func(w http.ResponseWriter, _ *http.Request) {
		writeSettings(w, s.settings())
	})
	mux.HandleFunc("PUT /admin/config", s.putConfig)
	return mux
}

func (s *server) work(w http.ResponseWriter, r *http.Request) {
	cur := s.settings()
	if cur.Latency > 0 {
		timer := time.NewTimer(cur.Latency)
		defer timer.Stop()
		select {
		case <-timer.C:
		case <-r.Context().Done():
			return
		}
	}
	w.Header().Set("Content-Type", "application/json")
	if cur.ErrorRate > 0 && s.chance() < cur.ErrorRate {
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "error"})
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok", "latency_ms": cur.Latency.Milliseconds()})
}

type configBody struct {
	Latency   *string  `json:"latency"`
	ErrorRate *float64 `json:"error_rate"`
}

func (s *server) putConfig(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<10)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	var body configBody
	if err := dec.Decode(&body); err != nil {
		http.Error(w, "invalid body: "+err.Error(), http.StatusBadRequest)
		return
	}

	s.mu.Lock()
	next := s.cur
	if body.Latency != nil {
		d, err := time.ParseDuration(*body.Latency)
		if err != nil {
			s.mu.Unlock()
			http.Error(w, "invalid latency: "+err.Error(), http.StatusBadRequest)
			return
		}
		next.Latency = d
	}
	if body.ErrorRate != nil {
		next.ErrorRate = *body.ErrorRate
	}
	if err := next.validate(); err != nil {
		s.mu.Unlock()
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	s.cur = next
	s.mu.Unlock()

	s.logger.Info("settings changed", "latency", next.Latency.String(), "error_rate", next.ErrorRate)
	writeSettings(w, next)
}

func writeSettings(w http.ResponseWriter, v settings) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"latency": v.Latency.String(), "error_rate": v.ErrorRate})
}
