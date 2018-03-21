# Practical Circuit Breaking and Retries

Circuit breaking and automatic retries are two powerful features of Envoy, and
this article gives you a few examples of how to configure and use them.

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

`$ git clone https://github.com/turbinelabs/envoy-examples/tree/step1`

Next, start the Zipkin tracing example in the `zipkin-tracing` directory by
running:

```console
$ docker-compose up --build -d
```

Run wrk with:

```
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

Run wrk with

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
$ for i in `seq 1 100`; do curl -XPOST -v -q --stderr - localhost:8000/service/1 | grep '< HTTP'; done | sort | uniq -c
```

You should see some failures.

```shell
97 < HTTP/1.1 200 OK
3 < HTTP/1.1 503 Service Unavailable
```

This is good! Our retry policy doesn't affect POST requests, only GETs
