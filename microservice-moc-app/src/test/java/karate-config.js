function fn() {
    var config = {};
    karate.log('Automated tests for PoC Pipeline Demo App');
    config.baseUrl = 'https://api.pocpipelinedemo.app';
    return config;
}