// ==========================================
// FILE: src/main/java/com/cdc/storage/AzureStorageSink.java
// ==========================================
package com.cdc.storage;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.cdc.StorageSink;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class AzureStorageSink implements StorageSink {
    private static final Logger log = LoggerFactory.getLogger(AzureStorageSink.class);
    private final BlobContainerClient containerClient;

    public AzureStorageSink() {
        String accountUrl = System.getenv("AZURE_STORAGE_ACCOUNT_URL");
        String containerName = System.getenv().getOrDefault("AZURE_STORAGE_CONTAINER", "landing");
        
        if (accountUrl == null || accountUrl.isEmpty()) {
            throw new IllegalArgumentException("AZURE_STORAGE_ACCOUNT_URL environment variable is required");
        }

        log.info("Initializing Azure Storage: account={}, container={}", accountUrl, containerName);

        // Use Managed Identity for authentication
        BlobServiceClient serviceClient = new BlobServiceClientBuilder()
            .endpoint(accountUrl)
            .credential(new DefaultAzureCredentialBuilder().build())
            .buildClient();

        this.containerClient = serviceClient.getBlobContainerClient(containerName);
        
        // Create container if it doesn't exist
        if (!containerClient.exists()) {
            log.info("Creating container: {}", containerName);
            containerClient.create();
        }
    }

    @Override
    public void write(String path, String content) throws IOException {
        try {
            BlobClient blobClient = containerClient.getBlobClient(path);
            byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
            
            blobClient.upload(new ByteArrayInputStream(bytes), bytes.length, true);
            
            log.debug("Wrote {} bytes to Azure: {}", bytes.length, path);
        } catch (Exception e) {
            throw new IOException("Failed to write to Azure Storage: " + path, e);
        }
    }
}
