package com.medimanage.feature.user;

public enum UserRole {
    admin, assistant, doctor, nurse, receptionist;

    public boolean canWrite() {
        return this == admin;
    }
}
