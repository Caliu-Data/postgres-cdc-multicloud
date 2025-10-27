// ==========================================
// FILE: src/main/java/com/cdc/StorageSink.java
// ==========================================
package com.cdc;

import java.io.IOException;

public interface StorageSink {
    void write(String path, String content) throws IOException;
}
