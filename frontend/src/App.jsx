
import { useEffect, useState } from "react";
import { Users, LogOut, Plus, Pencil, RefreshCw } from "lucide-react";
import "./App.css";

const API = "http://127.0.0.1:8000/api";

const emptyEmployee = {
  first_name: "",
  last_name: "",
  email: "",
  department: "",
  job_title: "",
  salary: "0.00",
};

export default function App() {
  const [token, setToken] = useState(
    () => sessionStorage.getItem("employee_token") || ""
  );
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [employees, setEmployees] = useState([]);
  const [form, setForm] = useState(emptyEmployee);
  const [editingId, setEditingId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  async function request(path, options = {}) {
    const response = await fetch(`${API}${path}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      if (response.status === 401 && path !== "/login") {
        logout();
      }
      throw new Error(data.detail || "Request failed");
    }

    return data;
  }

  function logout() {
    sessionStorage.removeItem("employee_token");
    setToken("");
    setEmployees([]);
    setShowForm(false);
    setEditingId(null);
    setError("");
    setMessage("");
  }

  async function login(event) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const data = await request("/login", {
        method: "POST",
        body: JSON.stringify({ username, password }),
      });

      sessionStorage.setItem("employee_token", data.access_token);
      setToken(data.access_token);
      setPassword("");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadEmployees() {
    setError("");
    setLoading(true);

    try {
      setEmployees(await request("/employees"));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (token) loadEmployees();
  }, [token]);

  function openAddForm() {
    setEditingId(null);
    setForm(emptyEmployee);
    setError("");
    setMessage("");
    setShowForm(true);
  }

  function openEditForm(employee) {
    setEditingId(employee.id);
    setForm({
      first_name: employee.first_name,
      last_name: employee.last_name,
      email: employee.email,
      department: employee.department,
      job_title: employee.job_title,
      salary: String(employee.salary),
    });
    setError("");
    setMessage("");
    setShowForm(true);
  }

  function changeField(event) {
    setForm({ ...form, [event.target.name]: event.target.value });
  }

  async function saveEmployee(event) {
    event.preventDefault();
    setError("");
    setMessage("");

    const payload = {
      ...form,
      salary: Number(form.salary),
    };

    try {
      await request(
        editingId ? `/employees/${editingId}` : "/employees",
        {
          method: editingId ? "PUT" : "POST",
          body: JSON.stringify(payload),
        }
      );

      setShowForm(false);
      setEditingId(null);
      setForm(emptyEmployee);
      setMessage(editingId ? "Employee updated." : "Employee added.");
      await loadEmployees();
    } catch (err) {
      setError(err.message);
    }
  }

  if (!token) {
    return (
      <main className="login-page">
        <form className="login-card" onSubmit={login}>
          <div className="brand-icon"><Users size={28} /></div>
          <h1>Employee Portal</h1>
          <p>Sign in to manage employee records.</p>

          {error && <div className="alert error">{error}</div>}

          <label htmlFor="username">Username</label>
          <input
            id="username"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />

          <label htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          <button className="primary full" disabled={loading}>
            {loading ? "Signing in..." : "Sign in"}
          </button>
        </form>
      </main>
    );
  }

  return (
    <main className="dashboard">
      <header className="topbar">
        <div className="brand">
          <Users size={24} />
          <span>Employee Portal</span>
        </div>
        <button className="secondary" onClick={logout}>
          <LogOut size={16} /> Logout
        </button>
      </header>

      <section className="content">
        <div className="page-heading">
          <div>
            <h1>Employees</h1>
            <p>View and manage your employee directory.</p>
          </div>
          <button className="primary" onClick={openAddForm}>
            <Plus size={17} /> Add employee
          </button>
        </div>

        {error && <div className="alert error">{error}</div>}
        {message && <div className="alert success">{message}</div>}

        {showForm && (
          <section className="panel">
            <h2>{editingId ? "Update employee" : "Add employee"}</h2>

            <form className="employee-form" onSubmit={saveEmployee}>
              {[
                ["first_name", "First name"],
                ["last_name", "Last name"],
                ["email", "Email"],
                ["department", "Department"],
                ["job_title", "Job title"],
                ["salary", "Annual salary"],
              ].map(([name, label]) => (
                <div className="field" key={name}>
                  <label htmlFor={name}>{label}</label>
                  <input
                    id={name}
                    name={name}
                    type={name === "email" ? "email" : name === "salary" ? "number" : "text"}
                    min={name === "salary" ? "0" : undefined}
                    step={name === "salary" ? "0.01" : undefined}
                    value={form[name]}
                    onChange={changeField}
                    required
                  />
                </div>
              ))}

              <div className="form-actions">
                <button type="submit" className="primary">
                  {editingId ? "Save changes" : "Save employee"}
                </button>
                <button
                  type="button"
                  className="secondary"
                  onClick={() => setShowForm(false)}
                >
                  Cancel
                </button>
              </div>
            </form>
          </section>
        )}

        <section className="panel">
          <div className="table-heading">
            <h2>Employee directory</h2>
            <button
              className="secondary"
              onClick={loadEmployees}
              disabled={loading}
            >
              <RefreshCw size={15} /> Refresh
            </button>
          </div>

          {loading ? (
            <p>Loading employees...</p>
          ) : employees.length === 0 ? (
            <p>No employees found. Add your first employee.</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Employee</th>
                    <th>Email</th>
                    <th>Department</th>
                    <th>Job title</th>
                    <th>Salary</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {employees.map((employee) => (
                    <tr key={employee.id}>
                      <td>{employee.id}</td>
                      <td>{employee.first_name} {employee.last_name}</td>
                      <td>{employee.email}</td>
                      <td>{employee.department}</td>
                      <td>{employee.job_title}</td>
                      <td>
                        {Number(employee.salary).toLocaleString("en-US", {
                          style: "currency",
                          currency: "USD",
                        })}
                      </td>
                      <td>
                        <button
                          className="edit-button"
                          onClick={() => openEditForm(employee)}
                          aria-label={`Edit ${employee.first_name} ${employee.last_name}`}
                        >
                          <Pencil size={15} /> Edit
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </section>
    </main>
  );
}
