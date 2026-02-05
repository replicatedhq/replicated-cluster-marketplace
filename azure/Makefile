APPLICATION =
CHANNEL =
IMAGE_ID =

.PHONY: build
build: check-vars clean
	mkdir ./dist
	az bicep build --outfile ./dist/mainTemplate.json --file ./modules/cluster.bicep
	jq '.parameters.application.defaultValue="$(APPLICATION)" | .parameters.releaseChannel.defaultValue="$(CHANNEL)" | .parameters.imageReference.defaultValue.id="$(IMAGE_ID)"' ./dist/mainTemplate.json > ./dist/mainTemplate.json.tmp
	mv ./dist/mainTemplate.json.tmp ./dist/mainTemplate.json
	cp ./createUiDefinition.json dist/createUiDefinition.json

.PHONY: clean
clean:
	rm -rf ./dist

.PHONY: package
package: build
	cd dist && zip "$(APPLICATION)-$(CHANNEL).zip" mainTemplate.json createUiDefinition.json

.PHONY: check-vars
check-vars:
ifeq ($(APPLICATION),)
	@echo "APPLICATION must be set" && exit 1
endif
ifeq ($(CHANNEL),)
	@echo "CHANNEL must be set" && exit 1
endif
ifeq ($(IMAGE_ID),)
	@echo "IMAGE_ID must be set" && exit 1
endif
