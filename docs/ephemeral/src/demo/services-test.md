# Services-Test


The `services-test` is an auxiliary environment used to discover services for ephemeral `test` environments.

This environment only contains a Service Namespace where we configured the Discovery.

The services discovered by the discovery mechanism in this namespace creates a pool of services that can be used by the ephemeral testing environment, like `test`.
