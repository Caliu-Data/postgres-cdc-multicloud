
// ==========================================
// FILE: src/main/java/com/cdc/storage/GcsStorageSink.java
// ==========================================
package com.cdc.storage;

import com.cdc.StorageSink;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class GcsStorageSink implements StorageSink {
    private static final Logger log = LoggerFactory.getLogger(GcsStorageSink.class);
    private final Storage storage;
    private final String bucketName;

    public GcsStorageSink() {
        this.bucketName = System.getenv("GCS_BUCKET");
        String projectId = System.getenv("GOOGLE_PROJECT_ID");
        
        if (bucketName == null || bucketName.isEmpty()) {
            throw new IllegalArgumentException("GCS_BUCKET environment variable is required");
        }

        log.info("Initializing GCS Storage: bucket={}, project={}", bucketName, projectId);

        StorageOptions.Builder builder = StorageOptions.newBuilder();
        if (projectId != null && !projectId.isEmpty()) {
            builder.setProjectId(projectId);
        }
        
        this.storage = builder.build().getService();
    }

    @Override
    public void write(String path, String content) throws IOException {
        try {
            byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
            
            BlobId blobId = BlobId.of(bucketName, path);
            BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
                .setContentType("application/x-ndjson")
                .build();

            storage.create(blobInfo, bytes);
            
            log.debug("Wrote {} bytes to GCS: gs://{}/{}", bytes.length, bucketName, path);
        } catch (Exception e) {
            throw new IOException("Failed to write to GCS: " + path, e);
        }
    }
}