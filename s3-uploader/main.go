package main

import (
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Println("Usage: s3-uploader <bucket> <key> <filepath>")
		os.Exit(1)
	}

	bucket := os.Args[1]
	key := os.Args[2]
	filePath := os.Args[3]

	file, err := os.Open(filePath)
	if err != nil {
		fmt.Printf("Unable to open file %q, %v\n", filePath, err)
		os.Exit(1)
	}
	defer file.Close()

	// Session will automatically pick up AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION from env
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	})
	if err != nil {
		fmt.Printf("Unable to create session, %v\n", err)
		os.Exit(1)
	}

	uploader := s3manager.NewUploader(sess)

	_, err = uploader.Upload(&s3manager.UploadInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
		Body:   file,
	})
	if err != nil {
		fmt.Printf("Unable to upload %q to %q, %v\n", filePath, bucket, err)
		os.Exit(1)
	}

	fmt.Printf("Successfully uploaded %q to %q\n", filePath, "s3://"+bucket+"/"+key)
}
