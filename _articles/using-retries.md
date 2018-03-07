# Practical retries

Now that you've configured [Envoy on your laptop](on-your-laptop.html) and understand the basics, there are a few routing excercises and traffic control
examples you can explore.

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

## Configuring latency and success rate

In our first example we add a configurable latency and success rate to the
Python service that underlies all the Envoy examples.

First, check out the this tag of our examples:

`https://github.com/turbinelabs/envoy-examples/tree/step1`

Next, start the Zipkin tracing example by running:

`docker-compose up --build -d`

in the `zipkin-tracing` directory.

Run wrk with:

`wrk -c 1 -t 1 --latency -d 5s http://localhost:8000/service/1`

which returns, for example:

```console
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

In this example, success rate is less than 100%, and the latency histogram has a
median of roughly 50 ms.

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

Shut down the example we ran previously by running this command in the `zipkin-tracing` directory:

`docker-compose down --remove-orphans`

Start your example again by running

`docker-compose up --build -d`

Run wrk with

`wrk -c 1 -t 1 --latency -d 5s http://localhost:8000/service/1`

and you should see the following:

```console
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

As you can see, success rate is back to 100%. Retrying the request has brought
our success rate from 95% to 99.75%.

To proceed to the next step run `git checkout step3`.
