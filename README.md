# trajan

Zero downtime continuous deployment service and client for Node.js

## Use case

You are running a small VPS that will power your SaaS app. You want to deploy frequently and without a downtime for your clients.

1. Samfelld cli pipes a `tar.gz` package of your app to the service.
1. The service deploys this app as a drone in a manifold (hello Heroku).
1. Your app sends a message to the spawning service saying it is online.
1. The service sends a **message** to its current drones to wind down.
1. The drones keep sending `503` to any requests they get and finish with their outstanding requests.
1. Meanwhile a proxy routes to one of your drones that are online in a **rotating fashion**.
1. If any drones that were told to shut it are still online, we force close them.

And that is all folks. Some extras:

* The surface API allows you to get stats on all the drones which contains information on their cpu and memory usage so you can upgrade to a better VPS when the time comes.

## Some issues

1. We are using `child_process.fork` so we get a bi-directional comms between the service and the child. Unfortunately, this means that we cannot get a nice pipe with logs coming from the child. All log-worthy traffic needs to be sent to the parent service explicitly.