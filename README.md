# IIT-mandi assignnent

## University Student Records Database Assignment

This repository contains a normalized relational database design for the original flat table:

```text
StudentRecords(student_id, student_name, department, advisor_name, advisor_email,
               course_code, course_name, instructor_name, instructor_email,
               enrollment_year, marks_obtained)
```

The solution uses PostgreSQL-compatible SQL.

## Files

- `schema.sql` — creates all normalized BCNF tables with primary keys, foreign keys, data types, defaults, and checks.
- `queries.sql` — contains insert, update, delete, advanced query, transaction, isolation, and MVCC answers.

---

## Task 1.1 — Normalization

### Original relation

The original flat table stores student, advisor, course, instructor, and enrollment data in one table.

The assumed composite key is:

```text
(student_id, course_code)
```

This means a row is identified by a particular student taking a particular course.

### Functional dependencies

The main functional dependencies are:

```text
(student_id, course_code) -> student_name, department, advisor_name, advisor_email,
                             course_name, instructor_name, instructor_email,
                             enrollment_year, marks_obtained

student_id -> student_name, department, advisor_name
course_code -> course_name, instructor_name, instructor_email
advisor_name -> advisor_email
instructor_name -> instructor_email
```

### Partial dependencies

A partial dependency exists when a non-key attribute depends on only part of the composite key.

Because the composite key is `(student_id, course_code)`, the following are partial dependencies:

```text
student_id -> student_name
student_id -> department
student_id -> advisor_name
course_code -> course_name
course_code -> instructor_name
course_code -> instructor_email
```

These cause redundancy. For example, the same student details are repeated for every course taken by that student, and the same course details are repeated for every student enrolled in that course.

### Transitive dependencies

A transitive dependency exists when a non-key attribute depends on another non-key attribute.

The transitive dependencies are:

```text
advisor_name -> advisor_email
instructor_name -> instructor_email
```

There is also a transitive path from the original composite key to these email attributes:

```text
(student_id, course_code) -> advisor_name -> advisor_email
(student_id, course_code) -> instructor_name -> instructor_email
```

These cause update anomalies. For example, changing an advisor's email in the original flat table would require updating multiple rows.

---

## BCNF Decomposition

The final BCNF tables are:

### 1. Advisors

```text
Advisors(advisor_id, advisor_name, advisor_email)
```

Primary key:

```text
advisor_id
```

Candidate key:

```text
advisor_name
```

Resolved dependency:

```text
advisor_name -> advisor_email
```

Resolved anomaly:

An advisor's email is stored once, so updating the email does not require changing many student-course records.

### 2. Instructors

```text
Instructors(instructor_id, instructor_name, instructor_email)
```

Primary key:

```text
instructor_id
```

Candidate key:

```text
instructor_name
```

Resolved dependency:

```text
instructor_name -> instructor_email
```

Resolved anomaly:

An instructor's email is stored once, so course records do not duplicate instructor email data.

### 3. Students

```text
Students(student_id, student_name, department, advisor_id)
```

Primary key:

```text
student_id
```

Foreign key:

```text
advisor_id -> Advisors(advisor_id)
```

Resolved dependency:

```text
student_id -> student_name, department, advisor_id
```

Resolved anomaly:

Student information is stored once and is not repeated for every course enrollment.

### 4. Courses

```text
Courses(course_code, course_name, instructor_id)
```

Primary key:

```text
course_code
```

Foreign key:

```text
instructor_id -> Instructors(instructor_id)
```

Resolved dependency:

```text
course_code -> course_name, instructor_id
```

Resolved anomaly:

Course information can be inserted without needing a student to exist. Course details are stored once.

### 5. Enrollments

```text
Enrollments(student_id, course_code, enrollment_year, marks_obtained)
```

Primary key:

```text
(student_id, course_code)
```

Foreign keys:

```text
student_id -> Students(student_id)
course_code -> Courses(course_code)
```

Resolved dependency:

```text
(student_id, course_code) -> enrollment_year, marks_obtained
```

Resolved anomaly:

Enrollment-specific information is separated from student and course information. Deleting an enrollment does not delete the student or the course.

---

## Why the Final Design is in BCNF

A table is in BCNF when, for every non-trivial functional dependency `X -> Y`, `X` is a superkey.

In the final design:

