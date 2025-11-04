package com.dynatrace.todoapp;

public class TodoRecord {
    private String title;
    private String id;
    private boolean completed = false;

    public TodoRecord(String inputTitle, String inputId, boolean inputCompleted) {
        this.title = inputTitle;
        this.id = inputId;
        this.completed = inputCompleted;
    }

    public TodoRecord() {

    }

    public TodoRecord(TodoRecord newTodoRecord) {
        this.title = newTodoRecord.title;
        this.id = newTodoRecord.id;
        this.completed = newTodoRecord.completed;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    @Override
    public String toString() {
        return "TodoRecord{" +
                "title='" + title + '\'' +
                ", id='" + id + '\'' +
                ", completed=" + completed +
                '}';
    }

    public boolean isCompleted() {
        return completed;
    }

    public void setCompleted(boolean completed) {
        this.completed = completed;
    }
}
