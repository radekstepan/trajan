# trajan

Zero downtime continuous deployment service and client for Node.js

## Use case

You are running a small VPS that will power your SaaS app. You want to deploy frequently and without a downtime for your clients.

1. `trajan` client pipes a `tar.gz` package of your app to the service.
1. The service deploys this app as a drone in a manifold (hello Heroku).
1. Your app sends a message to the spawning service saying it is online.
1. The service sends a message to its current drones to wind down.
1. The drones keep sending `503` to any requests they get and finish with their outstanding requests.
1. Meanwhile a proxy routes to one of your drones that are online in a rotating fashion.
1. If any drones that were told to shut it are still online, we force close them.

And that is all folks. Some extras:

* The surface API allows you to get stats on all the drones which contains information on their cpu and memory usage so you can upgrade to a better VPS when the time comes.

## Commands

### Service

Edit the `config.json` file with the following settings:

* `proxy_port`: where should all the app requests be made to
* `deploy_port`: where does the service live
* `auth_token`: API token to use when deploying into the service
* `apps_dir`: directory with deployed dynos
* `temp_dir`: directory where newly arrived packages live
* `dyno_count`: on deploy how many dyno instances to spawn

Then start the service like so:

```bash
$ ./bin/trajan
```

### Client

To deploy an app on localhost (default port):

```bash
./bin/trajan-cli deploy 127.0.0.1 test/example-app/
```

To get a JSON response with stats on all dynos:

```bash
./bin/trajan-cli dynos 127.0.0.1
```

To save an authentication token for a service in `.trajan` file:

```bash
./bin/trajan-cli auth 127.0.0.1 supersecret
```

To pass an environment variable to be saved and used on next dyno spawn:

```bash
./bin/trajan-cli env 127.0.0.1 test/example-app/ PORT=3000
```

## Some issues

1. We are using `child_process.fork` so we get a bi-directional comms between the service and the child. Unfortunately, this means that we cannot get a nice pipe with logs coming from the child. All log-worthy traffic needs to be sent to the parent service explicitly.
1. Test coverage is low.