-- Create users to access database
CREATE USER employee_app;
\password employee_app
GRANT CONNECT ON DATABASE employee_management TO employee_app;

CREATE USER bammie;
\password bammie
GRANT CONNECT ON DATABASE employee_management TO employee_app;

-- Connect to the employee_management database
GRANT USAGE, CREATE ON SCHEMA public TO employee_app;
GRANT USAGE, CREATE ON SCHEMA public TO bammie;