- In `Advisors`, `advisor_id` is the primary key and `advisor_name` is unique, so advisor-related dependencies use keys.
- In `Instructors`, `instructor_id` is the primary key and `instructor_name` is unique, so instructor-related dependencies use keys.
- In `Students`, student details depend only on `student_id`.
- In `Courses`, course details depend only on `course_code`.
- In `Enrollments`, enrollment details depend on the full composite key `(student_id, course_code)`.

Therefore, the decomposed tables satisfy BCNF.

---

## Data Integrity Analysis

### Entity integrity

Satisfied.

Every table has a primary key. Primary keys are unique and cannot be null. Examples include `student_id`, `advisor_id`, `instructor_id`, `course_code`, and the composite key `(student_id, course_code)` in `Enrollments`.

### Referential integrity

Satisfied.

Foreign keys ensure that:

- Every student advisor exists in `Advisors`.
- Every course instructor exists in `Instructors`.
- Every enrollment references an existing student and an existing course.

This prevents orphan enrollment records.

### Domain integrity

Satisfied.

The schema uses appropriate data types and constraints:

- IDs use `INT`.
- Names and emails use `VARCHAR`.
- Marks use `DECIMAL(5,2)`.
- `marks_obtained` is checked to be between 0 and 100.
- `enrollment_year` is checked to be between 2000 and 2100.
- Email columns use a simple email-pattern check.

### User-defined integrity

Satisfied for the stated requirements.

The design enforces the main business rules required in this assignment: students must have advisors, courses must have instructors, enrollment rows must reference valid students and courses, and marks must stay within a valid range.

A possible additional business rule, such as maximum course capacity, is discussed in the transaction section but is not implemented as a schema constraint because no capacity column was given in the original table.

---

## Design Decisions

### Surrogate IDs for advisors and instructors

The original dependencies use `advisor_name -> advisor_email` and `instructor_name -> instructor_email`. The design adds `advisor_id` and `instructor_id` as stable primary keys. Names are also marked unique so that the original functional dependencies remain valid.

This avoids problems if two people have similar names or if a person's email changes.

### Course code as primary key

`course_code` is kept as the primary key for `Courses` because the original table already treats course code as the identifier for a course.

### Composite key for enrollments

The `Enrollments` table uses `(student_id, course_code)` as its primary key because the assignment states that the original composite key is `(student_id, course_code)`.

### Marks as DECIMAL

`marks_obtained` is stored as `DECIMAL(5,2)` so that marks such as `76.50` can be stored accurately.

### Enrollment year default

`enrollment_year` has a default value of `2026`, which is a reasonable constant default for this assignment.

---

## Task 1.5 — Transaction and Isolation Analysis

### Course transfer transaction

The course transfer transaction deletes a student's current enrollment in `CS101` and inserts the new enrollment in `CS404` inside one transaction.

If both operations succeed, `COMMIT` makes the change permanent.

If the insert fails, the transaction should execute `ROLLBACK`, so the deletion from `CS101` is not permanently applied. This preserves atomicity: either the whole transfer happens, or none of it happens.

### Non-repeatable read

The anomaly where a transaction reads a student's `marks_obtained`, another transaction updates and commits the value, and the first transaction reads again and sees a different value is called a non-repeatable read.

The minimum isolation level that prevents non-repeatable reads is:

```text
REPEATABLE READ
```

### Course capacity anomaly

The anomaly where two concurrent transactions both read the same course enrollment count, both decide the course has room, and both insert a new enrollment is a write skew or business-rule race condition.

The isolation level that prevents this anomaly is:

```text
SERIALIZABLE
```

At `SERIALIZABLE` isolation, the database ensures that the final effect is equivalent to the transactions running one after another, preventing this kind of concurrent capacity violation.

### MVCC read behaviour

Under MVCC, the database keeps multiple row versions. A reporting transaction reads from a snapshot of the database instead of always reading the newest committed row version.

If a reporting transaction begins and reads a student's marks, then another transaction updates those marks and commits, the reporting transaction will still see the old marks if it re-reads the same row under a snapshot-consistent isolation level.

The isolation level that guarantees the reporting transaction sees a consistent snapshot throughout its lifetime is:

```text
REPEATABLE READ
```

`SERIALIZABLE` also provides this consistency and adds stronger protection against serialization anomalies.

The trade-off is that higher isolation can increase overhead, conflicts, rollbacks, and retries compared with a lower isolation level such as `READ COMMITTED`.
