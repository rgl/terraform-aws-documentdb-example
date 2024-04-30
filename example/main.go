package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
	log.Printf("Hello, World!")
	dumpMachineNetworkAddresses()
	lambda.Start(handler)
}

func dumpMachineNetworkAddresses() {
	networkInterfaces, err := net.Interfaces()
	if err != nil {
		log.Printf("failed to list network interfaces: %v", err)
		return
	}
	for _, networkInterface := range networkInterfaces {
		addrs, err := networkInterface.Addrs()
		if err != nil {
			log.Printf("failed to get the network interface %s addresses: %v", networkInterface.Name, err)
			continue
		}
		for _, addr := range addrs {
			log.Printf("network interface %s address: %s", networkInterface.Name, addr.String())
		}
	}
}

func handler(ctx context.Context, event events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	client, err := connectToMongoDB(ctx)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{}, err
	}
	database := client.Database("counters")   // NB this also creates the database if it does not exist.
	collection := database.Collection("hits") // NB this also creates the collection if it does not exist.
	hitsCounter, err := incrementCounter(ctx, collection)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{}, err
	}
	data := map[string]interface{}{
		"hitsCounter": hitsCounter,
		"event":       event,
	}
	body, err := json.Marshal(data)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{}, err
	}
	return events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
		Body: string(body),
	}, nil
}

// see Connecting Programmatically to Amazon DocumentDB at https://docs.aws.amazon.com/documentdb/latest/developerguide/connect_programmatically.html#connect_programmatically-tls_enabled
func connectToMongoDB(ctx context.Context) (*mongo.Client, error) {
	connectionString := os.Getenv("EXAMPLE_DOCDB_CONNECTION_STRING")
	if connectionString == "" {
		return nil, fmt.Errorf("the EXAMPLE_DOCDB_CONNECTION_STRING environment variable is not set")
	}

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(connectionString))
	if err != nil {
		return nil, fmt.Errorf("failed to connect: %w", err)
	}

	err = client.Ping(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to ping: %w", err)
	}

	// log the existing databases and their collections.
	databaseNames, err := client.ListDatabaseNames(ctx, bson.M{})
	if err != nil {
		return nil, fmt.Errorf("failed to list databases: %w", err)
	}
	for _, databaseName := range databaseNames {
		log.Printf("mongo database: %s", databaseName)
	}
	for _, databaseName := range databaseNames {
		database := client.Database(databaseName)
		collectionNames, err := database.ListCollectionNames(ctx, bson.M{})
		if err != nil {
			return nil, fmt.Errorf("failed to list database %s collections: %w", databaseName, err)
		}
		for _, collectionName := range collectionNames {
			log.Printf("mongo database %s collection: %s", databaseName, collectionName)
		}
	}

	return client, nil
}

func incrementCounter(ctx context.Context, collection *mongo.Collection) (int, error) {
	filter := bson.M{"_id": "counter"}
	update := bson.M{"$inc": bson.M{"value": 1}}
	result := collection.FindOneAndUpdate(
		ctx,
		filter,
		update,
		options.FindOneAndUpdate().SetUpsert(true).SetReturnDocument(options.After))
	if result.Err() != nil {
		return 0, fmt.Errorf("failed to increment counter: %w", result.Err())
	}
	var counter struct {
		Value int `bson:"value"`
	}
	err := result.Decode(&counter)
	if err != nil {
		return 0, fmt.Errorf("failed to decode increment counter response: %w", result.Err())
	}
	return counter.Value, nil
}
