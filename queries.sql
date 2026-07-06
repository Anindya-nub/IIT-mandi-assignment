-- queries.sql
-- PostgreSQL-compatible DML, DQL, transaction, and concurrency notes.

-- =========================================================
-- Task 1.3(a): Insert sample data
-- =========================================================

INSERT INTO Advisors (advisor_id, advisor_name, advisor_email) VALUES
(1, 'Dr Meera Iyer', 'meera.iyer@university.edu'),
(2, 'Dr Arjun Rao', 'arjun.rao@university.edu');

INSERT INTO Instructors (instructor_id, instructor_name, instructor_email) VALUES
(10, 'Dr Neha Shah', 'neha.shah@university.edu'),
(20, 'Dr Vikram Menon', 'vikram.menon@university.edu');

INSERT INTO Students (student_id, student_name, department, advisor_id) VALUES
(1, 'Alice Kumar', 'CSE', 1),
(2, 'Bob Thomas', 'CSE', 1),
(3, 'Carol Dsouza', 'ECE', 2),
(4, 'David Paul', 'CSE', 1),
(5, 'Eve Nair', 'ECE', 2);

INSERT INTO Courses (course_code, course_name, instructor_id) VALUES
('CS101', 'Programming Fundamentals', 10),
('CS202', 'Database Management Systems', 10),
('CS303', 'Operating Systems', 20),
('CS404', 'Computer Networks', 20);

INSERT INTO Enrollments (student_id, course_code, enrollment_year, marks_obtained) VALUES
(1, 'CS101', 2024, 88.00),
(1, 'CS202', 2025, 76.00),
(2, 'CS101', 2024, 76.00),
(2, 'CS303', 2025, 34.00),
(3, 'CS202', 2024, 91.00),
(3, 'CS303', 2025, 68.00),
(5, 'CS101', 2024, 55.00);

-- =========================================================
-- Task 1.3(b): Update one instructor email using primary key
-- =========================================================

UPDATE Instructors
SET instructor_email = 'neha.updated@university.edu'
WHERE instructor_id = 10;

-- =========================================================
-- Task 1.3(c): Delete failed enrollment records only
-- =========================================================

DELETE FROM Enrollments
WHERE marks_obtained < 35;

-- =========================================================
-- Task 1.3(d): Delete all rows from the old flat table
-- =========================================================

-- Assumption: StudentRecords is the old unnormalized legacy table.
-- DELETE is safer for transaction-controlled bulk removal because it is a DML
-- statement that respects BEGIN/ROLLBACK in all major databases. TRUNCATE
-- behaviour varies by engine: in MySQL, TRUNCATE is treated as DDL and
-- implicitly commits any open transaction, making it non-rollback-safe; in
-- PostgreSQL, TRUNCATE is transactional and can be rolled back. Therefore,
-- the safest cross-database choice for a bulk removal inside a transaction is DELETE.
DELETE FROM StudentRecords;

-- =========================================================
-- Task 1.4(a): IN operator
-- =========================================================

SELECT s.student_name, c.course_name
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
INNER JOIN Courses c ON e.course_code = c.course_code
WHERE e.course_code IN ('CS101', 'CS202', 'CS303');

-- =========================================================
-- Task 1.4(b): BETWEEN and IS NOT NULL
-- =========================================================

SELECT s.student_id, s.student_name, e.course_code, e.marks_obtained, a.advisor_email
FROM Students s
INNER JOIN Advisors a ON s.advisor_id = a.advisor_id
INNER JOIN Enrollments e ON s.student_id = e.student_id
WHERE e.marks_obtained BETWEEN 60 AND 85
  AND a.advisor_email IS NOT NULL;

-- =========================================================
-- Task 1.4(c): GROUP BY and HAVING
-- =========================================================

SELECT
    s.department,
    AVG(e.marks_obtained) AS average_marks,
    MIN(e.marks_obtained) AS minimum_marks,
    MAX(e.marks_obtained) AS maximum_marks
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
GROUP BY s.department
HAVING AVG(e.marks_obtained) > 55;

-- =========================================================
-- Task 1.4(d): INNER JOIN and LEFT JOIN
-- =========================================================

SELECT s.student_name, c.course_name, e.marks_obtained
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
INNER JOIN Courses c ON e.course_code = c.course_code;

SELECT s.student_name, c.course_name, e.marks_obtained
FROM Students s
LEFT JOIN Enrollments e ON s.student_id = e.student_id
LEFT JOIN Courses c ON e.course_code = c.course_code;

