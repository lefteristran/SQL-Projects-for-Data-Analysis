-- Create the table
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department VARCHAR(50),
    salary DECIMAL(10,2)
);

-- Insert 5 rows of data
INSERT INTO employees (employee_id, first_name, last_name, department, salary) VALUES
(1, 'Alice', 'Smith', 'Finance', 55000.00),
(2, 'Bob', 'Johnson', 'IT', 62000.00),
(3, 'Charlie', 'Brown', 'Marketing', 50000.00),
(4, 'Diana', 'Miller', 'HR', 48000.00),
(5, 'Ethan', 'Davis', 'Operations', 58000.00);


SELECT * FROM employees