package main

import (
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: s3-deleter <bucket> <prefix>")
		os.Exit(1)
	}

	bucket := os.Args[1]
	prefix := os.Args[2]

	// Session will automatically pick up AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION from env
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	})
	if err != nil {
		fmt.Printf("Unable to create session, %v\n", err)
		os.Exit(1)
	}

	svc := s3.New(sess)

	fmt.Printf("Listing objects in bucket %q with prefix %q...\n", bucket, prefix)

	// List objects
	var objects []*s3.ObjectIdentifier
	err = svc.ListObjectsV2Pages(&s3.ListObjectsV2Input{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	}, func(page *s3.ListObjectsV2Output, lastPage bool) bool {
		for _, obj := range page.Contents {
			objects = append(objects, &s3.ObjectIdentifier{
				Key: obj.Key,
			})
		}
		return true
	})

	if err != nil {
		fmt.Printf("Unable to list objects, %v\n", err)
		os.Exit(1)
	}

	if len(objects) == 0 {
		fmt.Println("No objects found to delete.")
		return
	}

	fmt.Printf("Found %d objects. Deleting...\n", len(objects))

	// Delete objects in batches of 1000 (S3 limit)
	batchSize := 1000
	for i := 0; i < len(objects); i += batchSize {
		end := i + batchSize
		if end > len(objects) {
			end = len(objects)
		}

		batch := objects[i:end]
		_, err := svc.DeleteObjects(&s3.DeleteObjectsInput{
			Bucket: aws.String(bucket),
			Delete: &s3.Delete{
				Objects: batch,
				Quiet:   aws.Bool(true),
			},
		})
		if err != nil {
			fmt.Printf("Unable to delete batch %d-%d, %v\n", i, end, err)
			os.Exit(1)
		}
		fmt.Printf("Deleted batch %d-%d\n", i, end)
	}

	fmt.Println("Successfully deleted all objects.")
}
