// ==========================================
// FILE: src/main/java/com/cdc/Main.java
// ==========================================
package com.cdc;

import io.debezium.engine.DebeziumEngine;
import io.debezium.engine.format.Json;
import io.debezium.engine.ChangeEvent;
import com.sun.net.httpserver.HttpServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.time.Duration;
import java.util.Properties;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

public class Main {
    private static final Logger log = LoggerFactory.getLogger(Main.class);
    private static final AtomicLong eventsProcessed = new AtomicLong(0);
    private static final AtomicReference<String> lastLsn = new AtomicReference<>("");
    private static final AtomicLong lastEventTime = new AtomicLong(System.currentTimeMillis());

    public static void main(String[] args) throws Exception {
        log.info("Starting PostgreSQL CDC Pipeline...");

        // Load configuration
        Properties props = loadConfiguration();
        
        // Create storage sink based on cloud provider
        StorageSink sink = StorageSinkFactory.fromEnv();
        log.info("Initialized storage sink: {}", sink.getClass().getSimpleName());

        // Create event batcher
        int batchMaxSize = Integer.parseInt(
            System.getenv().getOrDefault("BATCH_MAX_SIZE", "5000000")); // 5MB
        int batchMaxSeconds = Integer.parseInt(
            System.getenv().getOrDefault("BATCH_MAX_SECONDS", "10"));
        
        EventBatcher batcher = new EventBatcher(
            sink, 
            Duration.ofSeconds(batchMaxSeconds), 
            batchMaxSize
        );

        // Build Debezium engine
        DebeziumEngine<ChangeEvent<String, String>> engine = DebeziumEngine.create(Json.class)
            .using(props)
            .notifying(record -> {
                try {
                    batcher.add(record.topic(), record.value());
                    eventsProcessed.incrementAndGet();
                    lastEventTime.set(System.currentTimeMillis());
                    
                    // Extract LSN if available (for monitoring)
                    if (record.value() != null && record.value().contains("\"lsn\":")) {
                        // Simple extraction - in production use proper JSON parsing
                        int lsnStart = record.value().indexOf("\"lsn\":") + 7;
                        int lsnEnd = record.value().indexOf("\"", lsnStart);
                        if (lsnEnd > lsnStart) {
                            lastLsn.set(record.value().substring(lsnStart, lsnEnd));
                        }
                    }
                } catch (Exception e) {
                    log.error("Error processing record", e);
                }
            })
            .using((success, message, error) -> {
                if (!success) {
                    log.error("Engine error: {}", message, error);
                }
            })
            .build();

        // Start health check server
        startHealthCheckServer();

        // Shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            log.info("Shutting down...");
            try {
                engine.close();
                batcher.close();
                log.info("Shutdown complete");
            } catch (IOException e) {
                log.error("Error during shutdown", e);
            }
        }));

        // Run engine (blocks until shutdown)
        log.info("CDC pipeline started successfully");
        try {
            engine.run();
        } catch (Exception e) {
            log.error("Engine failed", e);
            System.exit(1);
        }
    }

    private static Properties loadConfiguration() {
        Properties props = new Properties();
        
        // Engine configuration
        props.setProperty("name", "pg-cdc-embedded");
        props.setProperty("connector.class", "io.debezium.connector.postgresql.PostgresConnector");
        props.setProperty("offset.storage", "org.apache.kafka.connect.storage.FileOffsetBackingStore");
        props.setProperty("offset.storage.file.filename", "/app/offsets/offsets.dat");
        props.setProperty("offset.flush.interval.ms", "5000");
        
        // PostgreSQL connection
        props.setProperty("topic.prefix", getEnv("TOPIC_PREFIX", "cdc"));
        props.setProperty("database.hostname", getEnv("PG_HOST", "localhost"));
        props.setProperty("database.port", getEnv("PG_PORT", "5432"));
        props.setProperty("database.user", getEnv("PG_USER", "postgres"));
        props.setProperty("database.password", getEnv("PG_PASSWORD", ""));
        props.setProperty("database.dbname", getEnv("PG_DB", "postgres"));
        
        // CDC configuration
        props.setProperty("plugin.name", "pgoutput");
        props.setProperty("publication.name", getEnv("PG_PUBLICATION", "cdc_pub"));
        props.setProperty("slot.name", getEnv("PG_SLOT", "cdc_slot"));
        
        // Snapshot mode
        props.setProperty("snapshot.mode", getEnv("SNAPSHOT_MODE", "initial"));
        
        // Table selection
        String tableInclude = getEnv("TABLE_INCLUDE", "");
        if (!tableInclude.isEmpty()) {
            props.setProperty("table.include.list", tableInclude);
        }
        
        // Schema changes
        props.setProperty("include.schema.changes", "true");
        
        // Tombstones for deletes
        props.setProperty("tombstones.on.delete", "false");
        
        log.info("Configuration loaded: host={}, db={}, publication={}, slot={}", 
            props.getProperty("database.hostname"),
            props.getProperty("database.dbname"),
            props.getProperty("publication.name"),
            props.getProperty("slot.name")
        );
        
        return props;
    }

    private static String getEnv(String key, String defaultValue) {
        String value = System.getenv(key);
        return (value != null && !value.isEmpty()) ? value : defaultValue;
    }

    private static void startHealthCheckServer() {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
            server.createContext("/health", exchange -> {
                long lagSeconds = (System.currentTimeMillis() - lastEventTime.get()) / 1000;
                String response = String.format(
                    "{\"status\":\"healthy\",\"eventsProcessed\":%d,\"lastLsn\":\"%s\",\"lagSeconds\":%d}",
                    eventsProcessed.get(),
                    lastLsn.get(),
                    lagSeconds
                );
                exchange.sendResponseHeaders(200, response.length());
                OutputStream os = exchange.getResponseBody();
                os.write(response.getBytes());
                os.close();
            });
            server.setExecutor(null);
            server.start();
            log.info("Health check server started on port 8080");
        } catch (IOException e) {
            log.error("Failed to start health check server", e);
        }
    }
}