-- =========================================================
-- Task 1.4(e): Correlated subquery: above department average
-- =========================================================

SELECT s.student_name, e.marks_obtained
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
WHERE e.marks_obtained > (
    SELECT AVG(e2.marks_obtained)
    FROM Students s2
    INNER JOIN Enrollments e2 ON s2.student_id = e2.student_id
    WHERE s2.department = s.department
);

-- =========================================================
-- Task 1.4(f): Set operation EXCEPT
-- =========================================================

SELECT student_id
FROM Enrollments
WHERE enrollment_year = 2024
EXCEPT
SELECT student_id
FROM Enrollments
WHERE enrollment_year = 2025;

-- =========================================================
-- Task 1.4(g): Correlated subquery: second-highest marks per department
-- =========================================================

SELECT s.department, s.student_name, e.marks_obtained
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
WHERE 1 = (
    SELECT COUNT(DISTINCT e2.marks_obtained)
    FROM Students s2
    INNER JOIN Enrollments e2 ON s2.student_id = e2.student_id
    WHERE s2.department = s.department
      AND e2.marks_obtained > e.marks_obtained
)
AND 2 <= (
    SELECT COUNT(DISTINCT s3.student_id)
    FROM Students s3
    INNER JOIN Enrollments e3 ON s3.student_id = e3.student_id
    WHERE s3.department = s.department
)
ORDER BY s.department, e.marks_obtained DESC, s.student_name;

-- =========================================================
-- Task 1.4(h): Window functions with ROW_NUMBER, RANK, DENSE_RANK
-- =========================================================

SELECT
    s.department,
    s.student_name,
    e.course_code,
    e.marks_obtained,
    ROW_NUMBER() OVER (
        PARTITION BY s.department
        ORDER BY e.marks_obtained DESC
    ) AS row_number_rank,
    RANK() OVER (
        PARTITION BY s.department
        ORDER BY e.marks_obtained DESC
    ) AS rank_value,
    DENSE_RANK() OVER (
        PARTITION BY s.department
        ORDER BY e.marks_obtained DESC
    ) AS dense_rank_value
FROM Students s
INNER JOIN Enrollments e ON s.student_id = e.student_id
ORDER BY s.department, e.marks_obtained DESC, s.student_name;

-- =========================================================
-- Task 1.5(a): Transaction to transfer a student from CS101 to CS404
-- =========================================================

-- Success path:
BEGIN;

DELETE FROM Enrollments
WHERE student_id = 1
  AND course_code = 'CS101';

INSERT INTO Enrollments (student_id, course_code, enrollment_year, marks_obtained)
VALUES (1, 'CS404', 2026, NULL);

COMMIT;

-- Rollback branch:
-- If the INSERT fails before COMMIT, run ROLLBACK instead of COMMIT.
-- For example, a failure could occur if course_code 'CS404' does not exist or
-- if the same (student_id, course_code) primary key already exists.
-- ROLLBACK;

-- =========================================================
-- Task 1.5(b): Non-repeatable read
-- =========================================================

-- Anomaly name: Non-repeatable read.
-- A transaction reads the same row twice and sees different marks because
-- another transaction updated and committed the row between the two reads.
-- Minimum isolation level that prevents it: REPEATABLE READ.

-- =========================================================
-- Task 1.5(c): Course capacity anomaly
-- =========================================================

-- Anomaly name: Write skew / lost business-rule update under concurrent checks.
-- Both transactions read the same course enrollment count and both insert,
-- violating the course capacity rule.
-- Isolation level that prevents it: SERIALIZABLE.

-- =========================================================
-- Task 1.5(d): MVCC explanation
-- =========================================================

-- Under MVCC, a reporting transaction reads from a snapshot rather than reading
-- directly from the newest physical version of every row. If the reporting
-- transaction is running under REPEATABLE READ or SERIALIZABLE snapshot-style
-- isolation and it reads a student's marks_obtained, then a concurrent writer
-- updates that mark and commits, the reporting transaction will still see the
-- old value when it re-reads the same row. It sees the version that was visible
-- when the reporting transaction's snapshot began.
--
-- Isolation level that guarantees a consistent snapshot throughout the
-- reporting transaction: REPEATABLE READ, with SERIALIZABLE providing even
-- stronger protection against serialization anomalies.
--
-- Trade-off: higher isolation gives more consistent analytical results but can
-- increase locking/conflict checks, transaction aborts, retries, and overhead
-- compared with READ COMMITTED.
