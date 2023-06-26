# Test

This environment is the ephemeral one.

It only contains an Application Namespace, where we want to publish a testing version of the microservice application.
It will make use of the services discovered by the `services-test` environment.

Multiple environment like this one may be created in parallel and will balance the services in the pool created by the `services-test` environment.
