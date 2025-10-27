# ==========================================
# FILE: Dockerfile
# ==========================================
# Multi-stage build for CDC microservice
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy POM first for better layer caching
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy compiled JAR from builder
COPY --from=builder /app/target/cdc-pipeline-*.jar /app/cdc-pipeline.jar

# Create volume for offset storage (optional persistence)
VOLUME /app/offsets

# Expose health check port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "/app/cdc-pipeline.jar"]