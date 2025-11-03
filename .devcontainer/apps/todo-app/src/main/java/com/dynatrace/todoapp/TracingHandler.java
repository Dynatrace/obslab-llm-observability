package com.dynatrace.todoapp;

/*
 * Disable tracing atm
 */
// import io.opentracing.Span;
// import io.opentracing.Tracer;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.ThreadLocalRandom;

public class TracingHandler {
    // Tracer tracer;

    // public TracingHandler() {
    //     tracer = io.opentracing.util.GlobalTracer.get();
    // }

    // public void createChildSpansActivity() throws InterruptedException {
    //     this.openAndCloseChildSpan("getCompletedTasks");
    //     this.openAndCloseChildSpan("deleteCompletedTasks");
    //     this.openAndCloseChildSpan("updateView");
    // }

    // public void openAndCloseChildSpan(String operationName) throws InterruptedException {
    //     Span parentSpan = tracer.scopeManager().activeSpan();
    //     Span newChildSpan = tracer.buildSpan(operationName).asChildOf(parentSpan).start();
    //     tracer.scopeManager().activate(newChildSpan);

    //     int randomNum = ThreadLocalRandom.current().nextInt(5, 20);
    //     TimeUnit.MILLISECONDS.sleep(randomNum);

    //     tracer.scopeManager().activate(parentSpan);
    //     newChildSpan.finish();
    // }

}
