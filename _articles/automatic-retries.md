---
layout: article
title: Automatic Retires
---

Automatic retries are a powerful way to add resilience to your system with
essentially no changes to your services. In many systems, failed requests can
be retried without any negative consequences, shielding users from transient
issues.

Envoy provides a simple configuration option for retrying requests. Consider
specifics of your system as you set up retries across each route:

*Choose appropriate defaults
*Limit retry-able requests
*Consider the calling context

## Choose Appropriate Defaults

Retries are specified as part of a route definition by adding a retry_policy
field to the route_action. In the API, this would be returned from the Route
Discovery Service (RDS).

## A typical Envoy retry policy

The retry_on parameter specifies **which types of responses to retry** this
request on. 5xx is a good place to start, as it will retry all server errors.
There are more specific subsets that Envoy supports (e.g. gateway-error,
connect-failure, and refused-stream), but all of these are caught with 5xx.

By default, Envoy will set the **number of retries** to one. There’s little
downside to increasing this to three, especially for relatively short requests,
as Envoy will limit the total time spent to the overall request timeout,
including the initial request and all retries.

The *per_try_request_timeout* field sets a **timeout for each retry**. Without
this parameter, any request that times out will not be retried, since the
default is the same as the calling request’s timeout. While it’s not a big deal
to leave this out, setting it to the 99th percentile of normal latency allows
Envoy to retry requests that are taking a long time due to a failure. (Note
that this limit may be longer than the total request timeout — more on that
below.)

## Limit Retry-able Requests
Once you have your defaults in place, there are several types of calls for
which it does not make sense to retry requests.

First, **do not retry requests where retrying would change the result**, such
as non-idempotent transactions. Most frameworks for monolithic services wrap
all requests in a DB transaction, guaranteeing any failure will roll back all
state changes, allowing the caller to try again. Unfortunately, in the
microservices world, an intermediate service may not be as diligent in
unwinding partial work across several services on a failure. Even worse, the
unwinding may fail, or the caller won’t be informed of the final state. In
general, enabling retries for all read requests is safe and effective, since
most systems tend to be read-heavy. Since routes in Envoy can be specified by
HTTP method, retrying GET requests is a good place to start.

Similarly, **do not retry expensive requests**, especially if they cannot be
canceled. This is subjective, because these requests can “correctly” be
retried. The problem is that retrying them may run the system out of resources,
creating a set of cascading failures. As a general rule, don’t retry requests
where the user would be impatiently waiting for the result. User logins should
almost always be retried quickly; complex analytics calculations should fail
back to the user and let either the UI or the user retry immediately.

For complex cases, remember that any of this configuration can be overridden
with HTTP headers. It’s better to configure routes to be conservative with
their retries and allow specific calling code to request more aggressive retry
behavior.

## Consider the Calling Context

For internal service calls, it’s important to consider the restrictions imposed
on the caller as well.

Since Envoy will limit the total duration of retries, consider the relationship
between the caller’s timeout, the per-retry timeout, and the number of retries.
Specifically, don’t let the # of retries times the individual time be
significantly higher than the caller’s timeout. If the total request time is
limited to 500ms, and each upstream call is limited to 250ms, Envoy can’t make
more than 2 calls before failing the original call. This isn’t fundamentally
bad, but the 250ms timeout isn’t actually allowing a full retry on timeout.
(Sometimes failures are quick, so Envoy will be able to complete the second
request, and having a lot of retries will help.) As a starting point, lowering
the upstream timeout to 100ms will allow several calls, including the jitter
that Envoy adds between calls.

On the other hand, if the caller’s request has a high caller timeout and makes
many parallel requests (“high fan-out”), adding retries will result in
consistently poor performance. Imagine a service (with no caller timeout) that
makes 100 requests with an average of 150ms latency and a 500ms per-request
timeout. Without retries, the request will be bounded at ~500ms. With retries,
a few requests will (statistically) time out, resulting in one or more retries.
Simply adding 3 retries will cause this service to shoot from 500ms to
2,000ms — a huge slowdown, which is only compounded in a service mesh with deep
calls stacks. Make sure to add a caller timeout to any service that has
high-fanout before adding retries to its upstream calls.

## Next Steps

Finally, it is strongly recommended that you set up Global Circuit Breaking in
conjunction with automatic retries. Retrying error requests 3x can triple the
volume of error traffic, making Envoy an amplifier for a misconfigured calling
service. Global circuit breaking helps selectively shed load when this sort of
failure occurs, preventing it from cascading to multiple services.

For more detail, and advanced configuration information, read about them in the
Envoy docs.
