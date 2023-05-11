# Claiming

`CUSTOMER_NAME` has an e-commerce application they are developing for a customer.
It's fairly simple as of now: it's still in development.
It's composed of 3 different microservices, one for the front-end, one for managing orders, and one for managing the catalog.

You can select an object from the store and buy some units.
No need for payment or other complex stuff; the order will be stored and the catalog updated taking track of the total units bought for each object.

More in details, when an order is accepted, data in DynamoDB is updated and the corresponding DynamoStreams' event is fetched and placed in the SQS Queue.
The catalog microservice is constantly monitoring the SQS queue and updating its own database.

Leveraging on Primaza's Claiming and Binding functionalities, `CUSTOMER_NAME` can now just publish the application and claim the services they need, without any need of managing Secrets.
