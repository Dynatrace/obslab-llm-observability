FROM openjdk:8-jdk as build

RUN mkdir -p /app
WORKDIR /app
ADD build.gradle /app
ADD . /app
RUN ./gradlew -i bootJar

# ---------------------------------------------------------- #

FROM openjdk:8-jdk as release

# Update <environmentURL> below.
# environmentURL=mss33078.dev.dynatracelabs.com
# TECHNOLOGY=java
#COPY --from=<environmentURL>/linux/oneagent-codemodules:java / /
#ENV LD_PRELOAD /opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so
#ENV DT_LIVEDEBUGGER_LABELS=app:josh
#ENV DT_LIVEDEBUGGER_REMOTE_ORIGIN=ssh://git@bitbucket.lab.dynatrace.org/dobs/tutorial-java-workshop.git
#ENV DT_LIVEDEBUGGER_COMMIT=main

RUN mkdir -p /app
# Copy the jar image (which already include resoures)
COPY --from=build /app/build/libs/todoapp-1.0.0.jar  /app/todoapp-1.0.0.jar

ENTRYPOINT ["java", "-jar", "/app/todoapp-1.0.0.jar"]
