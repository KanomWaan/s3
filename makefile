define get_config
$(shell jq -r '."$(1)"' makefile.json)
endef

#--------------------------------------------------------
# [CONFIGURABLE]
#--------------------------------------------------------
V_NGINX_NAME := $(call get_config,V_NGINX_NAME)
V_LOCAL_FILE_PATH := $(call get_config,V_LOCAL_FILE_PATH)
V_S3_BUCKET  := $(call get_config,V_S3_BUCKET)
V_S3_PREFIX  := $(call get_config,V_S3_PREFIX)
V_AWS_ACCESS_KEY_ID := $(call get_config,V_AWS_ACCESS_KEY_ID)
V_AWS_SECRET_ACCESS_KEY := $(call get_config,V_AWS_SECRET_ACCESS_KEY)
V_AWS_REGION := $(call get_config,V_AWS_REGION)

.PHONY: upload delete s3

#--------------------------------------------------------
# Upload file or folder to S3 (via pod aws-cli)
#--------------------------------------------------------
upload:
	@echo "Preparing to upload to S3..."; \
	if [ -z "$(V_LOCAL_FILE_PATH)" ]; then \
		echo "Error: V_LOCAL_FILE_PATH is not set in makefile.json"; \
		echo "Please specify the file or folder path you want to upload."; \
		exit 1; \
	fi; \
	SOURCE_PATH="$(V_LOCAL_FILE_PATH)"; \
	echo "Using local path: $$SOURCE_PATH"; \
	if [ ! -e "$$SOURCE_PATH" ]; then \
		echo "Error: Source path $$SOURCE_PATH does not exist"; exit 1; \
	fi; \
	if [ -d "$$SOURCE_PATH" ]; then \
		TAR_NAME=$$(basename "$$SOURCE_PATH").tar.gz; \
		echo "Compressing directory $$SOURCE_PATH to $$TAR_NAME..."; \
		tar -C "$$SOURCE_PATH" -czf "$$TAR_NAME" .; \
		FILE_TO_UPLOAD="$$TAR_NAME"; \
		IS_DIR=true; \
	else \
		FILE_TO_UPLOAD="$$SOURCE_PATH"; \
		TAR_NAME=$$(basename "$$SOURCE_PATH"); \
		IS_DIR=false; \
	fi; \
	if [ -n "$(V_S3_PREFIX)" ]; then S3_KEY="$(V_S3_PREFIX)/$$TAR_NAME"; else S3_KEY="$$TAR_NAME"; fi; \
	echo "Building s3-uploader binary..."; \
	(cd s3-uploader && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o s3-uploader main.go); \
	echo "Copying binary and data to pod $(V_NGINX_NAME)..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- mkdir -p account/tmp_upload; \
	kubectl cp s3-uploader/s3-uploader default/$(V_NGINX_NAME):account/tmp_upload/s3-uploader; \
	kubectl cp "$$FILE_TO_UPLOAD" default/$(V_NGINX_NAME):account/tmp_upload/$$TAR_NAME; \
	echo "Making binary executable..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- chmod +x account/tmp_upload/s3-uploader; \
	echo "Executing upload on pod..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- \
		env AWS_ACCESS_KEY_ID='$(V_AWS_ACCESS_KEY_ID)' \
		AWS_SECRET_ACCESS_KEY='$(V_AWS_SECRET_ACCESS_KEY)' \
		AWS_REGION='$(V_AWS_REGION)' \
		account/tmp_upload/s3-uploader "$(V_S3_BUCKET)" "$$S3_KEY" "account/tmp_upload/$$TAR_NAME"; \
	echo "Cleaning up..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- rm -rf account/tmp_upload; \
	if [ "$$IS_DIR" = "true" ]; then \
		rm -f "$$FILE_TO_UPLOAD"; \
	fi; \
	rm -f s3-uploader/s3-uploader; \
	echo "Updating V_TAR_NAME in makefile.json to $$TAR_NAME..."; \
	jq --arg v "$$TAR_NAME" '.V_TAR_NAME = $$v' makefile.json > makefile.json.tmp && mv makefile.json.tmp makefile.json; \
	echo "Upload finished."

#--------------------------------------------------------
# Delete S3 folder (prefix)
#--------------------------------------------------------
delete:
	@if [ -z "$(V_S3_PREFIX)" ]; then \
		echo "Error: V_S3_PREFIX is not set"; \
		exit 1; \
	fi
	@echo "Building s3-deleter binary..."; \
	(cd s3-deleter && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o s3-deleter main.go); \
	echo "Copying binary to pod $(V_NGINX_NAME)..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- mkdir -p account/tmp_delete; \
	kubectl cp s3-deleter/s3-deleter default/$(V_NGINX_NAME):account/tmp_delete/s3-deleter; \
	echo "Making binary executable..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- chmod +x account/tmp_delete/s3-deleter; \
	echo "Executing delete on pod..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- \
		env AWS_ACCESS_KEY_ID='$(V_AWS_ACCESS_KEY_ID)' \
		AWS_SECRET_ACCESS_KEY='$(V_AWS_SECRET_ACCESS_KEY)' \
		AWS_REGION='$(V_AWS_REGION)' \
		account/tmp_delete/s3-deleter "$(V_S3_BUCKET)" "$(V_S3_PREFIX)"; \
	echo "Cleaning up..."; \
	kubectl exec -n default $(V_NGINX_NAME) -- rm -rf account/tmp_delete; \
	rm -f s3-deleter/s3-deleter; \
	echo "Done."

s3:
	@echo "Usage: make upload | make delete"

