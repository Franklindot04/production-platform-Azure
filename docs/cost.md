# Cost

Status: the cost after Session 1 and Session 2. Issue #52.

The amounts are the actual cost of the month so far, in EUR. They cover Session 1, Session 2 and the persistent layer.

## Budget and spend

| Item | Value |
|---|---|
| Budget of `dev` | 100.0 EUR a month, set in Azure and not defined in Terraform |
| Spend so far | 1.020 EUR |
| Share of the budget | 1.0 percent |

The three figures agree: the total by resource group, the total by service and the spend that the budget reports.

## By resource group

| Resource group | Holds | Cost (EUR) |
|---|---|---|
| `pp-dev-aks-nodes-rg` | The node resource group of the session cluster. It exists only while a session runs | 0.966 |
| `pp-dev-persistent-rg` | The persistent layer | 0.054 |
| `pp-shared-state-rg` | The state storage | under 0.001 |

All cost of the month so far is in these three resource groups.

## By service

| Service | Cost (EUR) |
|---|---|
| Virtual Machines | 0.839 |
| Storage | 0.072 |
| Virtual Network | 0.054 |
| Azure Monitor | 0.054 |
| Bandwidth | under 0.001 |
| Key Vault | under 0.001 |
| Load Balancer | 0.000 |
| Log Analytics | 0.000 |

Amounts are rounded to three decimals, and an amount under 0.0005 is written as "under 0.001". The total is rounded from the exact sum, so the rows are rounded separately from the total. The total is 1.020.

## Read the numbers again

The budget and its spend:

```bash
az consumption budget list --query "[].{name:name,amount:amount,timeGrain:timeGrain,spent:currentSpend.amount,unit:currentSpend.unit}" -o table
```

The actual cost by service and by resource group. `<start>` and `<end>` are ISO 8601 timestamps:

```bash
q() {
  az rest --method post \
    --url "https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
    --body '{
      "type": "ActualCost",
      "timeframe": "Custom",
      "timePeriod": { "from": "<start>", "to": "<end>" },
      "dataset": {
        "granularity": "None",
        "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } },
        "grouping": [ { "type": "Dimension", "name": "'"$1"'" } ]
      }
    }' \
    --query "properties.rows" -o tsv
}

q ServiceName
q ResourceGroupName
```

`az consumption usage list` returns rows without a cost for this subscription, so it is not used.

## Not covered

- The cost per hour of cluster time is not calculated.
- The alert thresholds of the budget are not read here.
- There is no forecast.
- The environments `staging` and `prod` do not exist.
