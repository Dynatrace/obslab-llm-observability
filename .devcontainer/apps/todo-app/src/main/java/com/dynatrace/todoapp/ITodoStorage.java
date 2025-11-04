package com.dynatrace.todoapp;

import java.util.Arrays;

/**
 * Interface for providing a generic way of storing todos
 */
public interface ITodoStorage {

    /**
     * Add a todo
     */
    void add(TodoRecord todoRecord);

    /**
     * Get all todo recrods a TodoRecord Array.
     *
     * @return TodoRecord[]
     */
    TodoRecord[] getAll();

    boolean remove(TodoRecord todoRecord);
}
