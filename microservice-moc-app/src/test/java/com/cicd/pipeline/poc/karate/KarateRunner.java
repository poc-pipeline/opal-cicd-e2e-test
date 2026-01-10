package com.cicd.pipeline.poc.karate;

import com.intuit.karate.junit5.Karate;

public class KarateRunner {

  @Karate.Test
  Karate testSample() {
    return Karate.run("features/test").relativeTo(getClass());
  }
}
