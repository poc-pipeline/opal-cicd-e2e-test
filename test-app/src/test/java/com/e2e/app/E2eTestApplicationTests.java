package com.e2e.app;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class E2eTestApplicationTests {

    @Test
    void contextLoads() {
        // Verify Spring context loads successfully
    }

    @Test
    void mainMethodTest() {
        // Verify main method runs without exception
        E2eTestApplication.main(new String[]{});
    }
}
