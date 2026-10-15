FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/quarkus-app/ /app/
USER nobody
EXPOSE 8080
CMD ["java", "-jar", "/app/quarkus-run.jar"]
