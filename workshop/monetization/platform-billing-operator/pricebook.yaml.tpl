apiVersion: billing.opendatahub.io/v1alpha1
kind: PriceBook
metadata:
  name: pb-workshop
  namespace: connectivity-link-workshop
spec:
  currency: USD
  # Replace with a timestamp later than current time plus noticeDays.
  effectiveFrom: "REPLACE_WITH_FUTURE_UTC_TIMESTAMP"
  noticeDays: 0
  skus:
    - sku: llama-3-70b
      unit: per-1M-tokens
      rates:
        prompt_tokens: "2.50"
        completion_tokens: "10.00"
        reasoning_tokens: "10.00"
        cached_tokens: "0.625"
