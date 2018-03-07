# Routing Basics

Now that you've configured
[Envoy on your laptop](on-your-laptop.html)
and understand the basics of using Envoy, there are a few routing exercises you can explore.

## The setup

The Envoy documentation provides a good overview of
[how to run the example](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/zipkin_tracing)

You should already have the following installed from running Envoy on your laptop:

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://help.github.com/articles/set-up-git/)
- [curl](https://curl.haxx.se/)

Additionally, install this service to drive load to our examples:

- [wrk](https://github.com/wg/wrk)

and checkout the example files by cloning our example repo:

`git clone git@github.com:turbinelabs/envoy-examples.git`

and checking out our routing steps:

`git checkout step5`

## Routing to a new version of a service

In this example we've created a second cluster to represent a new version of our
service. This change is visible in this
[yaml file for Zipkin](https://github.com/turbinelabs/envoy-examples/blob/step5/zipkin-tracing/front-envoy-zipkin.yaml) illustrated here:

```yaml
     - socket_address:
         address: service1
         port_value: 80
+  - name: service1a
+    connect_timeout: 0.250s
+    type: strict_dns
+    lb_policy: round_robin
+    http2_protocol_options: {}
+    circuit_breakers:
+      thresholds:
+        - priority: DEFAULT
+          max_connections: 1
+          max_requests: 1
+        - priority: HIGH
+          max_connections: 2
+          max_requests: 2
+    hosts:
     - socket_address:
         address: service1a
         port_value: 80
```

Next we've added routing rule in the same file that lets us test the new version of that service by including an HTTP header:

```yaml
                   priority: HIGH
                 decorator:
                   operation: updateAvailability
+              - match:
+                  prefix: "/"
+                  headers:
+                    - name: "x-canary-version"
+                      value: "service1a"
+                route:
+                  cluster: service1a
+                  retry_policy:
+                    retry_on: 5xx
+                    num_retries: 3
+                    per_try_timeout: 0.300s
               - match:
                   prefix: "/"
                 route:
```

Our header rule says that if a header with `x-canary-version` and a value of
`service1a` is present, route the request to our new service. If that header is
absent, requests will continue to route to our original service.

If you've previously run the Envoy Zipkin examples, you may need to shut down
those containers with this command in the `zipkin-tracing` directory:

`docker-compose down --remove-orphans`

Start your example again in the `zipkin-tracing` directory by running this
command

`docker-compose up --build -d`

If we make a request to our service with no headers, you'll get a response from
service 1.

```console
> curl localhost:8000/service/1
Hello from behind Envoy (service 1)! hostname: d0adee810fc4 resolvedhostname: 172.18.0.2
```

However if we include the `x-canary-version` header, Envoy will route our
request to service 1a.

```console
> curl -H 'x-canary-version: service1a' localhost:8000/service/1
Hello from behind Envoy (service 1a)! hostname: 569ee89eebc8 resolvedhostname: 172.18.0.6
```

This is a powerful feature. It allows you to
[separate the deploy and release phases](https://blog.turbinelabs.io/deploy-not-equal-release-part-one-4724bc1e726b)
of your application, paving the way for canary releases and
[testing in production](https://opensource.com/article/17/8/testing-production).

## Incremental releases

This example exercise will show how Envoy handles incremental release routing.

To get started, checkout new example files with:

`git checkout step6`.

First, you'll notice that we've added a new match rule to our Zipkin yaml file
that activates only 25% of the time. The `runtime` object in the route match
tells Envoy to roll a 100 sided die, and if the result is less than the value
of the runtime key (we default it to 25 here), then activate the match. By
routing to a different cluster in this match, we can send a percentage of
traffic to our new version.

```yaml
                     retry_on: 5xx
                     num_retries: 3
                     per_try_timeout: 0.300s
+              - match:
+                  prefix: "/"
+                  runtime:
+                    default_value: 25
+                    runtime_key: routing.traffic_shift.helloworld
+                route:
+                  cluster: service1a
+                  retry_policy:
+                    retry_on: 5xx
+                    num_retries: 3
+                    per_try_timeout: 0.300s
               - match:
                   prefix: "/"
                 route:
```

Shut down your previous example services in the `zipkin-tracing` directory, by
running:

`docker-compose down --remove-orphans`

Start your new example services by running

`docker-compose up --build -d`

Now if we make a request to our service with no headers we should see responses
from service 1a about 25% of the time.

## Wrap-up

Now that you've seen a few examples of incremental and header-based routing
using Envoy, you may want to investigate
[automatic retries](automatic-retries.html)
or learn how to
[dynamically configure routing](https://www.learnenvoy.io/articles/routing-configuration.html)
