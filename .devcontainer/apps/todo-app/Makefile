PUBLISH_VERSION=$(shell echo ${NEW_VERSION} | sed 's/inner-999/1/g')

GIT_COMMIT=$(shell git rev-parse HEAD)
GIT_ORIGIN=$(shell git config --get remote.origin.url)

build-jar-with-docker:
	#FIXME:PUBLISH_VERSION is empty
	#echo this is the GIT_COMMIT ${GIT_COMMIT}
	rm -rf build
	# Build the build/libs/tutorial-V.V.V - which already includes the project sources in the jar
	docker run --rm -v "$(shell pwd)":/home/gradle/project -w /home/gradle/project gradle:4.10.0-jdk8-alpine gradle -i bootJar

build-jar-local:
	# Build the build/libs/tutorial-V.V.V - which already includes the project sources in the jar
	gradle -i bootJar

run-local:
	# Run the app locally
	java -jar build/libs/todoapp-1.0.0.jar

build-img:
	#build with no arguments
	#docker build --tag shinojosa/todoapp:latest --tag shinojosa/todoapp:${PUBLISH_VERSION} --build-arg GIT_COMMIT=${GIT_COMMIT} --build-arg GIT_ORIGIN=${GIT_ORIGIN} .
	docker build --tag shinojosa/todoapp:latest --tag shinojosa/todoapp:1.0.0 .

build-amd:
	docker build --platform linux/amd64 -t shinojosa/todoapp:1.0.0 .

build-arm:
	docker build --platform linux/arm64 -t shinojosa/todoapp:1.0.0-arm .

upload-no-latest:
	docker push shinojosa/tutorial-java:${PUBLISH_VERSION}

upload: upload-no-latest
	@if [ ${CIRCLE_BRANCH} = "master" ]; then \
		docker push rookout/tutorial-java:latest; \
	fi

build-and-upload: build-img upload
