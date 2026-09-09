package com.medimanage.feature.user;

public enum UserRole {
    admin, staff, assistant, doctor, nurse, receptionist;

    public boolean canWrite() {
        return this == admin;
    }

    /** Staff can create/update patient personal records but not clinical data. */
    public boolean canEditPatient() {
        return this == admin || this == staff;
    }
}
