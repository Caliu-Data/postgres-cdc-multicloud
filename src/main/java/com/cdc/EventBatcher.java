
// ==========================================
// FILE: src/main/java/com/cdc/EventBatcher.java
// ==========================================
package com.cdc;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class EventBatcher {
    private static final Logger log = LoggerFactory.getLogger(EventBatcher.class);
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter HOUR_FORMAT = DateTimeFormatter.ofPattern("HH");

    private final StorageSink sink;
    private final Duration maxAge;
    private final int maxBytes;
    private final ConcurrentHashMap<String, TableBatch> batches;
    private final ScheduledExecutorService scheduler;

    public EventBatcher(StorageSink sink, Duration maxAge, int maxBytes) {
        this.sink = sink;
        this.maxAge = maxAge;
        this.maxBytes = maxBytes;
        this.batches = new ConcurrentHashMap<>();
        this.scheduler = Executors.newScheduledThreadPool(1);
        
        // Schedule periodic flush
        scheduler.scheduleAtFixedRate(this::flushAll, 
            maxAge.getSeconds(), maxAge.getSeconds(), TimeUnit.SECONDS);
    }

    public void add(String topic, String eventJson) {
        TableBatch batch = batches.computeIfAbsent(topic, k -> new TableBatch(topic));
        batch.add(eventJson);
        
        // Check if batch should be flushed
        if (batch.shouldFlush(maxBytes)) {
            flush(topic, batch);
        }
    }

    private void flush(String topic, TableBatch batch) {
        List<String> events = batch.getAndReset();
        if (events.isEmpty()) {
            return;
        }

        try {
            Instant now = Instant.now();
            String date = DATE_FORMAT.format(now.atZone(ZoneOffset.UTC));
            String hour = HOUR_FORMAT.format(now.atZone(ZoneOffset.UTC));
            String filename = String.format("part-%d.ndjson", now.toEpochMilli());
            
            String path = String.format("%s/date=%s/hour=%s/%s", topic, date, hour, filename);
            
            StringBuilder content = new StringBuilder();
            for (String event : events) {
                content.append(event).append("\n");
            }
            
            sink.write(path, content.toString());
            log.info("Flushed {} events to {}", events.size(), path);
        } catch (IOException e) {
            log.error("Failed to flush batch for topic {}", topic, e);
            // Re-add events to batch for retry
            batch.addAll(events);
        }
    }

    private void flushAll() {
        batches.forEach(this::flush);
    }

    public void close() {
        log.info("Closing event batcher");
        flushAll();
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(30, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }

    private static class TableBatch {
        private final String topic;
        private final List<String> events;
        private final Instant createdAt;
        private int estimatedBytes;

        TableBatch(String topic) {
            this.topic = topic;
            this.events = new ArrayList<>();
            this.createdAt = Instant.now();
            this.estimatedBytes = 0;
        }

        synchronized void add(String event) {
            events.add(event);
            estimatedBytes += event.length();
        }

        synchronized void addAll(List<String> events) {
            this.events.addAll(events);
            estimatedBytes += events.stream().mapToInt(String::length).sum();
        }

        synchronized boolean shouldFlush(int maxBytes) {
            return estimatedBytes >= maxBytes;
        }

        synchronized List<String> getAndReset() {
            List<String> copy = new ArrayList<>(events);
            events.clear();
            estimatedBytes = 0;
            return copy;
        }
    }
}
