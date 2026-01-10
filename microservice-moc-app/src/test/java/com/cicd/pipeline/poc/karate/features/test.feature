Feature: Demonstrate a simple test with Karate

  Background:
    * url baseUrl

  Scenario: Obtener un Health Check.
    Given path '/api/health'
    When method get
    Then status 200
    And match response.status == 'UP'

  Scenario: Obtener información del servicio.
    Given path '/api/info'
    When method get
    Then status 200
    And match response == read('classpath:utils/responses/info.json')

  Scenario: Error 503 Service Unavailable.
    Given path '/status/unavailableservice'
    When method get
    Then status 503
    And match response.message == 'Service is not available'
    And match response == read('classpath:utils/responses/unavailableservice.json')
