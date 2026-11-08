// Command sample-service is the workload that the platform's SLOs measure.
// It answers health checks and a work endpoint whose latency and error rate
// can be changed at run time through a separate admin port.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	// Tracing is off unless OTEL_EXPORTER_OTLP_ENDPOINT is set. A failure to
	// set it up does not stop the service.
	shutdownTracing, err := initTracing(context.Background())
	if err != nil {
		logger.Error("tracing is off", "error", err)
	}

	latency, err := parseDuration(os.Getenv("LATENCY"), 0)
	if err != nil {
		logger.Error("invalid LATENCY", "error", err)
		os.Exit(2)
	}
	errorRate, err := parseRate(os.Getenv("ERROR_RATE"), 0)
	if err != nil {
		logger.Error("invalid ERROR_RATE", "error", err)
		os.Exit(2)
	}

	s, err := newServer(latency, errorRate, logger)
	if err != nil {
		logger.Error("invalid settings", "error", err)
		os.Exit(2)
	}

	api := &http.Server{
		Addr:              ":" + envOr("PORT", "8080"),
		Handler:           s.apiHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	admin := &http.Server{
		Addr:              ":" + envOr("ADMIN_PORT", "8081"),
		Handler:           s.adminHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	failed := make(chan error, 2)
	for _, srv := range []*http.Server{api, admin} {
		go func() {
			logger.Info("listening", "addr", srv.Addr)
			if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				failed <- err
			}
		}()
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	select {
	case sig := <-stop:
		logger.Info("shutting down", "signal", sig.String())
	case err := <-failed:
		logger.Error("server failed", "error", err)
		os.Exit(1)
	}

	// Report not ready first, so the load balancer stops sending requests.
	s.setReady(false)
	grace, _ := parseDuration(os.Getenv("SHUTDOWN_DELAY"), 0)
	time.Sleep(grace)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for _, srv := range []*http.Server{api, admin} {
		if err := srv.Shutdown(ctx); err != nil {
			logger.Error("shutdown", "error", err)
		}
	}

	// Flush the spans that are still queued.
	traceCtx, traceCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer traceCancel()
	if err := shutdownTracing(traceCtx); err != nil {
		logger.Error("tracing shutdown", "error", err)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDuration(v string, fallback time.Duration) (time.Duration, error) {
	if v == "" {
		return fallback, nil
	}
	return time.ParseDuration(v)
}

func parseRate(v string, fallback float64) (float64, error) {
	if v == "" {
		return fallback, nil
	}
	return strconv.ParseFloat(v, 64)
}
