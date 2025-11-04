package com.dynatrace.todoapp;

import java.util.ArrayList;

/**
 * Tdo Storage (in memory list that implements Interface TodoRecord Storage).
 */
public class TodoStorage implements ITodoStorage {
    private ArrayList<TodoRecord> todoStorage;

    private static TodoStorage instance = new TodoStorage();

    public static TodoStorage getInstance() {
        return instance;
    }

    private TodoStorage() {
        todoStorage = new ArrayList<>();
    }

    public void add(TodoRecord todoRecordObject) {
        todoStorage.add(todoRecordObject);
    }

    public boolean remove(TodoRecord todoRecord) {
        return todoStorage.remove(todoRecord);
    }

    public boolean remove_all() {
        return todoStorage.removeAll(todoStorage);
    }

    public TodoRecord findById(String todoRecordId) {
        for (TodoRecord record : todoStorage) {
            if (record.getId().equals(todoRecordId)) {
                return record;
            }
        }
        return null;
    }

    public TodoRecord[] getAll() {
        return todoStorage.toArray(new TodoRecord[0]);
    }
}
