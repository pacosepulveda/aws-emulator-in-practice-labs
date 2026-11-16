#!/usr/bin/env node
// Lab 02 I-5 — CDK against AWS Emulator: S3 + DynamoDB + SQS (same logical architecture).
// Emulator endpoints configured per resource through each construct's props.
import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as ddb from "aws-cdk-lib/aws-dynamodb";
import * as sqs from "aws-cdk-lib/aws-sqs";

class EmulatorStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    const runId = this.node.tryGetContext("runId") || "nodevid";
    // Los endpoints del emulador los aplica el CDK/CLI vía AWS_ENDPOINT_URL
    // (exportado en cdk_app.sh); ver cdk_app.sh y results/02-iac/results.json (I-5).
    const bucket = new s3.Bucket(this, "ArtifactsBucket", {
      bucketName: `aws-emulator-lab-02-${runId}`,
      versioned: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: false,
    });

    const table = new ddb.Table(this, "StateTable", {
      tableName: `aws-emulator-lab-02-${runId}`,
      partitionKey: { name: "pk", type: ddb.AttributeType.STRING },
      billingMode: ddb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const queue = new sqs.Queue(this, "TasksQueue", {
      queueName: `aws-emulator-lab-02-${runId}`,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    new cdk.CfnOutput(this, "BucketOut", { value: bucket.bucketName });
    new cdk.CfnOutput(this, "TableOut", { value: table.tableName });
    new cdk.CfnOutput(this, "QueueOut", { value: queue.queueUrl });
  }
}

const app = new cdk.App();
new EmulatorStack(app, "aws-emulator-lab-02-cdk", {
  env: { account: "000000000000", region: "us-east-1" },
});
