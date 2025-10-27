// ==========================================
// FILE: src/main/java/com/cdc/storage/S3StorageSink.java
// ==========================================
package com.cdc.storage;

import com.cdc.StorageSink;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class S3StorageSink implements StorageSink {
    private static final Logger log = LoggerFactory.getLogger(S3StorageSink.class);
    private final S3Client s3Client;
    private final String bucketName;

    public S3StorageSink() {
        this.bucketName = System.getenv("S3_BUCKET");
        String regionStr = System.getenv().getOrDefault("AWS_REGION", "us-east-1");
        
        if (bucketName == null || bucketName.isEmpty()) {
            throw new IllegalArgumentException("S3_BUCKET environment variable is required");
        }

        log.info("Initializing S3 Storage: bucket={}, region={}", bucketName, regionStr);

        this.s3Client = S3Client.builder()
            .region(Region.of(regionStr))
            .build();
    }

    @Override
    public void write(String path, String content) throws IOException {
        try {
            byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
            
            PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(path)
                .contentType("application/x-ndjson")
                .build();

            s3Client.putObject(putRequest, RequestBody.fromBytes(bytes));
            
            log.debug("Wrote {} bytes to S3: s3://{}/{}", bytes.length, bucketName, path);
        } catch (Exception e) {
            throw new IOException("Failed to write to S3: " + path, e);
        }
    }
}

