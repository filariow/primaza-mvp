# Services

`CUSTOMER_NAME` wants their Application Developer to publish their simple e-commerce webapp:

![image](../../imgs/demo-app-architecture.png)

So the Service Administrator is asked to provision the following services:

* An AWS RDS DBInstance
* An SQS Queue
* A DynamoDB that sends its events via DynamoStreams and a Lambda function to the SQS Queue
