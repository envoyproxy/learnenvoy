---
layout: article
title: Circuit Breaking
---

[//]: # ( Copyright 2018 Turbine Labs, Inc.                                   )
[//]: # ( you may not use this file except in compliance with the License.    )
[//]: # ( You may obtain a copy of the License at                             )
[//]: # (                                                                     )
[//]: # (     http://www.apache.org/licenses/LICENSE-2.0                      )
[//]: # (                                                                     )
[//]: # ( Unless required by applicable law or agreed to in writing, software )
[//]: # ( distributed under the License is distributed on an "AS IS" BASIS,   )
[//]: # ( WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or     )
[//]: # ( implied. See the License for the specific language governing        )
[//]: # ( permissions and limitations under the License.                      )

[//]: # (Circuit Breaking)

In the world of microservices, services are often making calls to other
services. What happens when a service is busy, or unable to respond to that
call? How do you avoid a failure in one part of your infrastructure cascading
into other parts of your infrastructure? With circuit breaking.

Circuit breaking lets you configure failure thresholds that ensure safe
maximums after which these requests stop. This allows for a more graceful
failure, and time to respond to potential issues before they become larger.
It’s possible to implement circuit breaking in a few parts of your
infrastructure, but implementing these circuit breakers within services means
they are vulnerable to the same overload and failure we’re hoping to prevent.
At the network level, we can combine circuit breaking with other traffic
shifting patterns to ensure healthy and stable infrastructure.

Circuit breaking is a great feature of Envoy, as it's always better for your
services to fail quickly at the network level, and to gracefully prioritize
important requests.

## Configuring circuit breaking

Envoy provides a simple configuration option for circuit breaking. Consider the
specifics of your system as you set up circuit breaking.

Circuit breaking is specified as part of a Cluster (a group of similar upstream
hosts) definition by adding a `circuit_breakers` field. In the API, this would
be returned from the Cluster Discovery Service (CDS), either in the bootstrap
config, or in a Cluster returned by the Cluster Discovery Service (XDS).

## Circuit Breaker Configuration

Here's what a simple circuit breaking configuration looks like:

```yaml
circuit_breakers:
      thresholds:
        - priority: DEFAULT
          max_connections: 1000
          max_requests: 1000
        - priority: HIGH
          max_connections: 2000
          max_requests: 2000
```

In this example, there are a few fields that allow for a lot of service
flexibility:

 `thresholds` allows us to define priorities and limits for the type of traffic that our service responds to.

`priority` refers to how routes defined as `DEFAULT` or `HIGH` are treated by
the circuit breaker. Using the settings above, we would want to set any
requests that shouldn’t wait in a long queue to HIGH. For example: POST
requests in a service where a user wants to make a purchase, or save their
state.

`max_connections` are the maximum number of connections that Envoy will make to
our service clusters. The default for these is 1024, but in real-world
instances we may drastically lower them.

`max_requests` are the maximum number of parallel requests that Envoy makes to
our service clusters. The default is also 1024.

## Typical Circuit Breaker Policy

Essentially all clusters will benefit from a simple circuit breaker at the
network level. Because HTTP/1.1 and HTTP/2 have different connection behaviors
(one connection per request vs. many requests per connection), clusters with
different protocols will each use a different option:

 - For **HTTP/1.1** connections, use `max_connections`.
 - For **HTTP/2** connections, use `max_requests`.

In both cases, these settings will ensure the circuit breaker is tripped when
the majority of requests in the last 10 seconds have failed. A conservative
starting point for a service that does 1,000 requests / second would be 8,000
max connections / requests (80% of 10,000 requests).

This will prevent catastrophic outages based on timeout failures, where a
single service cascades everywhere. The most insidious failures happen not
because a service is down, but because it’s hanging on to requests for tens of
seconds. Generally, it’s better for one service to be completely down than for
all services to be outside their SLO because they’re waiting for a timeout deep
in the stack.

## Advanced circuit breaking

Now that you’ve seen a basic configuration and policy for circuit breaking,
we’ll discuss more advanced circuit breaking practices. These advanced
practices will add more resiliency to your infrastructure at the network level.

###  Break on latency

As mentioned above, one of the most common use cases of circuit breakers is to
prevent failures that are caused when a service is excessively slow, but not
fully down. While Envoy doesn’t directly provide an option to trip the breaker
on latency, you can combine it with [Automatic Retries](automatic-retries.html)
to emulate this behavior.

To break on an unexpected spike in slow requests, reduce the latency threshold
for retries and enable circuit break on lots of retries using the `max_retries`
option.

If you do this, monitor the results closely! Many practitioners report that
setting too low a latency threshold is the only time they’ve *created* an
outage by adding circuit breakers. When this latency threshold too low, you can
DoS your services. Start higher than you think you need, and lower it over
time.

### Configure breaking based on a long queue of retries

Even if you’re only [retrying requests](automatic-retries.html) on connection
errors, it is valuable to set up circuit breaking. Because retries has the
potential to increase the number of requests by 2x or more, circuit breaking
using the `max_retries` parameter protects services from being overloaded by
retries. Set this value to a similar number as `max_connections` or
`max_requests` — a fraction of the total number of requests the service
typically handles in a 10-second window. If the service has as many retries
outstanding as the typical number of requests, it’s broken and should be
disabled.

 ### Add fallbacks

Since circuit breakers are a way to throw errors, one of the best things your
can do for user experience is to add a secondary code path to your services
that tries to recover from those errors. This is similar to try/catch blocks in
code, except at a system level: what should a caller do when the service it
called is down?

Use this pattern when a service returns data that could be stale or incomplete,
such as shopping recommendations or a daily top 10 list. The backup path could
be a cached version, or it could be a simple version that the caller computes
locally.

Make sure to treat these fallback paths with the same engineering discipline
that you would any other piece of functionality. Exercising them via chaos
engineering or other controlled failure is crucial; otherwise, they could make
failures worse instead of better.

### Consider adding client checks

Circuit breaking is a design that allows for graceful response to failures and
downstream pressure. Even if the service is healthy enough that the global
breaker doesn’t open, it’s possible that a particular client consumes its own
thread pool, which leads to timeouts in the client. Consider combining this
with a client-side breaker library, like
[Netflix’ Hystrix](https://github.com/Netflix/Hystrix)

## Next Steps

With circuit breaking configured, your service is equipped to help selectively
shed load when failure occurs, preventing it from cascading to multiple
services. Combining this tool with
[automatic retries](automatic-retries.html)
makes for robust services that are able to handle common issues at the network
level.
