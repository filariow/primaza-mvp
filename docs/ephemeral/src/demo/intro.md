# Demo

In this demo we have already setup the following two environments:
* `prod`: is a long-term stable environment in which we have a microservice application running
* `services-test`: is an auxiliary environment used to discover services for the ephemeral `test` environment

We will create the ephemeral `test` environment that can use the services discovered by the `services-test` to run the microservice application for testing reasons.
