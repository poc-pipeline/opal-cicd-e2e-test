package com.cicd.pipeline.poc.dto;

import org.springframework.http.HttpStatus;

public record ErrorResponse(String message, int errorCode, long timestamp) {


    /**
     * 400
     * @param message
     * @return
     */
    public static ErrorResponse badRequest(String message){
        var errorCode = HttpStatus.BAD_REQUEST.value();
        return new ErrorResponse(message, errorCode, System.currentTimeMillis());
    }


    /**
     * 403
     * @param message
     * @return
     */
    public static ErrorResponse forbiden(String message){
        var errorCode = HttpStatus.FORBIDDEN.value();
        return new ErrorResponse(message, errorCode, System.currentTimeMillis());
    }
    
    /**
     * 404
     * @param message
     * @return
     */
    public static ErrorResponse notFoud(String message){
        var errorCode = HttpStatus.NOT_FOUND.value();
        return new ErrorResponse(message, errorCode, System.currentTimeMillis());
    }
    
    /**
     * 500
     * @param message
     * @return
     */
    public static ErrorResponse internalError(String message){
        var errorCode = HttpStatus.INTERNAL_SERVER_ERROR.value();
        return new ErrorResponse(message, errorCode, System.currentTimeMillis());
    }

    

    /**
     * 503
     * @param message
     * @return
     */
    public static ErrorResponse serviceUnavailable(String message){
        var errorCode = HttpStatus.SERVICE_UNAVAILABLE.value();
        return new ErrorResponse(message, errorCode, System.currentTimeMillis());
    }

    

    


}
