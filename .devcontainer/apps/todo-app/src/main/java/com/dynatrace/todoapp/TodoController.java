package com.dynatrace.todoapp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
public class TodoController {
    private static final Logger logger = LoggerFactory.getLogger(TodoController.class);
    private TodoStorage todos = TodoStorage.getInstance();
    // Disable tracing
    //private final TracingHandler tracingHandler = new TracingHandler();

    @RequestMapping(value = "/todos", method = RequestMethod.GET)
    public TodoRecord[] getTodos() {
        return todos.getAll();
    }

    @RequestMapping(value = "/todos", method = RequestMethod.POST)
    public ResponseEntity<?> addTodo(@RequestBody TodoRecord newTodoRecord) {
        newTodoRecord.setId(UUID.randomUUID().toString());
        logger.info("Adding a new todo: {}", newTodoRecord);
        // The bug in here in is for the bughunt example
        String todoTitle = newTodoRecord.getTitle().replaceAll("[^a-zA-Z0-9\\s]+", "");
        newTodoRecord.setTitle(todoTitle);
        todos.add(newTodoRecord);
        Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }

    @RequestMapping(value = "/todos", method = RequestMethod.PUT)
    public ResponseEntity<?> updateTodo(@RequestBody TodoRecord updatingTodoRecord) {
        TodoRecord tempTodoRecord = todos.findById(updatingTodoRecord.getId());
        if (tempTodoRecord != null) {
            tempTodoRecord.setTitle(updatingTodoRecord.getTitle());
            tempTodoRecord.setCompleted(updatingTodoRecord.isCompleted());
            logger.info("Updating Todo record: {}", tempTodoRecord);
        }
        Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }
    
    @RequestMapping(value = "/todos/remove_all", method = RequestMethod.DELETE)
    public ResponseEntity<?>deleteAll() {
        logger.info("Removing all items");
        todos.remove_all();
         Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }

    @RequestMapping(value = "/todos/{todoId}", method = RequestMethod.DELETE)
    public ResponseEntity<?> deleteTodo(@PathVariable("todoId") String todoId) {
        logger.info("Removing Todo record id: {}", todoId);
        TodoRecord tempTodoRecord = todos.findById(todoId);
        if (tempTodoRecord != null) {
            logger.info("Removing Todo record: {}", tempTodoRecord);
            todos.remove(tempTodoRecord);
        }
        Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }

    
    @RequestMapping(value = "/todos/clear_completed", method = RequestMethod.DELETE)
    public ResponseEntity<?> clearCompletedTodos() throws InterruptedException {
        //tracingHandler.createChildSpansActivity();
        logger.info("Removing completed todo records");
        logger.debug("reading todoStore from database");
        logger.debug("SELECT * FROM todos WHERE status='conpleted'");
        // The bug in here in is for the bughunt example
        List<TodoRecord> todoStore = new ArrayList<>();
        logger.debug("todoStore size is {}", todoStore.size());
        for (TodoRecord todoRecord : todos.getAll()) {
            if (todoRecord.isCompleted()) {
                // The bug in here in is for the bughunt example
                if (todoStore.remove(todoRecord)) {
                    logger.info("Removing Todo record: {}", todoRecord);
                }
            }
        }
        logger.error("failed to delete completed todos");
        Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }

    @RequestMapping(value = "/todos/dup/{todoId}", method = RequestMethod.POST)
    public ResponseEntity<?> duplicateTodo(@PathVariable("todoId") String todoId) {
        logger.info("Duplicating todo: {}", todoId);
        TodoRecord tempTodoRecord = todos.findById(todoId);
        if (tempTodoRecord != null) {
            TodoRecord newTodoRecord = new TodoRecord(tempTodoRecord);
            // The bug in here in is for the bughunt example
            newTodoRecord.setId(tempTodoRecord.getTitle());
            newTodoRecord.setTitle(UUID.randomUUID().toString());
            logger.info("Duplicating todo record: {}", newTodoRecord);
            todos.add(newTodoRecord);
        }
        Map<String, String> entities = new HashMap<>();
        entities.put("status", "ok");
        return new ResponseEntity<>(entities, HttpStatus.OK);
    }
}
