-- Create users to access database
CREATE USER employee_app WITH PASSWORD 'Password123!';
GRANT CONNECT ON DATABASE employee_management TO employee_app;

CREATE USER bammie WITH PASSWORD 'Password123!';
GRANT CONNECT ON DATABASE employee_management TO employee_app;

-- Connect to the employee_management database
GRANT USAGE, CREATE ON SCHEMA public TO employee_app, bammie;