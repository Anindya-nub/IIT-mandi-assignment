-- schema.sql
-- PostgreSQL-compatible schema for the normalized university database.

DROP TABLE IF EXISTS Enrollments CASCADE;
DROP TABLE IF EXISTS Courses CASCADE;
DROP TABLE IF EXISTS Students CASCADE;
DROP TABLE IF EXISTS Instructors CASCADE;
DROP TABLE IF EXISTS Advisors CASCADE;

CREATE TABLE Advisors (
    advisor_id INT PRIMARY KEY,
    advisor_name VARCHAR(100) NOT NULL UNIQUE,
    advisor_email VARCHAR(120) NOT NULL UNIQUE,
    CHECK (advisor_email LIKE '%_@_%._%')
);

CREATE TABLE Instructors (
    instructor_id INT PRIMARY KEY,
    instructor_name VARCHAR(100) NOT NULL UNIQUE,
    instructor_email VARCHAR(120) NOT NULL UNIQUE,
    CHECK (instructor_email LIKE '%_@_%._%')
);

CREATE TABLE Students (
    student_id INT PRIMARY KEY,
    student_name VARCHAR(100) NOT NULL,
    department VARCHAR(60) NOT NULL,
    advisor_id INT NOT NULL,
    CONSTRAINT fk_students_advisor
        FOREIGN KEY (advisor_id)
        REFERENCES Advisors(advisor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Courses (
    course_code VARCHAR(10) PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    instructor_id INT NOT NULL,
    CONSTRAINT fk_courses_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES Instructors(instructor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE Enrollments (
    student_id INT NOT NULL,
    course_code VARCHAR(10) NOT NULL,
    enrollment_year INT NOT NULL DEFAULT 2026,
    marks_obtained DECIMAL(5,2),
    PRIMARY KEY (student_id, course_code),
    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES Students(student_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_code)
        REFERENCES Courses(course_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CHECK (enrollment_year BETWEEN 2000 AND 2100),
    CHECK (marks_obtained IS NULL OR marks_obtained BETWEEN 0 AND 100)
);
