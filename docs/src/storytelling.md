# Schedule

Storytelling


## Use cases

Pick one with respect to the audience

1. [KaaS Company](kaas/storytelling.md)'s main business is to provide compute power to developers relying on Kubernetes.
2. Company has lot of services. They want to automatically balance them among teams developing different applications
3. Company want to decouple Developers from Operators. They use primaza as an interface for service binding.


## Side effects to show

1. the developer could be enabled of the permission of managing ServiceBindings in their application namespace and he could use the ServiceBinding spec to mount totally custom secrets
2. System Administrators can create Apply-All services: create a Registered Service and a Service Claim with label selector. Then whoever needs it should just add the label to their deployment and they will find credentials mounted. Examples may be, optional integration for monitoring, alerting, and so on.


## Demo


### Multi-Cluster environment Setup

Company has two clusters.
The former is called 'main' and has near to zero services or operators installed.
The latter is called 'worker' and has several operators installed, like OLM, and ACK.

Company's System Operator would like to setup a Primaza environment for the Hardcore-Developers team.
He tought about installing Primaza's Control Plane on 'main' cluster, and create a Service Namespace and an Application Namespace on 'worker'.
His plan is to give access to Hardcore-Developers team only to the application namespace and to provision for them the services they will use in the Service Namespace.

This is the architecture he designed:

<!-- Add image here -->
[!image]()

<!-- demo mc-env 5 min -->


### Services Registration

Company's System Operator knows the team is developing an application that requires the following resources:

* An AWS RDS Postgres database
* A DynamoDB with events forwarded to an SQS Queue

He decide to provision the SQS Queue manually, the Postgres database using AWS Controllers for Kubernetes (ACK), and DynamoDB leveraging on AWS' Service Catalog.

<!-- demo manual-reg -->
<!-- demo discovery -->
<!-- demo service-catalog -->

Now his job is done, he just need to tell the Hardcore-Developers they have their environment setup and to look into's Primaza's Service Catalog for service they need.


## Demo-app Provisioning

Hardcore-Developers team has it's e-commerce application they are developing for a customer.
It's fairly simple as of now: it's still in development.
It's composed of 3 different microservices, one for the front-end, one for managing orders, and one for managing the catalog.

You can select an object from the store and buy some units.
No need for payment or other complex stuff; the order will be stored and the catalog updated taking track of the total units bought for each object.

More in details, when an order is accepted, data in DynamoDB is updated and the corresponding DynamoStreams' event is fetched and placed in the SQS Queue.
The catalog microservice is constantly monitoring the SQS queue and updating its own database.

Leveraging on Primaza's Claiming and Binding functionalities, the Hardcore-Developers team can now just publish the application and claim the services they need.

As an Hardcore-Developers team member let now deploy the application and the claims we need to bind to the required services.
