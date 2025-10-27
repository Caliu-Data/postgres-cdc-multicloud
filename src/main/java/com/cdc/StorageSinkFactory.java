// ==========================================
// FILE: src/main/java/com/cdc/StorageSinkFactory.java
// ==========================================
package com.cdc;

import com.cdc.storage.AzureStorageSink;
import com.cdc.storage.S3StorageSink;
import com.cdc.storage.GcsStorageSink;

public class StorageSinkFactory {
    public static StorageSink fromEnv() {
        String provider = System.getenv().getOrDefault("CLOUD_PROVIDER", "azure").toLowerCase();
        
        return switch (provider) {
            case "azure" -> new AzureStorageSink();
            case "aws", "s3" -> new S3StorageSink();
            case "gcp", "gcs" -> new GcsStorageSink();
            default -> throw new IllegalArgumentException("Unsupported cloud provider: " + provider);
        };
    }
}