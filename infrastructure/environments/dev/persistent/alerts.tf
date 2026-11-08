# Burn-rate alerts for the two SLOs in docs/slos.md (ADR 0028).
#
# Error budget: availability 0.01 (99% target), latency 0.05 (95% target).
# Burn rate 14.4 is the fast alert and burn rate 6 is the slow alert.
# Each alert needs both its long window and its short window to be over the threshold.
# Each expression is self-contained. The thresholds are literal numbers.
#
# Latency: a request is slow when it takes longer than 0.5 seconds. The bucket label value is "0.5".
resource "azurerm_monitor_alert_prometheus_rule_group" "slo" {
  name                = "pp-${var.env}-slo-alerts"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  scopes              = [azurerm_monitor_workspace.main.id]
  interval            = "PT1M"
  rule_group_enabled  = true
  description         = "Burn-rate alerts for the availability and latency SLOs of the sample service."
  tags                = local.tags

  # 14.4 x 0.01 = 0.144
  rule {
    alert    = "AvailabilityFastBurn"
    for      = "PT2M"
    severity = 1
    enabled  = true

    expression = <<-EOT
      (
        sum(rate(http_requests_total{route="/work", code=~"5.."}[15m]))
        / sum(rate(http_requests_total{route="/work"}[15m])) > 0.144
      )
      and
      (
        sum(rate(http_requests_total{route="/work", code=~"5.."}[5m]))
        / sum(rate(http_requests_total{route="/work"}[5m])) > 0.144
      )
    EOT

    labels = {
      slo  = "availability"
      burn = "fast"
    }

    annotations = {
      summary     = "Availability budget is burning fast"
      description = "More than 14.4 percent of /work requests returned a 5xx code over both 15 minutes and 5 minutes. At this rate the 30 day error budget is used up in about two days."
    }

    action {
      action_group_id = azurerm_monitor_action_group.main.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }
  }

  # 6 x 0.01 = 0.06
  rule {
    alert    = "AvailabilitySlowBurn"
    for      = "PT5M"
    severity = 2
    enabled  = true

    expression = <<-EOT
      (
        sum(rate(http_requests_total{route="/work", code=~"5.."}[1h]))
        / sum(rate(http_requests_total{route="/work"}[1h])) > 0.06
      )
      and
      (
        sum(rate(http_requests_total{route="/work", code=~"5.."}[15m]))
        / sum(rate(http_requests_total{route="/work"}[15m])) > 0.06
      )
    EOT

    labels = {
      slo  = "availability"
      burn = "slow"
    }

    annotations = {
      summary     = "Availability budget is burning"
      description = "More than 6 percent of /work requests returned a 5xx code over both 1 hour and 15 minutes. At this rate the 30 day error budget is used up in about five days."
    }

    action {
      action_group_id = azurerm_monitor_action_group.main.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }
  }

  # 14.4 x 0.05 = 0.72
  rule {
    alert    = "LatencyFastBurn"
    for      = "PT2M"
    severity = 1
    enabled  = true

    expression = <<-EOT
      (
        1 - sum(rate(http_request_duration_seconds_bucket{route="/work", le="0.5"}[15m]))
        / sum(rate(http_request_duration_seconds_count{route="/work"}[15m])) > 0.72
      )
      and
      (
        1 - sum(rate(http_request_duration_seconds_bucket{route="/work", le="0.5"}[5m]))
        / sum(rate(http_request_duration_seconds_count{route="/work"}[5m])) > 0.72
      )
    EOT

    labels = {
      slo  = "latency"
      burn = "fast"
    }

    annotations = {
      summary     = "Latency budget is burning fast"
      description = "More than 72 percent of /work requests took longer than 0.5 seconds over both 15 minutes and 5 minutes. At this rate the 30 day error budget is used up in about two days."
    }

    action {
      action_group_id = azurerm_monitor_action_group.main.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }
  }

  # 6 x 0.05 = 0.30
  rule {
    alert    = "LatencySlowBurn"
    for      = "PT5M"
    severity = 2
    enabled  = true

    expression = <<-EOT
      (
        1 - sum(rate(http_request_duration_seconds_bucket{route="/work", le="0.5"}[1h]))
        / sum(rate(http_request_duration_seconds_count{route="/work"}[1h])) > 0.30
      )
      and
      (
        1 - sum(rate(http_request_duration_seconds_bucket{route="/work", le="0.5"}[15m]))
        / sum(rate(http_request_duration_seconds_count{route="/work"}[15m])) > 0.30
      )
    EOT

    labels = {
      slo  = "latency"
      burn = "slow"
    }

    annotations = {
      summary     = "Latency budget is burning"
      description = "More than 30 percent of /work requests took longer than 0.5 seconds over both 1 hour and 15 minutes. At this rate the 30 day error budget is used up in about five days."
    }

    action {
      action_group_id = azurerm_monitor_action_group.main.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT10M"
    }
  }
}
