# Practical Circuit Breaking and Retries

Circuit breaking and automatic retries are two great features of Envoy, and
this article gives you a few examples of how to configure and use them.
Effective implentation of these tools will greatly increase your service
success rates by letting Envoy do a lot of the heavy lifting around simple
failures and issues with GET requests.

## The setup

The Envoy documentation provides a good overview of
[how to run the example](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/zipkin_tracing)

You should already have the following installed from running Envoy on your
laptop:

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://help.github.com/articles/set-up-git/)
- [curl](https://curl.haxx.se/)

Additionally, install this service to drive load to our examples:

- [wrk](https://github.com/wg/wrk)

## Configuring latency and success rate

In our first example we've add a configurable latency and success rate to the
Python service that underlies all the Envoy examples.

First, check out this tag of the example repo:

```console
$ git clone https://github.com/turbinelabs/envoy-examples/tree/step1
```

Next, start the Zipkin tracing example in the `zipkin-tracing` directory by
running:

```console
$ docker-compose up --build -d
```

Run wrk with:

```console
$ wrk -c 1 -t 1 --latency -d 5s http://localhost:8000/service/1
```

which returns, for example:

```shell
Running 5s test @ http://localhost:8000/service/1
  1 threads and 1 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    55.01ms    2.41ms  61.58ms   72.83%
    Req/Sec    17.72      3.82    20.00     84.00%
  Latency Distribution
     50%   54.84ms
     75%   56.53ms
     90%   58.25ms
     99%   61.58ms
  92 requests in 5.10s, 24.12KB read
  Non-2xx or 3xx responses: 7
Requests/sec:     18.04
Transfer/sec:      4.73KB
```

In this example, success rate for requests is less than 100%, and the latency
histogram has a median of roughly 50 ms.

## Adding a retry policy

Next, let's add a retry policy to all service requests by adding the following
to the `zipkin-tracing/front-envoy-zipkin.yml` file

```diff
                   cluster: service1
+                  retry_policy:
+                    retry_on: 5xx
+                    num_retries: 3
+                    per_try_timeout: 0.300s
                 decorator:
```

Shut down the example we ran previously by running this command in the
`zipkin-tracing` directory:

```console
$ docker-compose down --remove-orphans
```

Start your example again by running:

```console
$ docker-compose up --build -d
```

Run wrk with:

```console
$ wrk -c 1 -t 1 --latency -d 5s http://localhost:8000/service/1
```

You should see the following:

```shell
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    56.99ms   10.16ms 126.43ms   96.67%
    Req/Sec    17.18      4.17    20.00     78.00%
  Latency Distribution
     50%   54.97ms
     75%   57.91ms
     90%   60.97ms
     99%  126.43ms
  89 requests in 5.09s, 22.17KB read
Requests/sec:     17.49
Transfer/sec:      4.36KB
```

With those changes, success rate is back to 100%. Retrying the request
automatically has brought our success rate from 95% to 99.75%, and in the real
world would drastically change your user's experience.

## Excluding POST requests

Next, let's modify our retry policy to not affect POST requests. POST
request tend to modify state, and are generally unsafe to retry. By adding a new
match rule to the `zipkin-tracing/front-envoy-zipkin.yml` file we can cause
POSTs to have no retry policy, but leave the existing retry policy in place for
all other requests.

```diff
+              - match:
+                  prefix: "/"
+                  headers:
+                    - name: ":method"
+                      value: "POST"
+                route:
+                  cluster: service1
+                decorator:
+                  operation: updateAvailability
```

Shut down your example in the `zipkin-tracing` directory by running:

```console
$ docker-compose down --remove-orphans
```

Start your example again by running:

```console
$ docker-compose up --build -d
```

Run wrk with:

```console
$ wrk -c 1 -t 1 --latency -d 5s http://localhost:8000/service/1
```

Now, you should see results like:

```shell
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    56.99ms   10.16ms 126.43ms   96.67%
    Req/Sec    17.18      4.17    20.00     78.00%
  Latency Distribution
     50%   54.97ms
     75%   57.91ms
     90%   60.97ms
     99%  126.43ms
  89 requests in 5.09s, 22.17KB read
Requests/sec:     17.49
Transfer/sec:      4.36KB
```

With our new changes, success rate for GET requests is still 100%. However if
you run curl in a loop like the following

```console
$ for i in `seq 1 100`; do \
     curl -XPOST -v -q --stderr - localhost:8000/service/1 \
     | grep '< HTTP'; \
  done | sort | uniq -c
```

You should see some failures.

```shell
97 < HTTP/1.1 200 OK
3 < HTTP/1.1 503 Service Unavailable
```

This is good! Our retry policy doesn't affect POST requests, only GETs, so our
goal was achieved.

## Circuit breaking

Next, we'll add load shedding capabilities to our configuration by setting a
few new variables and changing our service a bit:

```console
$ git clone https://github.com/turbinelabs/envoy-examples/tree/step1
```

Until now we've been running `wrk` with a single thread a concurrency level of
one. This matches up well with our python service, which is single threaded.
Let's try upping the thread count to ten and the concurrency level to ten by
running

```console
wrk -c 10 -t 10 --latency -d 5s http://localhost:8000/service/1
```

```shell
Running 5s test @ http://localhost:8000/service/1
  10 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   471.00ms  345.43ms   1.47s    80.60%
    Req/Sec     2.72      1.12     9.00     86.84%
  Latency Distribution
     50%  310.00ms
     75%  311.54ms
     90%    1.00s
     99%    1.46s
  114 requests in 5.04s, 17.54KB read
  Non-2xx or 3xx responses: 110
Requests/sec:     22.62
Transfer/sec:      3.48KB
```

Our output here is pretty grim. We made 114 requests, and all but 4 of them
failed. In addition, our 99th percentile latency has jumped to 1.46 seconds, and
the median is up to 310 ms. We're not only failing a lot of requests, we're
taking a long time to do so. In addition, imagine that all our POST requests are
important (e.g. they're used to make a purchase). In this case those POST
requests have to wait behind a flood of GET requests, and the vast majority will
fail.

Envoy provides circuit breakers and priority routes to manage load shedding. In
this step we've added a new service instance to our Docker Compose file, so we
can reserve at least one for high priority requests.

We've also set the priority of the route that handles POST requests to high

```diff
                       value: "POST"
                 route:
                   cluster: service1
+                  priority: HIGH
                 decorator:
                   operation: updateAvailability
               - match:
```

And we've added circuit breaker definitions to the service1 cluster


```diff
     type: strict_dns
     lb_policy: round_robin
     http2_protocol_options: {}
+    circuit_breakers:
+      thresholds:
+        - priority: DEFAULT
+          max_connections: 1
+          max_requests: 1
+        - priority: HIGH
+          max_connections: 2
+          max_requests: 2
     hosts:
     - socket_address:
         address: service1
         port_value: 80
+    - socket_address:
+        address: service1a
+        port_value: 80
```

Shut down your example, if needed by running

```console
docker-compose down --remove-orphans
```

in the `zipkin-tracing` directory, and then start your example again by running

```console
docker-compose up --build -d
```

Run wrk with

```console
wrk -c 10 -t 10 --latency -d 5s http://localhost:8000/service/1
```

and you should see results like

```shell
Running 5s test @ http://localhost:8000/service/1
  10 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     5.68ms   11.38ms 103.72ms   91.48%
    Req/Sec   443.27    292.13     1.68k    75.00%
  Latency Distribution
     50%    1.80ms
     75%    3.95ms
     90%   13.41ms
     99%   57.06ms
  22122 requests in 5.03s, 4.58MB read
  Non-2xx or 3xx responses: 22037
Requests/sec:   4402.34
Transfer/sec:      0.91MB
```

We're still failing a lot of requests, but our latency is back down to normal
levels. Envoy is using circuit breakers to return 502s immediately instead of
waiting on the service to handle them. This leaves capacity on the servers to
handle high priority requests. If you attempt a POST request while running work
it will succeed.


## Wrap-up

By using the examples in this guide, we now have a better understanding of how
Envoy's automatic retries and circuit breaking can ensure that your services
respond to simple failures gracefully by using these robust tools. 
